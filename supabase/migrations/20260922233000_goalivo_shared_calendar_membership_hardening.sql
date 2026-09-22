-- Tighten state transitions that must be performed by the receiving user or owner.

drop policy if exists friend_requests_update on goalivo.friend_requests;
create policy friend_requests_update on goalivo.friend_requests for update to authenticated
using (sender_id = (select auth.uid()) or receiver_id = (select auth.uid()))
with check (
  (status = 'accepted' and receiver_id = (select auth.uid()))
  or (status = 'declined' and receiver_id = (select auth.uid()))
  or (status = 'cancelled' and sender_id = (select auth.uid()))
  or (status = 'pending' and sender_id = (select auth.uid()))
);

drop policy if exists friendships_insert on goalivo.friendships;
create policy friendships_insert on goalivo.friendships for insert to authenticated
with check (
  (user_a = (select auth.uid()) or user_b = (select auth.uid()))
  and exists (
    select 1
    from goalivo.friend_requests fr
    where fr.status = 'accepted'
      and ((fr.sender_id = user_a and fr.receiver_id = user_b)
        or (fr.sender_id = user_b and fr.receiver_id = user_a))
  )
);

drop policy if exists group_members_update on goalivo.group_members;
create policy group_members_update on goalivo.group_members for update to authenticated
using (
  goalivo.is_group_admin(group_id)
  and user_id <> (select g.owner_user_id from goalivo.groups g where g.id = group_id)
  and (role <> 'admin' or (select g.owner_user_id from goalivo.groups g where g.id = group_id) = (select auth.uid()))
)
with check (
  goalivo.is_group_admin(group_id)
  and role in ('admin', 'member')
  and user_id <> (select g.owner_user_id from goalivo.groups g where g.id = group_id)
);

drop policy if exists group_members_delete on goalivo.group_members;
create policy group_members_delete on goalivo.group_members for delete to authenticated
using (
  user_id <> (select g.owner_user_id from goalivo.groups g where g.id = group_id)
  and (user_id = (select auth.uid()) or goalivo.is_group_admin(group_id))
);
