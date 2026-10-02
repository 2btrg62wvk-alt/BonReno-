begin;
create temporary table rd_test_ids(name text primary key,id uuid default gen_random_uuid());
insert into rd_test_ids(name) values('client'),('other_client'),('plumber'),('electrician'),('general'),('far_plumber'),('plumbing_project'),('electric_project'),('other_project'),('quote'),('other_quote');
insert into auth.users(id,email) select id,'rd-rls-'||id||'@example.invalid' from rd_test_ids where name in ('client','other_client','plumber','electrician','general','far_plumber');
insert into public.rd_profiles(id,role,display_name,city,latitude,longitude,services,radius_km)
 select id,case when name in ('client','other_client') then 'client' else 'contractor' end,name,case when name='far_plumber' then 'Québec' else 'Laval' end,45,-73,
 case name when 'plumber' then array['plumbing'] when 'far_plumber' then array['plumbing'] when 'electrician' then array['electrical'] when 'general' then array['general'] else '{}'::text[] end,50
 from rd_test_ids where name in ('client','other_client','plumber','electrician','general','far_plumber');
insert into public.rd_projects(id,client_id,title,service,description,budget,timing,city,latitude,longitude)
 select id,(select id from rd_test_ids where name='client'),name,case name when 'plumbing_project' then 'plumbing' when 'electric_project' then 'electrical' else 'other' end,'Description pour le test','1000 $','Flexible','Laval',45,-73 from rd_test_ids where name in ('plumbing_project','electric_project','other_project');
grant select on rd_test_ids to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub',(select id::text from rd_test_ids where name='plumber'),true);
do $$begin
 if (select count(*) from public.rd_projects)<>1 then raise exception 'Plumber visibility failed';end if;
 if (select count(*) from public.rd_projects where service='electrical')<>0 then raise exception 'Direct wrong trade access';end if;
 begin
  insert into public.rd_quotes(project_id,contractor_id,amount,duration,start_date,message) values((select id from rd_test_ids where name='electric_project'),auth.uid(),100,'1 jour',current_date,'Test offre non admissible');
  raise exception 'Wrong trade insert accepted';
 exception when insufficient_privilege or raise_exception then
  if sqlerrm='Wrong trade insert accepted' then raise;end if;
 end;
end $$;
insert into public.rd_quotes(id,project_id,contractor_id,amount,duration,start_date,message) values((select id from rd_test_ids where name='quote'),(select id from rd_test_ids where name='plumbing_project'),auth.uid(),100,'1 jour',current_date,'Soumission plomberie de test');
select set_config('request.jwt.claim.sub',(select id::text from rd_test_ids where name='electrician'),true);
do $$begin if (select count(*) from public.rd_projects)<>1 or (select count(*) from public.rd_projects where service='plumbing')<>0 then raise exception 'Electrician visibility failed';end if; end $$;
select set_config('request.jwt.claim.sub',(select id::text from rd_test_ids where name='far_plumber'),true);
do $$begin if (select count(*) from public.rd_projects)<>0 then raise exception 'Territory filter failed';end if;end $$;
select set_config('request.jwt.claim.sub',(select id::text from rd_test_ids where name='general'),true);
do $$begin if (select count(*) from public.rd_projects)<>3 then raise exception 'General visibility failed';end if;end $$;
insert into public.rd_quotes(id,project_id,contractor_id,amount,duration,start_date,message) values((select id from rd_test_ids where name='other_quote'),(select id from rd_test_ids where name='plumbing_project'),auth.uid(),120,'2 jours',current_date,'Autre soumission générale test');
select set_config('request.jwt.claim.sub',(select id::text from rd_test_ids where name='other_client'),true);
do $$begin
 if (select count(*) from public.rd_projects)<>0 or (select count(*) from public.rd_quotes)<>0 then raise exception 'Client isolation failed';end if;
 begin perform public.rd_accept_quote((select id from rd_test_ids where name='quote'));raise exception 'Nonowner accepted';exception when raise_exception then if sqlerrm='Nonowner accepted' then raise;end if;end;
end $$;
select set_config('request.jwt.claim.sub',(select id::text from rd_test_ids where name='client'),true);
select public.rd_accept_quote((select id from rd_test_ids where name='quote'));
do $$begin
 if (select count(*) from public.rd_quotes where status='accepted')<>1 then raise exception 'Acceptance failed';end if;
 if (select count(*) from public.rd_quotes where status='declined')<>1 then raise exception 'Other quote not declined';end if;
 begin perform public.rd_accept_quote((select id from rd_test_ids where name='other_quote'));raise exception 'Second acceptance succeeded';exception when raise_exception then if sqlerrm='Second acceptance succeeded' then raise;end if;end;
end $$;
select set_config('request.jwt.claim.sub',(select id::text from rd_test_ids where name='plumber'),true);
select public.rd_progress_project((select id from rd_test_ids where name='plumbing_project'),'in_progress');
insert into public.rd_messages(quote_id,sender_id,body) values((select id from rd_test_ids where name='quote'),auth.uid(),'Message de test');
select set_config('request.jwt.claim.sub',(select id::text from rd_test_ids where name='client'),true);
do $$begin if (select count(*) from public.rd_messages)<>1 then raise exception 'Client cannot read message';end if;end $$;
select public.rd_progress_project((select id from rd_test_ids where name='plumbing_project'),'completed');
select set_config('request.jwt.claim.sub',(select id::text from rd_test_ids where name='electrician'),true);
do $$begin if (select count(*) from public.rd_messages)<>0 then raise exception 'Private message leak';end if;end $$;
reset role;
rollback;
select 'PASS: trade visibility, general, territory, client isolation, unauthorized bids, acceptance, race guard, progress and messages' as result;
