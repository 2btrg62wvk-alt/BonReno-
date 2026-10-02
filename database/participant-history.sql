begin;
create function rd_private.has_quote(project uuid) returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from public.rd_quotes q where q.project_id=project and q.contractor_id=auth.uid())
$$;
revoke all on function rd_private.has_quote(uuid) from public,anon;
grant execute on function rd_private.has_quote(uuid) to authenticated;
alter policy project_read on public.rd_projects using(client_id=(select auth.uid()) or rd_private.has_quote(id) or (status='open' and rd_private.matches_project(service,latitude,longitude)));
create table public.rd_account_details(id uuid primary key references public.rd_profiles(id) on delete cascade,phone text not null default '',legal_company_name text not null default '',address text not null default '',postal text not null default '',website text not null default '');
alter table public.rd_account_details enable row level security;
grant select,insert,update on public.rd_account_details to authenticated;
create policy details_read on public.rd_account_details for select to authenticated using(id=(select auth.uid()));
create policy details_create on public.rd_account_details for insert to authenticated with check(id=(select auth.uid()));
create policy details_edit on public.rd_account_details for update to authenticated using(id=(select auth.uid())) with check(id=(select auth.uid()));
commit;
