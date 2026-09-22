-- Goalivo shared calendar foreign-key indexes.
create index if not exists friend_requests_sender_idx on goalivo.friend_requests(sender_id, status);
create index if not exists friend_requests_receiver_idx on goalivo.friend_requests(receiver_id, status);
create index if not exists friendships_user_a_idx on goalivo.friendships(user_a);
create index if not exists friendships_user_b_idx on goalivo.friendships(user_b);
create index if not exists groups_owner_idx on goalivo.groups(owner_user_id, status);
create index if not exists group_invitations_group_idx on goalivo.group_invitations(group_id, status);
create index if not exists group_invitations_inviter_idx on goalivo.group_invitations(inviter_id, status);
create index if not exists group_invitations_invitee_idx on goalivo.group_invitations(invitee_id, status);
create index if not exists shared_events_owner_idx on goalivo.shared_events(owner_user_id, status);
create index if not exists event_shares_created_by_idx on goalivo.event_shares(created_by, status);
create index if not exists event_share_content_event_idx on goalivo.event_share_content(event_id);
