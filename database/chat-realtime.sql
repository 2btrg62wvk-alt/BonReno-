-- Realtime delivers only messages permitted by the existing message_read RLS.
-- No new grants, public access, or changes to participant policies.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = 'rd_messages'
  ) then
    alter publication supabase_realtime add table public.rd_messages;
  end if;
end $$;
