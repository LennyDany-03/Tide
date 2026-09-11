-- =============================================================================
-- Tide · Supabase auth setup
--
-- Paste into Supabase → SQL Editor → New query → Run.
-- Safe to run again: every statement replaces or skips what already exists.
--
-- What it creates
--   1. public.profiles         one row per auth user, RLS on, owner-only
--   2. table privileges        least privilege on top of RLS
--   3. updated_at trigger
--   4. auth.users triggers     create/sync a profile on sign-up and on change
--   5. account_status(email)   lets the sign-in screen say "no account, create
--                              one" instead of "invalid credentials"
-- =============================================================================


-- 1. Profiles -----------------------------------------------------------------

create table if not exists public.profiles (
  id             uuid primary key references auth.users (id) on delete cascade,
  email          text,
  full_name      text check (full_name is null or char_length(full_name) <= 120),
  avatar_url     text,
  tour_completed boolean not null default false,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- A signed-in user can read and update only their own row. There is no insert
-- or delete policy on purpose: rows are created by the trigger below and
-- removed by the cascade when the auth user is deleted, never by the app.
drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
  on public.profiles
  for select
  to authenticated
  using ((select auth.uid()) = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles
  for update
  to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);


-- 2. Privileges -----------------------------------------------------------------
-- RLS decides which rows; grants decide which columns. The app may change only
-- its name and whether the tour has been shown — never id, email or avatar_url,
-- which come from auth.users through the trigger.

revoke all on table public.profiles from anon, authenticated;
grant select on table public.profiles to authenticated;
grant update (full_name, tour_completed) on table public.profiles to authenticated;


-- 3. updated_at -----------------------------------------------------------------

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists profiles_touch_updated_at on public.profiles;
create trigger profiles_touch_updated_at
  before update on public.profiles
  for each row execute function public.touch_updated_at();


-- 4. Profile from auth.users ------------------------------------------------------
-- Email sign-up passes { full_name } as user metadata; Google supplies
-- full_name / name and avatar_url / picture. security definer so the trigger
-- can write the row whoever the inserting role is; search_path pinned so it
-- cannot be hijacked.

create or replace function public.handle_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles as p (id, email, full_name, avatar_url)
  values (
    new.id,
    new.email,
    left(coalesce(new.raw_user_meta_data ->> 'full_name',
                  new.raw_user_meta_data ->> 'name'), 120),
    coalesce(new.raw_user_meta_data ->> 'avatar_url',
             new.raw_user_meta_data ->> 'picture')
  )
  on conflict (id) do update
    set email      = excluded.email,
        full_name  = coalesce(p.full_name, excluded.full_name),
        avatar_url = coalesce(excluded.avatar_url, p.avatar_url);
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_auth_user();

drop trigger if exists on_auth_user_updated on auth.users;
create trigger on_auth_user_updated
  after update of email, raw_user_meta_data on auth.users
  for each row execute function public.handle_auth_user();

-- Anyone who signed up before this script ran gets a profile too.
insert into public.profiles (id, email, full_name, avatar_url)
select
  u.id,
  u.email,
  left(coalesce(u.raw_user_meta_data ->> 'full_name',
                u.raw_user_meta_data ->> 'name'), 120),
  coalesce(u.raw_user_meta_data ->> 'avatar_url',
           u.raw_user_meta_data ->> 'picture')
from auth.users u
on conflict (id) do nothing;


-- 5. account_status(email) ----------------------------------------------------------
-- Supabase deliberately returns the same "invalid credentials" error for a
-- wrong password and for an address it has never seen. Tide wants to tell
-- those apart, so this answers exactly one question about an address:
--
--   'none'      no account
--   'password'  an account that can sign in with a password
--   'google'    an account with no password (signed up with Google)
--
-- Trade-off, stated plainly: anyone with the publishable key can ask whether
-- an address is registered. Nothing else is ever returned — no id, no name, no
-- dates. If that trade is not acceptable for your app, drop this function; the
-- app falls back to Supabase's generic messages on its own.

create or replace function public.account_status(p_email text)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_password text;
begin
  if p_email is null or char_length(p_email) > 320 then
    return 'none';
  end if;

  select u.encrypted_password
    into v_password
    from auth.users u
   where u.email = lower(btrim(p_email))
     and u.deleted_at is null
   limit 1;

  if not found then
    return 'none';
  end if;

  if coalesce(v_password, '') <> '' then
    return 'password';
  end if;

  return 'google';
end;
$$;


-- Function privileges -----------------------------------------------------------------
-- Supabase grants EXECUTE on new public functions to anon and authenticated by
-- default. Take it all back, then give back only what the app calls.

revoke all on function public.account_status(text) from public, anon, authenticated;
grant execute on function public.account_status(text) to anon, authenticated;

revoke all on function public.handle_auth_user() from public, anon, authenticated;
revoke all on function public.touch_updated_at() from public, anon, authenticated;
