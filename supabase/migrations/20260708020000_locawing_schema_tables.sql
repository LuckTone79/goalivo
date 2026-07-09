-- wideget-core: empty faithful mirror of locawing app tables into schema `locawing`.
-- Source: locawing project (nkizvcbesznhvwgskxhy). DATA EXCLUDED. Structure + RLS only.
-- Applied to wideget-core (ossqwphalaxhmadmffsn) 2026-07-08 via MCP.
-- Note: user_id FKs point to locawing.profiles(id); profiles.id -> auth.users(id).

grant usage on schema locawing to authenticated, anon, service_role;

create table if not exists locawing.profiles (
  id uuid not null,
  email text,
  role text not null default 'owner',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_pkey primary key (id),
  constraint profiles_id_fkey foreign key (id) references auth.users(id) on delete cascade
);

create table if not exists locawing.devices (
  id uuid not null default gen_random_uuid(),
  user_id uuid not null,
  name text not null,
  platform text not null,
  device_type text not null default 'test_device',
  connection_mode text not null,
  status text not null default 'offline',
  is_main_phone boolean not null default false,
  last_seen_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint devices_pkey primary key (id),
  constraint devices_platform_check check (platform = any (array['ios','android','windows_helper'])),
  constraint devices_connection_mode_check check (connection_mode = any (array['agent','helper','test_sdk','gpx'])),
  constraint devices_user_id_fkey foreign key (user_id) references locawing.profiles(id) on delete cascade
);

create table if not exists locawing.scenarios (
  id uuid not null default gen_random_uuid(),
  user_id uuid not null,
  scenario_key text not null,
  name text not null,
  type text not null,
  mode text not null,
  speed_kmh numeric not null,
  playback_interval_ms integer not null default 1000,
  status text not null default 'draft',
  origin_lat numeric not null,
  origin_lng numeric not null,
  destination_lat numeric,
  destination_lng numeric,
  total_distance_m numeric not null default 0,
  estimated_duration_sec integer not null default 0,
  scenario_json jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint scenarios_pkey primary key (id),
  constraint scenarios_user_id_scenario_key_key unique (user_id, scenario_key),
  constraint scenarios_type_check check (type = any (array['teleport','route','block_visit','schedule'])),
  constraint scenarios_mode_check check (mode = any (array['driving','walking'])),
  constraint scenarios_user_id_fkey foreign key (user_id) references locawing.profiles(id) on delete cascade
);

create table if not exists locawing.blocks (
  id uuid not null default gen_random_uuid(),
  scenario_id uuid not null,
  block_id text not null,
  polygon_json jsonb not null,
  center_lat numeric not null,
  center_lng numeric not null,
  visit_order integer,
  visited boolean not null default false,
  created_at timestamptz not null default now(),
  constraint blocks_pkey primary key (id),
  constraint blocks_scenario_id_fkey foreign key (scenario_id) references locawing.scenarios(id) on delete cascade
);

create table if not exists locawing.scenario_points (
  id uuid not null default gen_random_uuid(),
  scenario_id uuid not null,
  order_index integer not null,
  lat numeric not null,
  lng numeric not null,
  offset_ms integer not null,
  speed_kmh numeric not null,
  accuracy_m numeric,
  source_type text not null,
  created_at timestamptz not null default now(),
  constraint scenario_points_pkey primary key (id),
  constraint scenario_points_scenario_id_order_index_key unique (scenario_id, order_index),
  constraint scenario_points_source_type_check check (source_type = any (array['route','block_center','manual','schedule'])),
  constraint scenario_points_scenario_id_fkey foreign key (scenario_id) references locawing.scenarios(id) on delete cascade
);

create table if not exists locawing.schedules (
  id uuid not null default gen_random_uuid(),
  user_id uuid not null,
  scenario_id uuid,
  target_time timestamptz not null,
  target_lat numeric not null,
  target_lng numeric not null,
  movement_mode text not null,
  status text not null default 'scheduled',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint schedules_pkey primary key (id),
  constraint schedules_movement_mode_check check (movement_mode = any (array['instant','natural'])),
  constraint schedules_user_id_fkey foreign key (user_id) references locawing.profiles(id) on delete cascade,
  constraint schedules_scenario_id_fkey foreign key (scenario_id) references locawing.scenarios(id) on delete cascade
);

create table if not exists locawing.test_reports (
  id uuid not null default gen_random_uuid(),
  user_id uuid not null,
  scenario_id uuid,
  title text not null,
  summary text not null,
  report_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint test_reports_pkey primary key (id),
  constraint test_reports_user_id_fkey foreign key (user_id) references locawing.profiles(id) on delete cascade,
  constraint test_reports_scenario_id_fkey foreign key (scenario_id) references locawing.scenarios(id) on delete set null
);

create table if not exists locawing.commands (
  id uuid not null default gen_random_uuid(),
  user_id uuid not null,
  device_id uuid,
  scenario_id uuid,
  command_type text not null,
  payload_json jsonb not null default '{}'::jsonb,
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  received_at timestamptz,
  completed_at timestamptz,
  constraint commands_pkey primary key (id),
  constraint commands_command_type_check check (command_type = any (array['start','pause','resume','stop','emergency_stop','recover','ping'])),
  constraint commands_status_check check (status = any (array['pending','received','running','done','failed','cancelled'])),
  constraint commands_user_id_fkey foreign key (user_id) references locawing.profiles(id) on delete cascade,
  constraint commands_device_id_fkey foreign key (device_id) references locawing.devices(id) on delete set null,
  constraint commands_scenario_id_fkey foreign key (scenario_id) references locawing.scenarios(id) on delete set null
);

create table if not exists locawing.location_logs (
  id uuid not null default gen_random_uuid(),
  scenario_id uuid,
  device_id uuid,
  lat numeric,
  lng numeric,
  speed_kmh numeric,
  accuracy_m numeric,
  event_type text not null,
  offset_ms integer,
  message text,
  created_at timestamptz not null default now(),
  constraint location_logs_pkey primary key (id),
  constraint location_logs_event_type_check check (event_type = any (array['start','move','pause','resume','arrive','stop','emergency_stop','error','recovery_confirmed'])),
  constraint location_logs_scenario_id_fkey foreign key (scenario_id) references locawing.scenarios(id) on delete set null,
  constraint location_logs_device_id_fkey foreign key (device_id) references locawing.devices(id) on delete set null
);

-- updated_at triggers
do $$
declare t text;
begin
  foreach t in array array['profiles','devices','scenarios','schedules'] loop
    execute format('drop trigger if exists trg_%1$s_updated_at on locawing.%1$s', t);
    execute format('create trigger trg_%1$s_updated_at before insert or update on locawing.%1$s for each row execute function public.wideget_set_updated_at()', t);
  end loop;
end $$;

-- grants + enable RLS for all
do $$
declare t text;
begin
  foreach t in array array['profiles','devices','scenarios','blocks','scenario_points','schedules','test_reports','commands','location_logs'] loop
    execute format('alter table locawing.%s enable row level security', t);
    execute format('grant select, insert, update, delete on locawing.%s to authenticated', t);
    execute format('grant all on locawing.%s to service_role', t);
  end loop;
end $$;

drop policy if exists profiles_rw_own on locawing.profiles;
create policy profiles_rw_own on locawing.profiles for all to authenticated
  using (auth.uid() = id) with check (auth.uid() = id);

do $$
declare t text;
begin
  foreach t in array array['devices','scenarios','schedules','test_reports','commands'] loop
    execute format('drop policy if exists %1$s_rw_own on locawing.%1$s', t);
    execute format('create policy %1$s_rw_own on locawing.%1$s for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id)', t);
  end loop;
end $$;

do $$
declare t text;
begin
  foreach t in array array['blocks','scenario_points'] loop
    execute format('drop policy if exists %1$s_rw_via_scenario on locawing.%1$s', t);
    execute format($f$create policy %1$s_rw_via_scenario on locawing.%1$s for all to authenticated
      using (exists (select 1 from locawing.scenarios s where s.id = %1$s.scenario_id and s.user_id = auth.uid()))
      with check (exists (select 1 from locawing.scenarios s where s.id = %1$s.scenario_id and s.user_id = auth.uid()))$f$, t);
  end loop;
end $$;

drop policy if exists location_logs_rw_own on locawing.location_logs;
create policy location_logs_rw_own on locawing.location_logs for all to authenticated
  using (
    exists (select 1 from locawing.devices d where d.id = location_logs.device_id and d.user_id = auth.uid())
    or exists (select 1 from locawing.scenarios s where s.id = location_logs.scenario_id and s.user_id = auth.uid())
  )
  with check (
    exists (select 1 from locawing.devices d where d.id = location_logs.device_id and d.user_id = auth.uid())
    or exists (select 1 from locawing.scenarios s where s.id = location_logs.scenario_id and s.user_id = auth.uid())
  );
