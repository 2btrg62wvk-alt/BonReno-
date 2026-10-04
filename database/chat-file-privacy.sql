begin;
-- A file is visible to its uploader or participants of its actual message.
alter policy "chat files authenticated read" on storage.objects to authenticated
using (bucket_id='rd-chat-files' and (
 (storage.foldername(name))[1]=(select auth.uid())::text
 or exists(select 1 from public.rd_messages m where m.attachment_path=name)
));
alter policy "chat files own insert" on storage.objects to authenticated
with check (bucket_id='rd-chat-files'
 and (storage.foldername(name))[1]=(select auth.uid())::text
 and exists(select 1 from public.rd_quotes q where q.id::text=(storage.foldername(name))[2])
);
-- Prevent a participant from attaching someone else's file or another thread's file.
alter policy message_create on public.rd_messages to authenticated
with check (sender_id=(select auth.uid()) and rd_private.in_thread(quote_id)
 and (attachment_path is null or (
  split_part(attachment_path,'/',1)=sender_id::text
  and split_part(attachment_path,'/',2)=quote_id::text
  and exists(select 1 from storage.objects o where o.bucket_id='rd-chat-files' and o.name=attachment_path)
 ))
);
-- Profile photos follow the same profile visibility rules as names/cities.
alter policy client_avatar_read on storage.objects to authenticated
using (bucket_id='rd-client-avatars' and exists(
 select 1 from public.rd_profiles p where p.id::text=(storage.foldername(name))[1]
));
commit;
