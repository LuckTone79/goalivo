-- wideget-core: empty faithful mirror of kadit app tables into schema `kadit`.
-- Source: kadit project (chkjnszxisljiywjtqve). DATA EXCLUDED. Structure + RLS only.
-- Applied to wideget-core (ossqwphalaxhmadmffsn) 2026-07-08 via MCP.
-- Table names kept identical (kadit.kadit_*) for a provable 1:1 data-migration mapping.

grant usage on schema kadit to authenticated, anon, service_role;

create table if not exists kadit.kadit_generation_schedules (
  id uuid not null default gen_random_uuid(),
  user_id uuid not null,
  name text not null,
  topic text not null,
  source_feeds jsonb not null default '[]'::jsonb,
  card_count integer not null default 5,
  tone_id text not null default 'news',
  theme_id text not null default 'dark-news',
  font_id text,
  frequency text not null default 'daily',
  local_time text not null default '07:00',
  timezone text not null default 'Asia/Seoul',
  cron_expression text,
  enabled boolean not null default true,
  last_run_at timestamptz,
  next_run_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint kadit_generation_schedules_pkey primary key (id),
  constraint kadit_generation_schedules_card_count_check check (card_count >= 4 and card_count <= 10),
  constraint kadit_generation_schedules_frequency_check check (frequency = any (array['daily','weekly','once'])),
  constraint kadit_generation_schedules_user_id_fkey foreign key (user_id) references auth.users(id) on delete cascade
);

create table if not exists kadit.kadit_source_feeds (
  id uuid not null default gen_random_uuid(),
  user_id uuid not null,
  schedule_id uuid,
  topic text not null,
  source_type text not null,
  source_url text,
  account_name text,
  hashtag text,
  keyword text,
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint kadit_source_feeds_pkey primary key (id),
  constraint kadit_source_feeds_source_type_check check (source_type = any (array['rss','web','manual','x','instagram','threads','youtube'])),
  constraint kadit_source_feeds_user_id_fkey foreign key (user_id) references auth.users(id) on delete cascade,
  constraint kadit_source_feeds_schedule_id_fkey foreign key (schedule_id) references kadit.kadit_generation_schedules(id) on delete cascade
);

create table if not exists kadit.kadit_source_items (
  id uuid not null default gen_random_uuid(),
  user_id uuid not null,
  feed_id uuid,
  schedule_id uuid,
  topic text not null,
  source_type text not null,
  title text not null,
  text text not null,
  url text,
  author text,
  published_at timestamptz,
  metrics jsonb,
  raw_summary text,
  score numeric not null default 0,
  created_at timestamptz not null default now(),
  media jsonb not null default '[]'::jsonb,
  constraint kadit_source_items_pkey primary key (id),
  constraint kadit_source_items_user_id_fkey foreign key (user_id) references auth.users(id) on delete cascade,
  constraint kadit_source_items_schedule_id_fkey foreign key (schedule_id) references kadit.kadit_generation_schedules(id) on delete cascade,
  constraint kadit_source_items_feed_id_fkey foreign key (feed_id) references kadit.kadit_source_feeds(id) on delete set null
);

create table if not exists kadit.kadit_scheduled_runs (
  id uuid not null default gen_random_uuid(),
  user_id uuid not null,
  schedule_id uuid not null,
  status text not null default 'pending',
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  project_id text,
  source_item_ids uuid[] not null default '{}'::uuid[],
  source_snapshot jsonb,
  error_code text,
  error_message text,
  constraint kadit_scheduled_runs_pkey primary key (id),
  constraint kadit_scheduled_runs_status_check check (status = any (array['pending','running','succeeded','failed','skipped'])),
  constraint kadit_scheduled_runs_user_id_fkey foreign key (user_id) references auth.users(id) on delete cascade,
  constraint kadit_scheduled_runs_schedule_id_fkey foreign key (schedule_id) references kadit.kadit_generation_schedules(id) on delete cascade
);

create table if not exists kadit.kadit_artifacts (
  project_id text not null,
  kind text not null,
  lang text not null default 'ko',
  card_index integer not null default 0,
  data jsonb,
  content text,
  updated_at timestamptz not null default now(),
  user_id uuid,
  constraint kadit_artifacts_pkey primary key (project_id, kind, lang, card_index),
  constraint kadit_artifacts_user_id_fkey foreign key (user_id) references auth.users(id) on delete set null
);

create table if not exists kadit.kadit_image_jobs (
  id text not null,
  project_id text not null,
  card_index integer not null,
  status text not null default 'queued',
  prompt text not null,
  quality text not null default 'medium',
  model text not null,
  result_image_url text,
  error_code text,
  error_message text,
  progress integer not null default 0,
  attempt_count integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  started_at timestamptz,
  completed_at timestamptz,
  user_id uuid,
  constraint kadit_image_jobs_pkey primary key (id),
  constraint kadit_image_jobs_card_index_check check (card_index >= 1 and card_index <= 10),
  constraint kadit_image_jobs_quality_check check (quality = any (array['low','medium','high'])),
  constraint kadit_image_jobs_progress_check check (progress >= 0 and progress <= 100),
  constraint kadit_image_jobs_user_id_fkey foreign key (user_id) references auth.users(id) on delete set null
);

create table if not exists kadit.kadit_render_jobs (
  id text not null,
  project_id text not null,
  status text not null default 'queued',
  output_format text not null default 'png',
  width integer not null default 1080,
  height integer not null default 1920,
  card_count integer not null,
  requested_card_indexes integer[] not null,
  attempt_count integer not null default 0,
  max_attempts integer not null default 3,
  locked_at timestamptz,
  locked_by text,
  output_paths jsonb default '[]'::jsonb,
  failure_details jsonb default '[]'::jsonb,
  error_code text,
  error_message text,
  worker_kind text not null default 'inline',
  external_job_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  started_at timestamptz,
  completed_at timestamptz,
  user_id uuid,
  constraint kadit_render_jobs_pkey primary key (id),
  constraint kadit_render_jobs_worker_kind_check check (worker_kind = any (array['inline','external'])),
  constraint kadit_render_jobs_output_format_check check (output_format = any (array['png','jpeg','webp'])),
  constraint kadit_render_jobs_card_count_check check (card_count >= 1 and card_count <= 10),
  constraint kadit_render_jobs_user_id_fkey foreign key (user_id) references auth.users(id) on delete set null
);

create table if not exists kadit.kadit_renders (
  project_id text not null,
  lang text not null default 'ko',
  card_index integer not null,
  bytes_b64 text not null,
  byte_len integer not null,
  width integer not null default 1080,
  height integer not null default 1920,
  rendered_at timestamptz not null default now(),
  user_id uuid,
  constraint kadit_renders_pkey primary key (project_id, lang, card_index),
  constraint kadit_renders_user_id_fkey foreign key (user_id) references auth.users(id) on delete set null
);

create table if not exists kadit.kadit_versions (
  version_id text not null,
  project_id text not null,
  lang text not null default 'ko',
  snapshot_type text not null,
  change_summary text not null,
  before_card_count integer,
  after_card_count integer,
  content_snapshot jsonb,
  created_at timestamptz not null default now(),
  user_id uuid,
  constraint kadit_versions_pkey primary key (version_id),
  constraint kadit_versions_user_id_fkey foreign key (user_id) references auth.users(id) on delete set null
);

do $$
declare t text;
begin
  foreach t in array array['kadit_generation_schedules','kadit_source_feeds','kadit_artifacts','kadit_image_jobs','kadit_render_jobs'] loop
    execute format('drop trigger if exists trg_%1$s_updated_at on kadit.%1$s', t);
    execute format('create trigger trg_%1$s_updated_at before insert or update on kadit.%1$s for each row execute function public.wideget_set_updated_at()', t);
  end loop;
end $$;

do $$
declare t text;
begin
  foreach t in array array['kadit_generation_schedules','kadit_source_feeds','kadit_source_items','kadit_scheduled_runs','kadit_artifacts','kadit_image_jobs','kadit_render_jobs','kadit_renders','kadit_versions'] loop
    execute format('alter table kadit.%s enable row level security', t);
    execute format('grant select, insert, update, delete on kadit.%s to authenticated', t);
    execute format('grant all on kadit.%s to service_role', t);
    execute format('drop policy if exists %1$s_rw_own on kadit.%1$s', t);
    execute format('create policy %1$s_rw_own on kadit.%1$s for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id)', t);
  end loop;
end $$;
