begin;
create table public.rd_business_pages (
 id uuid primary key references public.rd_profiles(id) on delete cascade,
 tagline text not null default '' check(length(tagline)<=120),
 bio text not null default '' check(length(bio)<=3000),
 experience_years integer check(experience_years between 0 and 100),
 insurance_declared boolean not null default false,
 cover_path text check(cover_path is null or cover_path ~ ('^'||id::text||'/[a-f0-9-]+\.jpg$')),
 logo_path text check(logo_path is null or logo_path ~ ('^'||id::text||'/[a-f0-9-]+\.jpg$'))
);
create table public.rd_portfolio (
 id uuid primary key default gen_random_uuid(),
 contractor_id uuid not null references public.rd_profiles(id) on delete cascade,
 title text not null check(length(trim(title)) between 1 and 120),
 description text not null default '' check(length(description)<=1500),
 city text not null default '' check(length(city)<=120),
 before_path text check(before_path is null or before_path ~ ('^'||contractor_id::text||'/[a-f0-9-]+\.jpg$')),
 after_path text check(after_path is null or after_path ~ ('^'||contractor_id::text||'/[a-f0-9-]+\.jpg$')),
 created_at timestamptz not null default now(),
 check(before_path is not null or after_path is not null)
);
create index rd_portfolio_owner_idx on public.rd_portfolio(contractor_id,created_at desc);
alter table public.rd_business_pages enable row level security;
alter table public.rd_portfolio enable row level security;
revoke all on public.rd_business_pages,public.rd_portfolio from public,anon,authenticated;
grant select,insert,update on public.rd_business_pages to authenticated;
grant select on public.rd_portfolio to authenticated;
grant insert(id,contractor_id,title,description,city,before_path,after_path),update(title,description,city,before_path,after_path) on public.rd_portfolio to authenticated;
create policy business_read on public.rd_business_pages for select to authenticated using(rd_private.can_read_profile(id));
create policy business_insert on public.rd_business_pages for insert to authenticated with check(id=(select auth.uid()) and exists(select 1 from public.rd_profiles p where p.id=rd_business_pages.id and p.role='contractor'));
create policy business_update on public.rd_business_pages for update to authenticated using(id=(select auth.uid())) with check(id=(select auth.uid()) and exists(select 1 from public.rd_profiles p where p.id=rd_business_pages.id and p.role='contractor'));
create policy portfolio_read on public.rd_portfolio for select to authenticated using(rd_private.can_read_profile(contractor_id));
create policy portfolio_insert on public.rd_portfolio for insert to authenticated with check(contractor_id=(select auth.uid()) and exists(select 1 from public.rd_profiles p where p.id=contractor_id and p.role='contractor'));
create policy portfolio_update on public.rd_portfolio for update to authenticated using(contractor_id=(select auth.uid())) with check(contractor_id=(select auth.uid()));
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('rd-business-media','rd-business-media',false,10485760,array['image/jpeg']);
create policy business_media_read on storage.objects for select to authenticated using(bucket_id='rd-business-media' and exists(select 1 from public.rd_profiles p where p.id::text=(storage.foldername(name))[1] and rd_private.can_read_profile(p.id)));
create policy business_media_insert on storage.objects for insert to authenticated with check(bucket_id='rd-business-media' and (storage.foldername(name))[1]=(select auth.uid())::text and exists(select 1 from public.rd_profiles p where p.id=(select auth.uid()) and p.role='contractor'));
commit;
