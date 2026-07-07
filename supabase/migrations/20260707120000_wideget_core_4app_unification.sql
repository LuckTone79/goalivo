-- ============================================================================
-- wideget-core : 4-app unification (Goalivo / castfolio / kadit / locawing)
-- ----------------------------------------------------------------------------
-- Target project : existing "Goalivo" Supabase project, to be renamed in the
--                  dashboard to "wideget-core" by a human.
--
-- Scope of THIS migration (all ADDITIVE / NON-DESTRUCTIVE):
--   * per-app schemas: goalivo, castfolio, kadit, locawing
--   * shared public registry tables: apps, app_memberships, global_profiles
--   * seed rows for the 4 unified apps
--   * RLS + policies on every user-facing shared table
--   * updated_at trigger helper
--   * supporting indexes
--
-- Explicitly NOT in scope (see runbook / rollback docs):
--   * qkiki  schema  -> stays an INDEPENDENT Supabase project (never created here)
--   * one_more_rep   -> stays an INDEPENDENT Supabase project (never created here)
--   * NO DROP / DELETE / TRUNCATE of any existing object or row
--   * NO modification of the auth schema or auth.users (only FK references)
--   * NO cross-project data movement (that is a separate, manual, documented step)
--
-- Idempotency: every statement uses IF NOT EXISTS / CREATE OR REPLACE / guarded
-- DO blocks so the file is safe to re-run.
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- 0) Per-app schemas (data isolation boundary for each unified app)
-- ----------------------------------------------------------------------------
create schema if not exists goalivo;
create schema if not exists castfolio;
create schema if not exists kadit;
create schema if not exists locawing;

-- Intentionally NOT created: qkiki, one_more_rep (independent projects).

comment on schema goalivo  is 'Goalivo app-private data (unified under wideget-core).';
comment on schema castfolio is 'castfolio app-private data (unified under wideget-core).';
comment on schema kadit    is 'kadit app-private data (unified under wideget-core).';
comment on schema locawing  is 'locawing app-private data (unified under wideget-core).';

-- ----------------------------------------------------------------------------
-- 1) Shared updated_at trigger helper (used by any table with updated_at)
-- ----------------------------------------------------------------------------
create or replace function public.wideget_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

comment on function public.wideget_set_updated_at() is
  'Generic BEFORE INSERT/UPDATE trigger: stamps updated_at = now().';

-- ----------------------------------------------------------------------------
-- 2) public.apps  — global app registry
-- ----------------------------------------------------------------------------
create table if not exists public.apps (
  id         text primary key,
  name       text not null,
  slug       text not null unique,
  status     text not null default 'active',
  created_at timestamptz not null default now()
);

comment on table public.apps is 'Registry of apps unified under wideget-core.';

-- Seed the 4 unified apps (idempotent; does not overwrite manual edits).
insert into public.apps (id, name, slug) values
  ('goalivo',   'Goalivo',   'goalivo'),
  ('castfolio', 'Castfolio', 'castfolio'),
  ('kadit',     'Kadit',     'kadit'),
  ('locawing',  'Locawing',  'locawing')
on conflict (id) do nothing;

-- ----------------------------------------------------------------------------
-- 3) public.app_memberships  — which user belongs to which app
-- ----------------------------------------------------------------------------
create table if not exists public.app_memberships (
  app_id     text not null references public.apps(id),
  user_id    uuid not null references auth.users(id) on delete cascade,
  role       text not null default 'user',
  status     text not null default 'active',
  created_at timestamptz not null default now(),
  primary key (app_id, user_id)
);

comment on table public.app_memberships is
  'App membership per user. role/status escalation is service_role-only (see RLS).';

create index if not exists app_memberships_user_id_idx on public.app_memberships (user_id);
create index if not exists app_memberships_app_id_idx  on public.app_memberships (app_id);

-- ----------------------------------------------------------------------------
-- 4) public.global_profiles  — cross-app profile (1 row per auth user)
-- ----------------------------------------------------------------------------
create table if not exists public.global_profiles (
  user_id      uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  avatar_url   text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

comment on table public.global_profiles is 'Cross-app user profile shared by all wideget-core apps.';

drop trigger if exists trg_global_profiles_updated_at on public.global_profiles;
create trigger trg_global_profiles_updated_at
  before insert or update on public.global_profiles
  for each row execute function public.wideget_set_updated_at();

-- ----------------------------------------------------------------------------
-- 5) Row Level Security
-- ----------------------------------------------------------------------------
alter table public.apps            enable row level security;
alter table public.app_memberships enable row level security;
alter table public.global_profiles enable row level security;

-- --- public.apps -----------------------------------------------------------
-- Read-only registry for signed-in users. Writes are service_role-only
-- (service_role bypasses RLS; no write policy is defined for normal users).
drop policy if exists apps_select_authenticated on public.apps;
create policy apps_select_authenticated
  on public.apps
  for select
  to authenticated
  using (true);

-- --- public.app_memberships ------------------------------------------------
-- A user can see only their own memberships.
drop policy if exists app_memberships_select_own on public.app_memberships;
create policy app_memberships_select_own
  on public.app_memberships
  for select
  to authenticated
  using (auth.uid() = user_id);

-- A user can self-join an app, but ONLY as a normal 'user' with 'active'
-- status. This prevents privilege escalation (no self-granting 'admin').
-- Elevation / suspension / removal are performed with the service_role key
-- from trusted server code only.
drop policy if exists app_memberships_insert_self on public.app_memberships;
create policy app_memberships_insert_self
  on public.app_memberships
  for insert
  to authenticated
  with check (
    auth.uid() = user_id
    and role = 'user'
    and status = 'active'
    and exists (select 1 from public.apps a where a.id = app_id and a.status = 'active')
  );

-- (Deliberately no UPDATE/DELETE policy for normal users: role/status changes
--  and membership removal are service_role-only.)

-- --- public.global_profiles ------------------------------------------------
drop policy if exists global_profiles_select_own on public.global_profiles;
create policy global_profiles_select_own
  on public.global_profiles
  for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists global_profiles_insert_own on public.global_profiles;
create policy global_profiles_insert_own
  on public.global_profiles
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists global_profiles_update_own on public.global_profiles;
create policy global_profiles_update_own
  on public.global_profiles
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

commit;

-- ============================================================================
-- Notes for per-app schema tables (goalivo/castfolio/kadit/locawing.*):
--   * Every user-facing table MUST enable RLS.
--   * User-owned rows: add `user_id uuid not null references auth.users(id)`
--     and policy `using (auth.uid() = user_id)` (+ matching with check).
--   * App-shared rows: gate on public.app_memberships, e.g.
--       using (exists (select 1 from public.app_memberships m
--                      where m.user_id = auth.uid()
--                        and m.app_id  = '<app>'
--                        and m.status  = 'active'))
--   * NEVER base authorization on auth.jwt() -> user_metadata (user-editable).
-- The actual per-app tables are created by each app's own follow-up migration
-- once its current schema is finalized (see WIDEGET_CORE_MIGRATION_RUNBOOK.md).
-- ============================================================================
