-- Tighten shared-calendar mutation policies around friendships and ownership.

drop policy if exists group_members_update on goalivo.group_members;
create policy group_members_update on goalivo.group_members for update to authenticated
using (
  goalivo.is_group_admin(group_id)
  and user_id <> (select g.owner_user_id from goalivo.groups g where g.id = group_id)
)
with check (
  goalivo.is_group_admin(group_id)
  and role in ('admin', 'member')
  and user_id <> (select g.owner_user_id from goalivo.groups g where g.id = group_id)
);

drop policy if exists group_invitations_insert on goalivo.group_invitations;
create policy group_invitations_insert on goalivo.group_invitations for insert to authenticated
with check (
  inviter_id = (select auth.uid())
  and goalivo.is_group_admin(group_id)
  and goalivo.are_friends(invitee_id)
);

drop policy if exists event_shares_insert on goalivo.event_shares;
create policy event_shares_insert on goalivo.event_shares for insert to authenticated
with check (
  created_by = (select auth.uid())
  and exists (
    select 1 from goalivo.shared_events e
    where e.id = event_id and e.owner_user_id = (select auth.uid())
  )
  and (
    (target_type = 'user' and goalivo.are_friends(target_user_id))
    or (target_type = 'group' and goalivo.is_group_member(target_group_id))
  )
);
