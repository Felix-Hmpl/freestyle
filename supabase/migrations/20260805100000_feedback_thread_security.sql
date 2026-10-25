-- Admin attachments are shared only with the receiving thread's owner.
drop policy "feedback_attachments_select" on storage.objects;
-- Admin replies support attachments too. Only the owner of the receiving
-- thread gains access, and only when the message author owns the upload path.
-- A user cannot gain access by referencing another author's private object.
create policy "feedback_attachments_select" on storage.objects for select to authenticated
  using (
    bucket_id = 'feedback-attachments'
    and (
      (storage.foldername(name))[1] = (select int_id::text from profiles where id = auth.uid())
      or exists (select 1 from profiles where id = auth.uid() and (flags & 1) = 1)
      or exists (
        select 1 from feedback_messages m
        join feedback f on f.id = m.feedback_id
        where f.submitted_by = (select int_id from profiles where id = auth.uid())
          and storage.objects.name = any(m.attachment_paths)
          and (storage.foldername(storage.objects.name))[1] = m.author_id::text
      )
    )
  );

-- Closed threads are read-only for both owners and admins.
drop policy "feedback_messages_insert" on public.feedback_messages;
create policy "feedback_messages_insert" on feedback_messages for insert
  with check (
    author_id = (select int_id from profiles where id = auth.uid())
    and exists (
      select 1 from feedback f
      where f.id = feedback_id
        and f.status in ('new', 'answered')
        and (
          f.submitted_by = author_id
          or exists (select 1 from profiles where id = auth.uid() and (flags & 1) = 1)
        )
    )
  );

-- Serialize inserts with thread closure, including requests from stale clients.
-- Generate timestamps after acquiring the lock; clients cannot forge unread state.
create or replace function prepare_feedback_message()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  thread_status text;
begin
  select status into thread_status from feedback
  where id = new.feedback_id for update;
  if thread_status in ('reviewed', 'dismissed') then
    raise exception 'feedback thread is closed' using errcode = '42501';
  end if;
  new.created_at := clock_timestamp();
  return new;
end;
$$;

create trigger feedback_messages_prepare
  before insert on feedback_messages
  for each row execute function prepare_feedback_message();

revoke execute on function public.prepare_feedback_message() from public;
