-- Replace the table-wide SELECT grant with only non-sensitive source columns.
-- Owner reads and writes use the masked feed plus explicit safe return columns.

revoke select on goalivo.shared_events from authenticated;
grant select (
  id,
  owner_user_id,
  source_kind,
  source_ref,
  start_at,
  end_at,
  start_date,
  end_date,
  is_all_day,
  timezone,
  status,
  version,
  created_at,
  updated_at
) on goalivo.shared_events to authenticated;
