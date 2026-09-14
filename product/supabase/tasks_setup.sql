-- =============================================================================
-- Tide · Supabase to-do list setup
--
-- Run after auth_setup.sql: Supabase → SQL Editor → New query → Run.
-- Safe to run again: every statement replaces or skips what already exists.
--
-- What it creates
--   1. public.tasks            one row per task, RLS on, owner-only
--   2. table privileges        least privilege on top of RLS
--   3. last-write-wins trigger an older write never replaces a newer row
--
-- How the app uses it (lib/services/tasks/)
--   The device holds the list and every change is made there first. Each
--   task carries its own sync status; pending rows are pushed as whole-row
--   upserts (creates, then updates, then deletes), then everything the server
--   has written since the last pull is read back by `synced_at`.
--
--   Deletes are soft: `deleted_at` is set and the row stays, so a delete made
--   offline replays like any other write and reaches the account's other
--   devices on their next pull.
-- =============================================================================


-- 1. Tasks -----------------------------------------------------------------------
-- The id is made by the app (a v4 UUID) so a task created offline has one
-- before the server has seen it.
--
-- `updated_at` is the time of the edit *on the device that made it*, and is
-- what last-write-wins compares. `synced_at` is stamped here, by the server,
-- on every insert and update, and is what the app pulls by: a phone with a
-- wrong clock can then never make a row fall between two pulls.

create table if not exists public.tasks (
  id                        uuid primary key,
  user_id                   uuid not null default auth.uid()
                              references auth.users (id) on delete cascade,
  title                     text not null
                              check (char_length(btrim(title)) between 1 and 500),
  description               text check (char_length(description) <= 4000),
  due_date                  date,
  is_completed              boolean not null default false,
  completed_at              timestamptz,
  recurrence                text not null default 'none'
                              check (recurrence in ('none', 'daily', 'weekly',
                                                    'monthly', 'custom')),
  custom_recurrence_months  smallint
                              check (custom_recurrence_months between 1 and 24),
  reminders                 timestamptz[] not null default '{}'
                              check (cardinality(reminders) <= 50),
  tags                      text[] not null default '{}'
                              check (cardinality(tags) <= 30),
  subtasks                  jsonb not null default '[]'::jsonb
                              check (jsonb_typeof(subtasks) = 'array'),
  is_archived               boolean not null default false,
  created_at                timestamptz not null default now(),
  updated_at                timestamptz not null default now(),
  deleted_at                timestamptz,
  synced_at                 timestamptz not null default clock_timestamp()
);

create index if not exists tasks_user_synced_idx
  on public.tasks (user_id, synced_at, id);


-- Row level security ----------------------------------------------------------------

alter table public.tasks enable row level security;

drop policy if exists "tasks_select_own" on public.tasks;
create policy "tasks_select_own"
  on public.tasks
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "tasks_insert_own" on public.tasks;
create policy "tasks_insert_own"
  on public.tasks
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "tasks_update_own" on public.tasks;
create policy "tasks_update_own"
  on public.tasks
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- No delete policy. The app never hard-deletes a task; a row leaves with its
-- account, by the foreign key's cascade.


-- 2. Privileges -----------------------------------------------------------------
-- Whole-table insert/update because the app writes by upsert, and an upsert's
-- ON CONFLICT DO UPDATE needs UPDATE on every column it sends.

revoke all on table public.tasks from anon, authenticated;
grant select, insert, update on table public.tasks to authenticated;


-- 3. Last write wins --------------------------------------------------------------
-- A write carrying an older `updated_at` than the stored row is dropped, not
-- applied: returning null from a BEFORE UPDATE trigger skips the row. This is
-- what stops a phone that was offline for a week from undoing everything
-- another device did in the meantime when it finally sends its queue.
--
-- Every write that does land is stamped with the server's own clock.

create or replace function public.tasks_keep_newest()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' and new.updated_at < old.updated_at then
    return null;
  end if;
  -- The owner never changes, whatever the row sent says.
  if tg_op = 'UPDATE' then
    new.user_id := old.user_id;
  end if;
  new.synced_at := clock_timestamp();
  return new;
end;
$$;

revoke all on function public.tasks_keep_newest() from public, anon, authenticated;

drop trigger if exists tasks_keep_newest on public.tasks;
create trigger tasks_keep_newest
  before insert or update on public.tasks
  for each row execute function public.tasks_keep_newest();
