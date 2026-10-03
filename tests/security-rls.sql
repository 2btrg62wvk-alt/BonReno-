-- Run as the database administrator. Every fixture/write is rolled back.
begin;
create temporary table security_ids(name text primary key,id uuid default gen_random_uuid());
insert into security_ids(name) values('client'),('other_client'),('plumber'),('electrician'),('general'),('far_plumber'),('plumbing'),('electric'),('other'),('quote'),('second_quote');
grant select on security_ids to authenticated,anon;
create function pg_temp.sid(key text) returns uuid language sql as $$select id from pg_temp.security_ids where name=key$$;
create function pg_temp.check_test(ok boolean,label text) returns void language plpgsql as $$
begin if ok is distinct from true then raise exception 'FAIL: %',label; end if; end $$;
create function pg_temp.denied(command text,expected_state text default null) returns void language plpgsql security invoker as $$
declare denied boolean:=false;
begin
 begin execute command;
 exception when others then
  if expected_state is not null and sqlstate<>expected_state then raise; end if;
  denied:=true;
 end;
 if not denied then raise exception 'FAIL: unauthorized operation succeeded: %',command; end if;
end $$;
insert into auth.users(id,email) select id,'security-'||id||'@example.invalid' from security_ids where name in ('client','other_client','plumber','electrician','general','far_plumber');
insert into public.rd_profiles(id,role,display_name,city,latitude,longitude,services,radius_km)
select id,case when name in ('client','other_client') then 'client' else 'contractor' end,name,
case when name='far_plumber' then 'Québec' else 'Laval' end,45,-73,
case name when 'plumber' then array['plumbing'] when 'far_plumber' then array['plumbing'] when 'electrician' then array['electrical'] when 'general' then array['general'] else '{}'::text[] end,50
from security_ids where name in ('client','other_client','plumber','electrician','general','far_plumber');
insert into public.rd_projects(id,client_id,title,service,description,budget,timing,city,latitude,longitude)
select id,pg_temp.sid('client'),name,case name when 'plumbing' then 'plumbing' when 'electric' then 'electrical' else 'other' end,'Fixture security project','1000 $','Flexible','Laval',45,-73
from security_ids where name in ('plumbing','electric','other');
insert into public.rd_account_details(id,phone) values(pg_temp.sid('client'),'private-client-phone'),(pg_temp.sid('plumber'),'private-pro-phone');
insert into public.rd_project_photos(project_id,path) values(pg_temp.sid('plumbing'),pg_temp.sid('plumbing')||'/fixture.jpg');

set local role authenticated;
select set_config('request.jwt.claim.sub',pg_temp.sid('plumber')::text,true);
select pg_temp.check_test((select count(*) from public.rd_profiles where id in (select id from pg_temp.security_ids))=1,'No enumeration of unrelated profiles');
select pg_temp.check_test((select count(*) from public.rd_projects where id in (select id from pg_temp.security_ids))=1,'Plumber sees plumbing only');
select pg_temp.denied(format('insert into public.rd_quotes(project_id,contractor_id,amount,duration,start_date,message) values(%L,%L,100,''1 jour'',current_date,''Wrong trade quotation'')',pg_temp.sid('electric'),auth.uid()));
select pg_temp.denied(format('update public.rd_profiles set role=''client'' where id=%L',auth.uid()),'42501');
select pg_temp.denied(format('insert into public.rd_messages(quote_id,sender_id,body,created_at) values(%L,%L,''Forged timestamp'',now())',pg_temp.sid('quote'),auth.uid()),'42501');
insert into public.rd_quotes(id,project_id,contractor_id,amount,duration,start_date,message) values(pg_temp.sid('quote'),pg_temp.sid('plumbing'),auth.uid(),100,'1 jour',current_date,'Valid quotation from plumber');
select pg_temp.check_test((select count(*) from public.rd_profiles where id in (select id from pg_temp.security_ids))=2,'Quote counterparts visible');
select pg_temp.check_test((select count(*) from public.rd_account_details where id in (select id from pg_temp.security_ids))=1,'Even counterpart contact details remain private');
select pg_temp.denied(format('insert into public.rd_messages(quote_id,sender_id,body) values(%L,%L,''Impersonated client'')',pg_temp.sid('quote'),pg_temp.sid('client')),'42501');
insert into public.rd_messages(quote_id,sender_id,body) values(pg_temp.sid('quote'),auth.uid(),'Private conversation fixture');
select pg_temp.denied(format('insert into public.rd_project_photos(project_id,path) values(%L,%L)',pg_temp.sid('plumbing'),pg_temp.sid('plumbing')||'/unauthorized.jpg'),'42501');
select set_config('request.jwt.claim.sub',pg_temp.sid('electrician')::text,true);
select pg_temp.check_test((select count(*) from public.rd_projects where id in (select id from pg_temp.security_ids))=1,'Electrician sees electric only');
select pg_temp.check_test((select count(*) from public.rd_messages where quote_id=pg_temp.sid('quote'))=0,'Unrelated messages hidden');
select pg_temp.check_test((select count(*) from public.rd_project_photos where project_id=pg_temp.sid('plumbing'))=0,'Wrong trade photos hidden');
select pg_temp.denied(format('insert into public.rd_messages(quote_id,sender_id,body) values(%L,%L,''Unrelated conversation'')',pg_temp.sid('quote'),auth.uid()),'42501');
select set_config('request.jwt.claim.sub',pg_temp.sid('far_plumber')::text,true);
select pg_temp.check_test((select count(*) from public.rd_projects where id in (select id from pg_temp.security_ids))=0,'Out of territory hidden');
select set_config('request.jwt.claim.sub',pg_temp.sid('general')::text,true);
select pg_temp.check_test((select count(*) from public.rd_projects where id in (select id from pg_temp.security_ids))=3,'General sees all matching territory trades');
select pg_temp.check_test((select count(*) from public.rd_quotes where project_id=pg_temp.sid('plumbing'))=0,'Competitor prices hidden');
insert into public.rd_quotes(id,project_id,contractor_id,amount,duration,start_date,message) values(pg_temp.sid('second_quote'),pg_temp.sid('plumbing'),auth.uid(),120,'2 jours',current_date,'Valid second contractor quotation');
select pg_temp.check_test((select count(*) from public.rd_profiles where id in (select id from pg_temp.security_ids))=2,'Competing contractor profile hidden');
select set_config('request.jwt.claim.sub',pg_temp.sid('other_client')::text,true);
select pg_temp.check_test((select count(*) from public.rd_projects where id in (select id from pg_temp.security_ids))=0,'Other client project isolation');
select pg_temp.denied(format('select public.rd_accept_quote(%L)',pg_temp.sid('quote')),'P0001');
select pg_temp.denied(format('select public.rd_progress_project(%L,''archived'')',pg_temp.sid('plumbing')),'P0001');
select pg_temp.denied(format('insert into public.rd_projects(client_id,title,service,description,budget,timing,city,latitude,longitude) values(%L,''Impersonation'',''plumbing'',''Cannot post for other client'',''100'',''Flexible'',''Laval'',45,-73)',pg_temp.sid('client')),'42501');
select pg_temp.denied(format('insert into public.rd_account_details(id,phone) values(%L,''Forged contact'')',pg_temp.sid('electrician')),'42501');
select set_config('request.jwt.claim.sub',pg_temp.sid('client')::text,true);
select pg_temp.check_test((select count(*) from public.rd_profiles where id in (select id from pg_temp.security_ids))=3,'Client sees direct bidders only');
select public.rd_accept_quote(pg_temp.sid('quote'));
select pg_temp.denied(format('select public.rd_accept_quote(%L)',pg_temp.sid('second_quote')),'P0001');
select pg_temp.denied(format('select public.rd_progress_project(%L,null)',pg_temp.sid('plumbing')),'P0001');
select pg_temp.denied('select public.rd_progress_project(gen_random_uuid(),''in_progress'')','P0001');
select set_config('request.jwt.claim.sub',pg_temp.sid('general')::text,true);
select pg_temp.check_test((select count(*) from public.rd_projects where id=pg_temp.sid('plumbing'))=1,'Nonretained bidder retains own history');
select pg_temp.denied(format('select public.rd_progress_project(%L,''in_progress'')',pg_temp.sid('plumbing')),'P0001');
select set_config('request.jwt.claim.sub',pg_temp.sid('plumber')::text,true);
select public.rd_progress_project(pg_temp.sid('plumbing'),'in_progress');
select pg_temp.denied(format('select public.rd_progress_project(%L,''completed'')',pg_temp.sid('plumbing')),'P0001');
select set_config('request.jwt.claim.sub',pg_temp.sid('client')::text,true);
select public.rd_progress_project(pg_temp.sid('plumbing'),'completed');
select pg_temp.check_test((select status from public.rd_projects where id=pg_temp.sid('plumbing'))='completed','Authorized lifecycle still works');
select pg_temp.check_test(not exists(select 1 from information_schema.role_table_grants where table_schema='public' and grantee in ('anon','authenticated') and privilege_type='TRUNCATE'),'No RLS-bypassing TRUNCATE grants');
reset role;
set local role anon;
select set_config('request.jwt.claim.sub','',true);
select pg_temp.denied('select * from public.rd_profiles','42501');
select pg_temp.denied('select * from public.rd_projects','42501');
select pg_temp.denied('select * from public.rd_account_details','42501');
select pg_temp.denied('select * from public.rd_project_photos','42501');
select pg_temp.denied('select public.rd_accept_quote(gen_random_uuid())','42501');
reset role;
rollback;
select 'PASS: profile privacy, trade/territory isolation, competitors, messages, photos, role immutability, impersonation, timestamps, anonymous access, lifecycle authorization; all fixtures rolled back' as security_tests;
