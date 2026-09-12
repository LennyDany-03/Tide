-- =============================================================================
-- Tide · Supabase habits setup
--
-- Run after auth_setup.sql: Supabase → SQL Editor → New query → Run.
-- Safe to run again: every statement replaces or skips what already exists.
--
-- What it creates
--   1. public.habits           one row per habit, RLS on, owner-only
--   2. public.habit_entries    one row per habit per day that was ever touched
--   3. table privileges        least privilege on top of RLS
--   4. updated_at triggers
--   5. habits_snapshot()       an account's habits and history in one request
--   6. realtime broadcasts     every change announced on the owner's private
--                              topic, habits:<user id>
--
-- How the app uses it (lib/services/habits/)
--   Every write is the whole row, never a delta ("8 glasses on the 11th", not
--   "+1 glass"), so a write queued offline can be replayed any number of times
--   and a later write to the same row makes an earlier one redundant. Each row
--   carries the `origin` of the app process that last wrote it, so that
--   process can skip the broadcast of its own write.
-- =============================================================================


-- 1. Habits ---------------------------------------------------------------------
-- The id is made by the app (a v4 UUID), not by the database: a habit created
-- offline needs its id before the server has seen it, so its first day can be
-- queued against it.

create table if not exists public.habits (
  id                uuid primary key,
  user_id           uuid not null default auth.uid()
                      references auth.users (id) on delete cascade,
  name              text not null
                      check (char_length(btrim(name)) between 1 and 500),
  glyph             text not null check (char_length(glyph) between 1 and 40),
  kind              text not null
                      check (kind in ('binary', 'quantity', 'duration')),
  target            numeric not null default 1
                      check (target > 0 and target <= 100000),
  unit              text not null default '' check (char_length(unit) <= 32),
  -- ISO weekdays, Monday = 1 … Sunday = 7, the numbering Dart's DateTime uses.
  weekdays          smallint[] not null default '{1,2,3,4,5,6,7}'
                      check (cardinality(weekdays) between 1 and 7
                             and weekdays <@ '{1,2,3,4,5,6,7}'::smallint[]),
  reminder_enabled  boolean not null default false,
  reminder_time     time not null default '08:00',
  freeze_allowance  smallint not null default 2
                      check (freeze_allowance between 0 and 7),
  freezes_remaining smallint not null default 2
                      check (freezes_remaining between 0 and freeze_allowance),
  paused            boolean not null default false,
  origin            text check (char_length(origin) <= 64),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  -- What habit_entries' foreign key points at. It is what ties every entry to
  -- a habit owned by the same user, without a lookup in a policy.
  constraint habits_id_user_key unique (id, user_id)
);

create index if not exists habits_user_created_idx
  on public.habits (user_id, created_at);


-- 2. Entries --------------------------------------------------------------------
-- One row for each day of a habit that has been logged or frozen. `amount` is
-- null for a day with nothing logged; `frozen` means a freeze token was spent
-- on it. Undoing a day writes it back empty rather than deleting it: a delete
-- followed quickly by a re-log could reach another device in the wrong order
-- and erase the re-log there.
--
-- `day` is the person's own calendar date, with no time zone, because that is
-- what a streak counts.

create table if not exists public.habit_entries (
  habit_id   uuid not null,
  user_id    uuid not null default auth.uid(),
  day        date not null,
  amount     numeric check (amount >= 0 and amount <= 1000000),
  frozen     boolean not null default false,
  origin     text check (char_length(origin) <= 64),
  updated_at timestamptz not null default now(),
  primary key (habit_id, day),
  constraint habit_entries_habit_fkey
    foreign key (habit_id, user_id)
    references public.habits (id, user_id)
    on delete cascade
);

create index if not exists habit_entries_user_day_idx
  on public.habit_entries (user_id, day);


-- Row level security ----------------------------------------------------------------
-- A signed-in user reaches only their own rows, in both tables. The composite
-- foreign key above means an entry can only hang off a habit with the same
-- owner, so these policies never need to look across tables.

alter table public.habits        enable row level security;
alter table public.habit_entries enable row level security;

drop policy if exists "habits_select_own" on public.habits;
create policy "habits_select_own"
  on public.habits
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "habits_insert_own" on public.habits;
create policy "habits_insert_own"
  on public.habits
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "habits_update_own" on public.habits;
create policy "habits_update_own"
  on public.habits
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "habits_delete_own" on public.habits;
create policy "habits_delete_own"
  on public.habits
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "habit_entries_select_own" on public.habit_entries;
create policy "habit_entries_select_own"
  on public.habit_entries
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "habit_entries_insert_own" on public.habit_entries;
create policy "habit_entries_insert_own"
  on public.habit_entries
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "habit_entries_update_own" on public.habit_entries;
create policy "habit_entries_update_own"
  on public.habit_entries
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "habit_entries_delete_own" on public.habit_entries;
create policy "habit_entries_delete_own"
  on public.habit_entries
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);


-- 3. Privileges -----------------------------------------------------------------
-- Whole-table grants rather than per-column ones: the app writes by upsert,
-- and an upsert's ON CONFLICT DO UPDATE needs UPDATE on every column it sends,
-- id and user_id included. The update policy's `with check` is what stops a
-- row being handed to somebody else.

revoke all on table public.habits, public.habit_entries from anon, authenticated;
grant select, insert, update, delete
  on table public.habits, public.habit_entries
  to authenticated;


-- 4. updated_at -----------------------------------------------------------------
-- The same function auth_setup.sql installs, repeated so this file does not
-- depend on the order the two were run in.

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

revoke all on function public.touch_updated_at() from public, anon, authenticated;

drop trigger if exists habits_touch_updated_at on public.habits;
create trigger habits_touch_updated_at
  before update on public.habits
  for each row execute function public.touch_updated_at();

drop trigger if exists habit_entries_touch_updated_at on public.habit_entries;
create trigger habit_entries_touch_updated_at
  before update on public.habit_entries
  for each row execute function public.touch_updated_at();


-- 5. habits_snapshot() ------------------------------------------------------------
-- What the app reads on sign-in, on returning to the foreground, on pull to
-- refresh and when the realtime channel joins. One function instead of two
-- selects, for two reasons: it is a single statement, so habits and entries
-- are read at the same instant and an entry can never arrive for a habit the
-- list does not have; and it returns a single value, so PostgREST's row cap
-- (1,000 by default on Supabase) cannot quietly cut a long history short.
--
-- Shape: [ { ...habits row, "entries": [ { "day", "amount", "frozen" } ] } ]
--
-- security invoker: it runs as the caller, under the policies above.

create or replace function public.habits_snapshot()
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select coalesce(
    jsonb_agg(
      to_jsonb(h) || jsonb_build_object(
        'entries',
        coalesce((
          select jsonb_agg(
                   jsonb_build_object(
                     'day',    e.day,
                     'amount', e.amount,
                     'frozen', e.frozen
                   )
                   order by e.day
                 )
            from public.habit_entries e
           where e.habit_id = h.id
             and (e.amount is not null or e.frozen)
        ), '[]'::jsonb)
      )
      order by h.created_at, h.id
    ),
    '[]'::jsonb
  )
  from public.habits h
  where h.user_id = (select auth.uid());
$$;

revoke all on function public.habits_snapshot() from public, anon, authenticated;
grant execute on function public.habits_snapshot() to authenticated;


-- 6. Realtime ---------------------------------------------------------------------
-- Changes reach the owner's other devices as Realtime *Broadcast from the
-- database* rather than as Postgres Changes. Postgres Changes cannot filter or
-- authorise delete events, so every subscriber would be sent every user's
-- deleted rows; a broadcast goes to one topic, and the policy on
-- realtime.messages below lets only its owner join it.
--
-- Entries are announced on insert and update only. The app never deletes one
-- (an undone day is written back empty), so the only entry deletes are the
-- cascade from a deleted habit, and that habit's own delete already says it.
--
-- The app joins with `private: true`. Nothing needs changing in the
-- dashboard: private channels are authorised by these policies whether or not
-- Realtime's "Allow public access" setting is left on.

create or replace function public.broadcast_habit_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_owner uuid;
begin
  if tg_op = 'DELETE' then
    v_owner := old.user_id;
  else
    v_owner := new.user_id;
  end if;

  perform realtime.broadcast_changes(
    'habits:' || v_owner::text,  -- topic
    tg_op,                       -- event
    tg_op,                       -- operation
    tg_table_name,
    tg_table_schema,
    new,
    old
  );
  return null;
end;
$$;

revoke all on function public.broadcast_habit_change() from public, anon, authenticated;

drop trigger if exists habits_broadcast on public.habits;
create trigger habits_broadcast
  after insert or update or delete on public.habits
  for each row execute function public.broadcast_habit_change();

drop trigger if exists habit_entries_broadcast on public.habit_entries;
create trigger habit_entries_broadcast
  after insert or update on public.habit_entries
  for each row execute function public.broadcast_habit_change();

-- A signed-in user may receive on exactly one habits topic: their own. There
-- is no insert policy, so no client can publish onto it — only the trigger
-- above, which runs as the function's owner.
drop policy if exists "habits_topic_receive_own" on realtime.messages;
create policy "habits_topic_receive_own"
  on realtime.messages
  for select
  to authenticated
  using (
    realtime.messages.extension = 'broadcast'
    and (select realtime.topic()) = 'habits:' || (select auth.uid())::text
  );
