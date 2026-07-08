-- Security hardening: pin search_path on updated_at trigger functions.
-- Remediates Supabase advisor 0011_function_search_path_mutable. Bodies unchanged.
-- Idempotent (create or replace). Applied to wideget-core (ossqwphalaxhmadmffsn) 2026-07-08.

create or replace function public.wideget_set_updated_at()
returns trigger language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- Pre-existing Goalivo function from 20260620_enable_realtime_user_state.sql
create or replace function public.set_user_state_updated_at()
returns trigger language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
