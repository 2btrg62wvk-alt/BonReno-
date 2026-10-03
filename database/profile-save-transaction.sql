begin;
-- Invoker rights retain the existing RLS/column permissions. Both writes commit
-- together, including when a portfolio validation or ownership check fails.
create or replace function public.rd_save_business_changes(presentation jsonb, realization jsonb default null)
returns void language plpgsql security invoker set search_path='' as $$
declare owner uuid:=auth.uid(); changed uuid;
begin
 if owner is null or not exists(select 1 from public.rd_profiles where id=owner and role='contractor') then
  raise exception 'Compte entrepreneur requis' using errcode='42501';
 end if;
 insert into public.rd_business_pages(id,tagline,bio,experience_years,insurance_declared,cover_path,logo_path)
 values(owner,coalesce(presentation->>'tagline',''),coalesce(presentation->>'bio',''),
  (presentation->>'experience_years')::integer,coalesce((presentation->>'insurance_declared')::boolean,false),
  presentation->>'cover_path',presentation->>'logo_path')
 on conflict(id) do update set tagline=excluded.tagline,bio=excluded.bio,
  experience_years=excluded.experience_years,insurance_declared=excluded.insurance_declared,
  cover_path=coalesce(excluded.cover_path,rd_business_pages.cover_path),
  logo_path=coalesce(excluded.logo_path,rd_business_pages.logo_path);
 if realization is not null then
  insert into public.rd_portfolio(id,contractor_id,title,city,description,before_path,after_path)
  values((realization->>'id')::uuid,owner,realization->>'title',coalesce(realization->>'city',''),
   coalesce(realization->>'description',''),realization->>'before_path',realization->>'after_path')
  on conflict(id) do update set title=excluded.title,city=excluded.city,description=excluded.description,
   before_path=excluded.before_path,after_path=excluded.after_path
  where rd_portfolio.contractor_id=owner returning id into changed;
  if changed is null then raise exception 'Réalisation inaccessible'; end if;
 end if;
end $$;
revoke all on function public.rd_save_business_changes(jsonb,jsonb) from public,anon;
grant execute on function public.rd_save_business_changes(jsonb,jsonb) to authenticated;
commit;
