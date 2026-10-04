begin;
-- Archiving closes pending bids in the same locked transaction.
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
 if next_status='archived' then
  update public.rd_quotes set status='declined' where project_id=p.id and status='pending';
 end if;
 update public.rd_projects set status=next_status where id=project;
end $$;
commit;
