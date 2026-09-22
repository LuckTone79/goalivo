-- Goalivo shared calendar foundation.
-- Goalivo only. Personal user_state remains private and unchanged.

create extension if not exists pgcrypto;

create table if not exists goalivo.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  nickname text not null check (char_length(btrim(nickname)) between 2 and 20),
  friend_code text not null unique check (friend_code ~ '^[A-Z0-9]{8}$'),
  avatar_url text,
  timezone text not null default 'Asia/Seoul',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists goalivo.friend_requests (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references auth.users(id) on delete cascade,
  receiver_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted','declined','cancelled','expired')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (sender_id <> receiver_id)
);
create unique index if not exists friend_requests_pending_pair_idx
  on goalivo.friend_requests (least(sender_id, receiver_id), greatest(sender_id, receiver_id))
  where status = 'pending';

create table if not exists goalivo.friendships (
  id uuid primary key default gen_random_uuid(),
  user_a uuid not null references auth.users(id) on delete cascade,
  user_b uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  check (user_a <> user_b), check (user_a < user_b), unique (user_a, user_b)
);

create table if not exists goalivo.groups (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) on delete restrict,
  name text not null check (char_length(btrim(name)) between 1 and 60),
  description text not null default '' check (char_length(description) <= 500),
  color text not null default '#6c8cff' check (color ~ '^#[0-9A-Fa-f]{6}$'),
  posting_policy text not null default 'members' check (posting_policy in ('members','admins_only')),
  status text not null default 'active' check (status in ('active','archived','deleted')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists goalivo.group_members (
  group_id uuid not null references goalivo.groups(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('owner','admin','member')),
  status text not null default 'active' check (status in ('active','invited','left','removed')),
  joined_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (group_id, user_id)
);
create index if not exists group_members_user_status_idx on goalivo.group_members (user_id, status);
create index if not exists group_members_group_status_idx on goalivo.group_members (group_id, status);

create table if not exists goalivo.group_invitations (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references goalivo.groups(id) on delete cascade,
  inviter_id uuid not null references auth.users(id) on delete cascade,
  invitee_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted','declined','cancelled','expired')),
  expires_at timestamptz not null default (now() + interval '7 days'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (inviter_id <> invitee_id)
);
create unique index if not exists group_invitations_pending_idx
  on goalivo.group_invitations (group_id, invitee_id) where status = 'pending';

create table if not exists goalivo.shared_events (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  source_kind text not null default 'goalivo' check (source_kind in ('goalivo','google')),
  source_ref text not null,
  title text not null check (char_length(btrim(title)) between 1 and 300),
  start_at timestamptz,
  end_at timestamptz,
  start_date date,
  end_date date,
  is_all_day boolean not null default false,
  timezone text not null default 'Asia/Seoul',
  memo text not null default '',
  status text not null default 'active' check (status in ('active','cancelled','deleted','sync_paused')),
  version bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((is_all_day and start_date is not null and start_at is null)
      or (not is_all_day and start_at is not null and end_at is not null and end_at > start_at)),
  unique (owner_user_id, source_kind, source_ref)
);

create table if not exists goalivo.event_shares (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references goalivo.shared_events(id) on delete cascade,
  target_type text not null check (target_type in ('user','group')),
  target_user_id uuid references auth.users(id) on delete cascade,
  target_group_id uuid references goalivo.groups(id) on delete cascade,
  access_level text not null default 'title_time' check (access_level in ('time_only','title_time','selected_details')),
  status text not null default 'active' check (status in ('active','revoked','suspended','admin_revoked')),
  suspended_reason text,
  revoked_at timestamptz,
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((target_type = 'user' and target_user_id is not null and target_group_id is null)
      or (target_type = 'group' and target_group_id is not null and target_user_id is null))
);
create unique index if not exists event_shares_user_active_idx
  on goalivo.event_shares (event_id, target_user_id)
  where target_type = 'user' and status in ('active','suspended');
create unique index if not exists event_shares_group_active_idx
  on goalivo.event_shares (event_id, target_group_id)
  where target_type = 'group' and status in ('active','suspended');
create index if not exists event_shares_target_user_idx on goalivo.event_shares (target_user_id, status);
create index if not exists event_shares_target_group_idx on goalivo.event_shares (target_group_id, status);

create table if not exists goalivo.event_share_content (
  event_id uuid primary key references goalivo.shared_events(id) on delete cascade,
  shared_location text,
  shared_link text,
  shared_note text not null default '',
  updated_at timestamptz not null default now()
);

create or replace function goalivo.is_group_member(p_group_id uuid)
returns boolean language sql stable security definer set search_path = goalivo, public
as $$
  select exists (
    select 1 from goalivo.group_members gm
    where gm.group_id = p_group_id and gm.user_id = (select auth.uid()) and gm.status = 'active'
  );
$$;
create or replace function goalivo.is_group_admin(p_group_id uuid)
returns boolean language sql stable security definer set search_path = goalivo, public
as $$
  select exists (
    select 1 from goalivo.group_members gm
    where gm.group_id = p_group_id and gm.user_id = (select auth.uid())
      and gm.status = 'active' and gm.role in ('owner','admin')
  );
$$;
create or replace function goalivo.are_friends(p_other_user_id uuid)
returns boolean language sql stable security definer set search_path = goalivo, public
as $$
  select exists (
    select 1 from goalivo.friendships f
    where (f.user_a = (select auth.uid()) and f.user_b = p_other_user_id)
       or (f.user_b = (select auth.uid()) and f.user_a = p_other_user_id)
  );
$$;
create or replace function goalivo.can_view_shared_event(p_event_id uuid)
returns boolean language sql stable security definer set search_path = goalivo, public
as $$
  select exists (
    select 1 from goalivo.shared_events e
    where e.id = p_event_id and e.status in ('active','cancelled','sync_paused')
      and (e.owner_user_id = (select auth.uid()) or exists (
        select 1 from goalivo.event_shares s
        where s.event_id = e.id and s.status = 'active'
          and ((s.target_type = 'user' and s.target_user_id = (select auth.uid()))
            or (s.target_type = 'group' and goalivo.is_group_member(s.target_group_id)))
      ))
  );
$$;
create or replace function goalivo.find_profile_by_friend_code(p_friend_code text)
returns table(user_id uuid, nickname text, friend_code text)
language sql stable security definer set search_path = goalivo, public
as $$
  select p.user_id, p.nickname, p.friend_code from goalivo.profiles p
  where upper(p.friend_code) = upper(btrim(p_friend_code))
    and p.user_id <> (select auth.uid()) limit 1;
$$;

revoke all on function goalivo.is_group_member(uuid) from public;
revoke all on function goalivo.is_group_admin(uuid) from public;
revoke all on function goalivo.are_friends(uuid) from public;
revoke all on function goalivo.can_view_shared_event(uuid) from public;
revoke all on function goalivo.find_profile_by_friend_code(text) from public;
grant execute on function goalivo.is_group_member(uuid) to authenticated;
grant execute on function goalivo.is_group_admin(uuid) to authenticated;
grant execute on function goalivo.are_friends(uuid) to authenticated;
grant execute on function goalivo.can_view_shared_event(uuid) to authenticated;
grant execute on function goalivo.find_profile_by_friend_code(text) to authenticated;

alter table goalivo.profiles enable row level security;
alter table goalivo.friend_requests enable row level security;
alter table goalivo.friendships enable row level security;
alter table goalivo.groups enable row level security;
alter table goalivo.group_members enable row level security;
alter table goalivo.group_invitations enable row level security;
alter table goalivo.shared_events enable row level security;
alter table goalivo.event_shares enable row level security;
alter table goalivo.event_share_content enable row level security;

grant select, insert, update on goalivo.profiles to authenticated;
grant select, insert, update, delete on goalivo.friend_requests to authenticated;
grant select, insert, delete on goalivo.friendships to authenticated;
grant select, insert, update, delete on goalivo.groups to authenticated;
grant select, insert, update, delete on goalivo.group_members to authenticated;
grant select, insert, update, delete on goalivo.group_invitations to authenticated;
grant select, insert, update, delete on goalivo.shared_events to authenticated;
grant select, insert, update, delete on goalivo.event_shares to authenticated;
grant select, insert, update, delete on goalivo.event_share_content to authenticated;

drop policy if exists profiles_select on goalivo.profiles;
create policy profiles_select on goalivo.profiles for select to authenticated
using (user_id = (select auth.uid()) or goalivo.are_friends(user_id));
drop policy if exists profiles_insert on goalivo.profiles;
create policy profiles_insert on goalivo.profiles for insert to authenticated
with check (user_id = (select auth.uid()));
drop policy if exists profiles_update on goalivo.profiles;
create policy profiles_update on goalivo.profiles for update to authenticated
using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

drop policy if exists friend_requests_select on goalivo.friend_requests;
create policy friend_requests_select on goalivo.friend_requests for select to authenticated
using (sender_id = (select auth.uid()) or receiver_id = (select auth.uid()));
drop policy if exists friend_requests_insert on goalivo.friend_requests;
create policy friend_requests_insert on goalivo.friend_requests for insert to authenticated
with check (sender_id = (select auth.uid()) and sender_id <> receiver_id);
drop policy if exists friend_requests_update on goalivo.friend_requests;
create policy friend_requests_update on goalivo.friend_requests for update to authenticated
using (sender_id = (select auth.uid()) or receiver_id = (select auth.uid()))
with check (sender_id = (select auth.uid()) or receiver_id = (select auth.uid()));
drop policy if exists friend_requests_delete on goalivo.friend_requests;
create policy friend_requests_delete on goalivo.friend_requests for delete to authenticated
using (sender_id = (select auth.uid()) or receiver_id = (select auth.uid()));

drop policy if exists friendships_select on goalivo.friendships;
create policy friendships_select on goalivo.friendships for select to authenticated
using (user_a = (select auth.uid()) or user_b = (select auth.uid()));
drop policy if exists friendships_insert on goalivo.friendships;
create policy friendships_insert on goalivo.friendships for insert to authenticated
with check (user_a = (select auth.uid()) or user_b = (select auth.uid()));
drop policy if exists friendships_delete on goalivo.friendships;
create policy friendships_delete on goalivo.friendships for delete to authenticated
using (user_a = (select auth.uid()) or user_b = (select auth.uid()));

drop policy if exists groups_select on goalivo.groups;
create policy groups_select on goalivo.groups for select to authenticated
using (owner_user_id = (select auth.uid()) or goalivo.is_group_member(id));
drop policy if exists groups_insert on goalivo.groups;
create policy groups_insert on goalivo.groups for insert to authenticated
with check (owner_user_id = (select auth.uid()));
drop policy if exists groups_update on goalivo.groups;
create policy groups_update on goalivo.groups for update to authenticated
using (owner_user_id = (select auth.uid()) or goalivo.is_group_admin(id))
with check (owner_user_id = (select auth.uid()) or goalivo.is_group_admin(id));
drop policy if exists groups_delete on goalivo.groups;
create policy groups_delete on goalivo.groups for delete to authenticated
using (owner_user_id = (select auth.uid()));

drop policy if exists group_members_select on goalivo.group_members;
create policy group_members_select on goalivo.group_members for select to authenticated
using (user_id = (select auth.uid()) or goalivo.is_group_member(group_id));
drop policy if exists group_members_insert on goalivo.group_members;
create policy group_members_insert on goalivo.group_members for insert to authenticated
with check (
  (user_id = (select auth.uid()) and exists (
    select 1 from goalivo.groups g where g.id = group_id and g.owner_user_id = (select auth.uid())
  )) or (user_id = (select auth.uid()) and exists (
    select 1 from goalivo.group_invitations gi
    where gi.group_id = group_id and gi.invitee_id = (select auth.uid())
      and gi.status = 'pending' and gi.expires_at > now()
  )) or goalivo.is_group_admin(group_id)
);
drop policy if exists group_members_update on goalivo.group_members;
create policy group_members_update on goalivo.group_members for update to authenticated
using (goalivo.is_group_admin(group_id)) with check (goalivo.is_group_admin(group_id));
drop policy if exists group_members_delete on goalivo.group_members;
create policy group_members_delete on goalivo.group_members for delete to authenticated
using (user_id = (select auth.uid()) or goalivo.is_group_admin(group_id));

drop policy if exists group_invitations_select on goalivo.group_invitations;
create policy group_invitations_select on goalivo.group_invitations for select to authenticated
using (inviter_id = (select auth.uid()) or invitee_id = (select auth.uid()) or goalivo.is_group_member(group_id));
drop policy if exists group_invitations_insert on goalivo.group_invitations;
create policy group_invitations_insert on goalivo.group_invitations for insert to authenticated
with check (inviter_id = (select auth.uid()) and goalivo.is_group_admin(group_id));
drop policy if exists group_invitations_update on goalivo.group_invitations;
create policy group_invitations_update on goalivo.group_invitations for update to authenticated
using (invitee_id = (select auth.uid()) or inviter_id = (select auth.uid()) or goalivo.is_group_admin(group_id))
with check (invitee_id = (select auth.uid()) or inviter_id = (select auth.uid()) or goalivo.is_group_admin(group_id));

drop policy if exists shared_events_select on goalivo.shared_events;
create policy shared_events_select on goalivo.shared_events for select to authenticated
using (goalivo.can_view_shared_event(id));
drop policy if exists shared_events_insert on goalivo.shared_events;
create policy shared_events_insert on goalivo.shared_events for insert to authenticated
with check (owner_user_id = (select auth.uid()));
drop policy if exists shared_events_update on goalivo.shared_events;
create policy shared_events_update on goalivo.shared_events for update to authenticated
using (owner_user_id = (select auth.uid())) with check (owner_user_id = (select auth.uid()));
drop policy if exists shared_events_delete on goalivo.shared_events;
create policy shared_events_delete on goalivo.shared_events for delete to authenticated
using (owner_user_id = (select auth.uid()));

drop policy if exists event_shares_select on goalivo.event_shares;
create policy event_shares_select on goalivo.event_shares for select to authenticated
using (
  exists (select 1 from goalivo.shared_events e where e.id = event_id and e.owner_user_id = (select auth.uid()))
  or (target_type = 'user' and target_user_id = (select auth.uid()))
  or (target_type = 'group' and goalivo.is_group_member(target_group_id))
);
drop policy if exists event_shares_insert on goalivo.event_shares;
create policy event_shares_insert on goalivo.event_shares for insert to authenticated
with check (created_by = (select auth.uid()) and exists (
  select 1 from goalivo.shared_events e where e.id = event_id and e.owner_user_id = (select auth.uid())
));
drop policy if exists event_shares_update on goalivo.event_shares;
create policy event_shares_update on goalivo.event_shares for update to authenticated
using (
  exists (select 1 from goalivo.shared_events e where e.id = event_id and e.owner_user_id = (select auth.uid()))
  or (target_type = 'group' and goalivo.is_group_admin(target_group_id))
)
with check (
  exists (select 1 from goalivo.shared_events e where e.id = event_id and e.owner_user_id = (select auth.uid()))
  or (target_type = 'group' and goalivo.is_group_admin(target_group_id))
);
drop policy if exists event_shares_delete on goalivo.event_shares;
create policy event_shares_delete on goalivo.event_shares for delete to authenticated
using (
  exists (select 1 from goalivo.shared_events e where e.id = event_id and e.owner_user_id = (select auth.uid()))
  or (target_type = 'group' and goalivo.is_group_admin(target_group_id))
);

drop policy if exists event_share_content_select on goalivo.event_share_content;
create policy event_share_content_select on goalivo.event_share_content for select to authenticated
using (exists (select 1 from goalivo.shared_events e where e.id = event_id and goalivo.can_view_shared_event(e.id)));
drop policy if exists event_share_content_insert on goalivo.event_share_content;
create policy event_share_content_insert on goalivo.event_share_content for insert to authenticated
with check (exists (select 1 from goalivo.shared_events e where e.id = event_id and e.owner_user_id = (select auth.uid())));
drop policy if exists event_share_content_update on goalivo.event_share_content;
create policy event_share_content_update on goalivo.event_share_content for update to authenticated
using (exists (select 1 from goalivo.shared_events e where e.id = event_id and e.owner_user_id = (select auth.uid())))
with check (exists (select 1 from goalivo.shared_events e where e.id = event_id and e.owner_user_id = (select auth.uid())));

drop trigger if exists goalivo_profiles_updated_at on goalivo.profiles;
create trigger goalivo_profiles_updated_at before update on goalivo.profiles for each row execute function public.wideget_set_updated_at();
drop trigger if exists goalivo_friend_requests_updated_at on goalivo.friend_requests;
create trigger goalivo_friend_requests_updated_at before update on goalivo.friend_requests for each row execute function public.wideget_set_updated_at();
drop trigger if exists goalivo_groups_updated_at on goalivo.groups;
create trigger goalivo_groups_updated_at before update on goalivo.groups for each row execute function public.wideget_set_updated_at();
drop trigger if exists goalivo_group_members_updated_at on goalivo.group_members;
create trigger goalivo_group_members_updated_at before update on goalivo.group_members for each row execute function public.wideget_set_updated_at();
drop trigger if exists goalivo_group_invitations_updated_at on goalivo.group_invitations;
create trigger goalivo_group_invitations_updated_at before update on goalivo.group_invitations for each row execute function public.wideget_set_updated_at();
drop trigger if exists goalivo_shared_events_updated_at on goalivo.shared_events;
create trigger goalivo_shared_events_updated_at before update on goalivo.shared_events for each row execute function public.wideget_set_updated_at();
drop trigger if exists goalivo_event_shares_updated_at on goalivo.event_shares;
create trigger goalivo_event_shares_updated_at before update on goalivo.event_shares for each row execute function public.wideget_set_updated_at();
drop trigger if exists goalivo_event_share_content_updated_at on goalivo.event_share_content;
create trigger goalivo_event_share_content_updated_at before update on goalivo.event_share_content for each row execute function public.wideget_set_updated_at();

comment on table goalivo.shared_events is 'Goalivo events explicitly shared with a user or group.';
comment on table goalivo.event_shares is 'Per-target sharing policy with access-level filtering.';
