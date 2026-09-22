-- wideget-core: empty faithful mirror of castfolio TRADING/BATTLE app (source public schema)
-- into wideget-core schema `castfolio`. Source: castfolio project (vrbawgqrhigtkyiengkm).
-- Applied to wideget-core (ossqwphalaxhmadmffsn) 2026-07-08 via MCP. DATA EXCLUDED.
-- IMPORTANT: this app uses its OWN custom auth (castfolio.users w/ password_hash), NOT
-- Supabase auth.users. FKs point to castfolio.users(id). RLS ENABLED on every table with
-- NO authenticated policy => service_role-only (secure default). Authenticated policies to
-- be defined at onboarding (likely after migrating custom users -> Supabase Auth).

grant usage on schema castfolio to authenticated, anon, service_role;

create table if not exists castfolio.users (
  id uuid not null, username varchar(30) not null, email varchar(255) not null,
  password_hash varchar(255) not null, avatar_url varchar(512), bio varchar(500),
  fame_tier varchar(20) not null, trust_score integer not null, influence_score integer not null,
  sp_balance integer not null, language varchar(10) not null, is_premium boolean not null,
  premium_type varchar(20), created_at timestamp not null, updated_at timestamp not null,
  constraint users_pkey primary key (id),
  constraint users_email_key unique (email),
  constraint users_username_key unique (username)
);

create table if not exists castfolio.seasons (
  id uuid not null, name varchar(100) not null, start_date date not null, end_date date not null,
  status varchar(20) not null, created_at timestamp not null,
  constraint seasons_pkey primary key (id)
);

create table if not exists castfolio.strategies (
  id uuid not null, creator_id uuid not null, name varchar(100) not null, description text,
  natural_language_input text not null, conditions_json json, ai_interpretation text,
  market varchar(20) not null, tags varchar[], style varchar(30), source varchar(20) not null,
  status varchar(20) not null, current_snapshot_id uuid, like_count integer not null,
  claim_count integer not null, created_at timestamp not null, updated_at timestamp not null,
  constraint strategies_pkey primary key (id),
  constraint strategies_creator_id_fkey foreign key (creator_id) references castfolio.users(id)
);

create table if not exists castfolio.strategy_snapshots (
  id uuid not null, strategy_id uuid not null, version_number integer not null,
  conditions_json_frozen json, ai_interpretation_frozen text, market_regime_at_creation varchar(20),
  is_verified boolean not null, published_at timestamp,
  constraint strategy_snapshots_pkey primary key (id),
  constraint strategy_snapshots_strategy_id_fkey foreign key (strategy_id) references castfolio.strategies(id)
);

create table if not exists castfolio.backtest_results (
  id uuid not null, snapshot_id uuid not null, period varchar(10) not null,
  market_condition varchar(20) not null, total_return numeric(12,6), alpha numeric(12,6),
  mdd numeric(12,6), win_rate numeric(8,6), trade_count integer, sharpe_ratio numeric(10,4),
  profit_factor numeric(10,4), benchmark_return numeric(12,6), commission_rate numeric(10,6) not null,
  slippage_rate numeric(10,6) not null, calculated_at timestamp not null,
  constraint backtest_results_pkey primary key (id),
  constraint backtest_results_snapshot_id_fkey foreign key (snapshot_id) references castfolio.strategy_snapshots(id)
);

create table if not exists castfolio.signal_boxes (
  id uuid not null, snapshot_id uuid not null, current_price_sp integer not null,
  price_floor integer not null, price_ceiling integer not null, total_unlocks integer not null,
  last_price_calc_at timestamp, created_at timestamp not null,
  constraint signal_boxes_pkey primary key (id),
  constraint signal_boxes_snapshot_id_fkey foreign key (snapshot_id) references castfolio.strategy_snapshots(id)
);

create table if not exists castfolio.battles (
  id uuid not null, title varchar(200), description text, market varchar(20) not null,
  regime_context varchar(20), snapshot_a_id uuid not null, snapshot_b_id uuid not null,
  backtest_period varchar(10), result_a_return numeric(12,6), result_b_return numeric(12,6),
  winner varchar(5), vote_a_count integer not null, vote_b_count integer not null,
  status varchar(20) not null, battle_date date, resolved_at timestamp, created_at timestamp not null,
  constraint battles_pkey primary key (id),
  constraint battles_snapshot_a_id_fkey foreign key (snapshot_a_id) references castfolio.strategy_snapshots(id),
  constraint battles_snapshot_b_id_fkey foreign key (snapshot_b_id) references castfolio.strategy_snapshots(id)
);

create table if not exists castfolio.claims (
  id uuid not null, user_id uuid not null, strategy_id uuid not null, content varchar(140) not null,
  agree_count integer not null, disagree_count integer not null, created_at timestamp not null,
  constraint claims_pkey primary key (id),
  constraint claims_user_id_fkey foreign key (user_id) references castfolio.users(id),
  constraint claims_strategy_id_fkey foreign key (strategy_id) references castfolio.strategies(id)
);

create table if not exists castfolio.box_threads (
  id uuid not null, signal_box_id uuid not null, title varchar(200) not null, created_by uuid not null,
  is_pinned boolean not null, message_count integer not null, created_at timestamp not null,
  constraint box_threads_pkey primary key (id),
  constraint box_threads_signal_box_id_fkey foreign key (signal_box_id) references castfolio.signal_boxes(id),
  constraint box_threads_created_by_fkey foreign key (created_by) references castfolio.users(id)
);

create table if not exists castfolio.box_messages (
  id uuid not null, thread_id uuid not null, user_id uuid not null, content text not null,
  created_at timestamp not null,
  constraint box_messages_pkey primary key (id),
  constraint box_messages_thread_id_fkey foreign key (thread_id) references castfolio.box_threads(id),
  constraint box_messages_user_id_fkey foreign key (user_id) references castfolio.users(id)
);

create table if not exists castfolio.battle_votes (
  user_id uuid not null, battle_id uuid not null, vote varchar(1) not null, created_at timestamp not null,
  constraint battle_votes_pkey primary key (user_id, battle_id),
  constraint battle_votes_user_id_fkey foreign key (user_id) references castfolio.users(id),
  constraint battle_votes_battle_id_fkey foreign key (battle_id) references castfolio.battles(id)
);

create table if not exists castfolio.claim_votes (
  claim_id uuid not null, user_id uuid not null, vote varchar(10) not null, created_at timestamp not null,
  constraint claim_votes_pkey primary key (claim_id, user_id),
  constraint claim_votes_claim_id_fkey foreign key (claim_id) references castfolio.claims(id),
  constraint claim_votes_user_id_fkey foreign key (user_id) references castfolio.users(id)
);

create table if not exists castfolio.follows (
  follower_id uuid not null, following_id uuid not null, created_at timestamp not null,
  constraint follows_pkey primary key (follower_id, following_id),
  constraint follows_follower_id_fkey foreign key (follower_id) references castfolio.users(id),
  constraint follows_following_id_fkey foreign key (following_id) references castfolio.users(id)
);

create table if not exists castfolio.likes (
  user_id uuid not null, strategy_id uuid not null, created_at timestamp not null,
  constraint likes_pkey primary key (user_id, strategy_id),
  constraint likes_user_id_fkey foreign key (user_id) references castfolio.users(id),
  constraint likes_strategy_id_fkey foreign key (strategy_id) references castfolio.strategies(id)
);

create table if not exists castfolio.notifications (
  id uuid not null, user_id uuid not null, type varchar(30) not null, title varchar(200) not null,
  body text, reference_id uuid, reference_type varchar(30), is_read boolean not null,
  created_at timestamp not null,
  constraint notifications_pkey primary key (id),
  constraint notifications_user_id_fkey foreign key (user_id) references castfolio.users(id)
);

create table if not exists castfolio.score_history (
  id uuid not null, user_id uuid not null, season_id uuid, trust_score integer not null,
  influence_score integer not null, fame_tier varchar(20) not null, calculated_at timestamp not null,
  constraint score_history_pkey primary key (id),
  constraint score_history_user_id_fkey foreign key (user_id) references castfolio.users(id),
  constraint score_history_season_id_fkey foreign key (season_id) references castfolio.seasons(id)
);

create table if not exists castfolio.season_results (
  id uuid not null, season_id uuid not null, user_id uuid not null, final_rank integer,
  trust_score_season integer, influence_score_season integer, badge_earned varchar(50),
  reward_choice varchar(50), reward_delivered boolean not null, created_at timestamp not null,
  constraint season_results_pkey primary key (id),
  constraint season_results_user_id_fkey foreign key (user_id) references castfolio.users(id),
  constraint season_results_season_id_fkey foreign key (season_id) references castfolio.seasons(id)
);

create table if not exists castfolio.sp_transactions (
  id uuid not null, user_id uuid not null, amount integer not null, type varchar(30) not null,
  reference_id uuid, balance_after integer not null, created_at timestamp not null,
  constraint sp_transactions_pkey primary key (id),
  constraint sp_transactions_user_id_fkey foreign key (user_id) references castfolio.users(id)
);

create table if not exists castfolio.unlocks (
  id uuid not null, user_id uuid not null, signal_box_id uuid not null, sp_spent integer not null,
  price_at_purchase integer not null, creator_earned_sp integer not null, platform_earned_sp integer not null,
  created_at timestamp not null,
  constraint unlocks_pkey primary key (id),
  constraint uq_unlock_user_box unique (user_id, signal_box_id),
  constraint unlocks_user_id_fkey foreign key (user_id) references castfolio.users(id),
  constraint unlocks_signal_box_id_fkey foreign key (signal_box_id) references castfolio.signal_boxes(id)
);

create table if not exists castfolio.verification_queue (
  id uuid not null, strategy_id uuid not null, priority integer not null, status varchar(20) not null,
  requested_at timestamp not null, started_at timestamp, completed_at timestamp, error_message text,
  constraint verification_queue_pkey primary key (id),
  constraint verification_queue_strategy_id_fkey foreign key (strategy_id) references castfolio.strategies(id)
);

create table if not exists castfolio.weekly_events (
  id uuid not null, season_id uuid not null, title varchar(200) not null, description text,
  start_date date not null, end_date date not null, reward_sp integer not null, status varchar(20) not null,
  created_at timestamp not null,
  constraint weekly_events_pkey primary key (id),
  constraint weekly_events_season_id_fkey foreign key (season_id) references castfolio.seasons(id)
);

-- Enable RLS on all (custom-auth app -> service_role-only until onboarding defines policies)
do $$
declare t text;
begin
  foreach t in array array[
    'users','seasons','strategies','strategy_snapshots','backtest_results','signal_boxes','battles',
    'claims','box_threads','box_messages','battle_votes','claim_votes','follows','likes','notifications',
    'score_history','season_results','sp_transactions','unlocks','verification_queue','weekly_events'
  ] loop
    execute format('alter table castfolio.%s enable row level security', t);
    execute format('grant all on castfolio.%s to service_role', t);
  end loop;
end $$;
