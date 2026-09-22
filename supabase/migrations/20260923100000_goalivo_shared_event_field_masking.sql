-- Expose shared event rows through a server-masked feed.
-- The raw title and memo columns remain owner-writeable, but are no longer
-- selectable by the authenticated role. Recipients only receive fields allowed
-- by their active share target and access level.

create or replace view goalivo.shared_event_feed as
select
  e.id,
  e.owner_user_id,
  e.source_kind,
  e.source_ref,
  case
    when e.owner_user_id = (select auth.uid()) then e.title
    when exists (
      select 1 from goalivo.event_shares s
      where s.event_id = e.id
        and s.status = 'active'
        and s.access_level in ('title_time', 'selected_details')
        and (
          (s.target_type = 'user' and s.target_user_id = (select auth.uid()))
          or (s.target_type = 'group' and goalivo.is_group_member(s.target_group_id))
        )
    ) then e.title
    else '공유된 일정'
  end as title,
  e.start_at,
  e.end_at,
  e.start_date,
  e.end_date,
  e.is_all_day,
  e.timezone,
  case
    when e.owner_user_id = (select auth.uid()) then e.memo
    when exists (
      select 1 from goalivo.event_shares s
      where s.event_id = e.id
        and s.status = 'active'
        and s.access_level = 'selected_details'
        and (
          (s.target_type = 'user' and s.target_user_id = (select auth.uid()))
          or (s.target_type = 'group' and goalivo.is_group_member(s.target_group_id))
        )
    ) then coalesce((
      select c.shared_note
      from goalivo.event_share_content c
      where c.event_id = e.id
    ), '')
    else ''
  end as memo,
  e.status,
  e.version,
  e.created_at,
  e.updated_at,
  coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', s.id,
      'target_type', s.target_type,
      'target_user_id', s.target_user_id,
      'target_group_id', s.target_group_id,
      'access_level', s.access_level,
      'status', s.status,
      'suspended_reason', s.suspended_reason,
      'revoked_at', s.revoked_at,
      'created_by', s.created_by,
      'created_at', s.created_at,
      'updated_at', s.updated_at
    ) order by s.created_at)
    from goalivo.event_shares s
    where s.event_id = e.id
      and s.status in ('active', 'suspended')
      and (
        e.owner_user_id = (select auth.uid())
        or (s.target_type = 'user' and s.target_user_id = (select auth.uid()))
        or (s.target_type = 'group' and goalivo.is_group_member(s.target_group_id))
      )
  ), '[]'::jsonb) as event_shares
from goalivo.shared_events e
where goalivo.can_view_shared_event(e.id);

grant select on goalivo.shared_event_feed to authenticated;
revoke select (title, memo) on goalivo.shared_events from authenticated;
