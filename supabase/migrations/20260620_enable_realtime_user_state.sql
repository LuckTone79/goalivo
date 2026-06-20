-- Cross-device real-time sync for user_state
-- Applied to Supabase project "Goalivo" (ossqwphalaxhmadmffsn) on 2026-06-20.
--
-- Why: tasks added on one device were not appearing on another in real time.
-- The client stores the whole app state as a single JSONB row in public.user_state
-- (one row per user_id). This migration enables instant cross-device propagation
-- and reliable last-write timestamps. All changes are additive / non-destructive.

-- 1) Realtime: broadcast changes to public.user_state so other devices pull instantly.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'user_state'
  ) then
    execute 'alter publication supabase_realtime add table public.user_state';
  end if;
end$$;

-- 2) Ship the full row on UPDATE/DELETE realtime events.
alter table public.user_state replica identity full;

-- 3) Reliable updated_at (used by the client for echo-suppression / last-write-wins).
alter table public.user_state alter column updated_at set default now();

create or replace function public.set_user_state_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_user_state_updated_at on public.user_state;
create trigger trg_user_state_updated_at
  before insert or update on public.user_state
  for each row execute function public.set_user_state_updated_at();
