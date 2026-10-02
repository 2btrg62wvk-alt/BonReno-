begin;
create schema if not exists rd_private;
revoke all on schema rd_private from public, anon;
grant usage on schema rd_private to authenticated;
create table public.rd_profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 role text not null check(role in ('client','contractor')),
 display_name text not null check(length(display_name) between 1 and 120),
 company_name text not null default '', city text not null,
 latitude double precision not null check(latitude between -90 and 90),
 longitude double precision not null check(longitude between -180 and 180),
 services text[] not null default '{}', radius_km integer not null default 50 check(radius_km between 1 and 300),
 rbq text not null default '', created_at timestamptz not null default now(),
 check(services <@ array['general','plumbing','electrical','roofing','kitchen','bathroom','painting','flooring','hvac','excavation','exterior','landscaping','other']::text[]),
 check(role <> 'contractor' or cardinality(services)>0)
);
create table public.rd_projects (
 id uuid primary key default gen_random_uuid(), client_id uuid not null references public.rd_profiles(id),
 title text not null check(length(title) between 1 and 160), service text not null,
 description text not null check(length(description) between 10 and 10000), budget text not null, timing text not null,
 city text not null, postal text not null default '',
 latitude double precision not null check(latitude between -90 and 90), longitude double precision not null check(longitude between -180 and 180),
 status text not null default 'open' check(status in ('open','accepted','in_progress','completed','archived')),
 accepted_quote_id uuid, created_at timestamptz not null default now(),
 check(service=any(array['general','plumbing','electrical','roofing','kitchen','bathroom','painting','flooring','hvac','excavation','exterior','landscaping','other']))
);
create table public.rd_quotes (
 id uuid primary key default gen_random_uuid(), project_id uuid not null references public.rd_projects(id),
 contractor_id uuid not null references public.rd_profiles(id),
 amount numeric(12,2) not null check(amount>0), duration text not null check(length(duration) between 1 and 120),
 start_date date not null, message text not null check(length(message) between 10 and 10000),
 status text not null default 'pending' check(status in ('pending','accepted','declined')),
 created_at timestamptz not null default now(), unique(project_id,contractor_id)
);
alter table public.rd_projects add constraint rd_accepted_quote_fk foreign key(accepted_quote_id) references public.rd_quotes(id);
create table public.rd_messages (
 id uuid primary key default gen_random_uuid(), quote_id uuid not null references public.rd_quotes(id),
 sender_id uuid not null references public.rd_profiles(id), body text not null check(length(body) between 1 and 4000),
 created_at timestamptz not null default now()
);
create index rd_projects_client_idx on public.rd_projects(client_id,created_at desc);
create index rd_projects_feed_idx on public.rd_projects(status,service,created_at desc);
create index rd_quotes_contractor_idx on public.rd_quotes(contractor_id,created_at desc);
create index rd_messages_thread_idx on public.rd_messages(quote_id,created_at);
alter table public.rd_profiles enable row level security;
alter table public.rd_projects enable row level security;
alter table public.rd_quotes enable row level security;
alter table public.rd_messages enable row level security;
revoke all on public.rd_profiles,public.rd_projects,public.rd_quotes,public.rd_messages from anon,authenticated;
grant select,insert on public.rd_profiles,public.rd_projects,public.rd_quotes,public.rd_messages to authenticated;
grant update(display_name,company_name,city,latitude,longitude,services,radius_km,rbq) on public.rd_profiles to authenticated;
create policy profile_read on public.rd_profiles for select to authenticated using(true);
create policy profile_create on public.rd_profiles for insert to authenticated with check(id=(select auth.uid()));
create policy profile_edit on public.rd_profiles for update to authenticated using(id=(select auth.uid())) with check(id=(select auth.uid()));
create function rd_private.distance_km(a double precision,b double precision,c double precision,d double precision)
returns double precision language sql immutable set search_path='' as $$
 select 6371*2*asin(sqrt(least(1.0,power(sin(radians(c-a)/2),2)+cos(radians(a))*cos(radians(c))*power(sin(radians(d-b)/2),2))))
$$;
create function rd_private.matches_project(service text,lat double precision,lon double precision)
returns boolean language sql stable security invoker set search_path='' as $$
 select exists(select 1 from public.rd_profiles p where p.id=auth.uid() and p.role='contractor'
 and ('general'=any(p.services) or service=any(p.services))
 and rd_private.distance_km(p.latitude,p.longitude,lat,lon)<=p.radius_km)
$$;
-- Private lookups avoid recursive RLS between projects and quotes. Always bound to auth.uid().
create function rd_private.is_awarded(project uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from public.rd_quotes q where q.project_id=project and q.contractor_id=auth.uid() and q.status='accepted')
$$;
create function rd_private.owns_project(project uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from public.rd_projects p where p.id=project and p.client_id=auth.uid())
$$;
create function rd_private.in_thread(quote uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from public.rd_quotes q join public.rd_projects p on p.id=q.project_id where q.id=quote and (q.contractor_id=auth.uid() or p.client_id=auth.uid()))
$$;
create policy project_read on public.rd_projects for select to authenticated using(
 client_id=(select auth.uid()) or rd_private.is_awarded(id) or (status='open' and rd_private.matches_project(service,latitude,longitude)));
create policy project_create on public.rd_projects for insert to authenticated with check(
 client_id=(select auth.uid()) and status='open' and accepted_quote_id is null and exists(select 1 from public.rd_profiles where id=auth.uid() and role='client'));
create policy quote_read on public.rd_quotes for select to authenticated using(contractor_id=(select auth.uid()) or rd_private.owns_project(project_id));
create policy quote_create on public.rd_quotes for insert to authenticated with check(
 contractor_id=(select auth.uid()) and status='pending' and exists(select 1 from public.rd_projects p where p.id=project_id and p.status='open' and rd_private.matches_project(p.service,p.latitude,p.longitude)));
create policy message_read on public.rd_messages for select to authenticated using(rd_private.in_thread(quote_id));
create policy message_create on public.rd_messages for insert to authenticated with check(sender_id=(select auth.uid()) and rd_private.in_thread(quote_id));
create function rd_private.accept_quote(quote uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare q public.rd_quotes; p public.rd_projects;
begin
 if auth.uid() is null then raise exception 'Connexion requise'; end if;
 select * into q from public.rd_quotes where id=quote;
 if q.id is null then raise exception 'Soumission introuvable'; end if;
 select * into p from public.rd_projects where id=q.project_id for update;
 if p.client_id<>auth.uid() then raise exception 'Accès refusé'; end if;
 if p.status<>'open' or q.status<>'pending' then raise exception 'Ce projet a déjà un entrepreneur'; end if;
 update public.rd_quotes set status=case when id=quote then 'accepted' else 'declined' end where project_id=p.id;
 update public.rd_projects set status='accepted',accepted_quote_id=quote where id=p.id;
 return p.id;
end $$;
create function public.rd_accept_quote(quote uuid) returns uuid language sql security invoker set search_path='' as $$select rd_private.accept_quote(quote)$$;
create function rd_private.progress_project(project uuid,next_status text) returns void language plpgsql security definer set search_path='' as $$
declare p public.rd_projects;
begin
 if auth.uid() is null then raise exception 'Connexion requise'; end if;
 select * into p from public.rd_projects where id=project for update;
 if not (p.client_id=auth.uid() or exists(select 1 from public.rd_quotes where id=p.accepted_quote_id and contractor_id=auth.uid())) then raise exception 'Accès refusé'; end if;
 if not ((next_status='in_progress' and p.status='accepted') or (next_status='completed' and p.status='in_progress' and p.client_id=auth.uid()) or (next_status='archived' and p.status='open' and p.client_id=auth.uid())) then raise exception 'Changement de statut refusé'; end if;
 update public.rd_projects set status=next_status where id=project;
end $$;
create function public.rd_progress_project(project uuid,next_status text) returns void language sql security invoker set search_path='' as $$select rd_private.progress_project(project,next_status)$$;
revoke all on all functions in schema rd_private from public,anon;
grant execute on all functions in schema rd_private to authenticated;
revoke all on function public.rd_accept_quote(uuid),public.rd_progress_project(uuid,text) from public,anon;
grant execute on function public.rd_accept_quote(uuid),public.rd_progress_project(uuid,text) to authenticated;
commit;
