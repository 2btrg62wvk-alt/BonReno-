begin;
create index if not exists rd_messages_sender_idx on public.rd_messages(sender_id);
create index if not exists rd_project_photos_project_idx on public.rd_project_photos(project_id);
create index if not exists rd_projects_accepted_quote_idx on public.rd_projects(accepted_quote_id);
commit;
