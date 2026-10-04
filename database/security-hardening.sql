begin;
-- Supabase default table grants included operations that RLS does not cover
-- (notably TRUNCATE). Keep only the operations used by the application.
revoke all on public.rd_cities,public.rd_account_details,public.rd_project_photos from public,anon,authenticated;
grant select on public.rd_cities to anon,authenticated;
grant select,insert,update on public.rd_account_details to authenticated;
grant select on public.rd_project_photos to authenticated;
-- A connected account may read only itself or its direct quote counterpart.
-- This bounded private lookup avoids recursive profiles/projects/quotes RLS.
create or replace function rd_private.can_read_profile(target uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and (
  target=auth.uid() or exists(
   select 1 from public.rd_quotes q join public.rd_projects p on p.id=q.project_id
   where (p.client_id=auth.uid() and q.contractor_id=target)
      or (q.contractor_id=auth.uid() and p.client_id=target)
  )
 )
$$;
revoke all on function rd_private.can_read_profile(uuid) from public,anon;
grant execute on function rd_private.can_read_profile(uuid) to authenticated;
alter policy profile_read on public.rd_profiles using(rd_private.can_read_profile(id));

-- Server-owned timestamps cannot be forged to spoof sorting/notifications.
-- IDs remain insertable where the mobile upload workflow pre-generates them.
revoke insert on public.rd_profiles,public.rd_projects,public.rd_quotes,public.rd_messages,public.rd_project_photos from authenticated;
grant insert(id,role,display_name,company_name,city,latitude,longitude,services,radius_km,rbq) on public.rd_profiles to authenticated;
grant insert(id,client_id,title,service,description,budget,timing,city,postal,latitude,longitude) on public.rd_projects to authenticated;
grant insert(id,project_id,contractor_id,amount,duration,start_date,message) on public.rd_quotes to authenticated;
grant insert(id,quote_id,sender_id,body) on public.rd_messages to authenticated;
grant insert(id,project_id,path) on public.rd_project_photos to authenticated;

-- Authorize before revealing whether a quote exists. Lock its parent first.
create or replace function rd_private.accept_quote(quote uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare q public.rd_quotes; p public.rd_projects;
begin
 if auth.uid() is null then raise exception 'Connexion requise'; end if;
 select p0.* into p from public.rd_projects p0 join public.rd_quotes q0 on q0.project_id=p0.id
 where q0.id=quote and p0.client_id=auth.uid() for update of p0;
 if not found then raise exception 'Soumission introuvable ou inaccessible'; end if;
 select * into q from public.rd_quotes where id=quote;
 if p.status<>'open' or q.status<>'pending' then raise exception 'Ce projet a déjà un entrepreneur'; end if;
 update public.rd_quotes set status=case when id=quote then 'accepted' else 'declined' end where project_id=p.id;
 update public.rd_projects set status='accepted',accepted_quote_id=quote where id=p.id;
 return p.id;
end $$;
create or replace function rd_private.progress_project(project uuid,next_status text) returns void
language plpgsql security definer set search_path='' as $$
declare p public.rd_projects;
begin
 if auth.uid() is null then raise exception 'Connexion requise'; end if;
 select p0.* into p from public.rd_projects p0
 where p0.id=project and (p0.client_id=auth.uid() or exists(
  select 1 from public.rd_quotes q where q.id=p0.accepted_quote_id and q.contractor_id=auth.uid()
 )) for update;
 if not found then raise exception 'Projet introuvable ou inaccessible'; end if;
 if next_status is null or not (
  (next_status='in_progress' and p.status='accepted') or
  (next_status='completed' and p.status in ('accepted','in_progress') and p.client_id=auth.uid()) or
  (next_status='archived' and p.status='open' and p.client_id=auth.uid())
 ) then raise exception 'Changement de statut refusé'; end if;
 update public.rd_projects set status=next_status where id=project;
end $$;
commit;
