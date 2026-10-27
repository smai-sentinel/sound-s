-- Run once in a NEW Supabase project's SQL Editor. Never place a service role key in the website.
begin;
create table public.admins (user_id uuid primary key references auth.users(id) on delete cascade);
alter table public.admins enable row level security;
create function public.is_admin() returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.admins where user_id = (select auth.uid()));
$$;
revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to anon, authenticated;

create table public.tracks (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id) on delete cascade,
 title text not null check(char_length(trim(title)) between 1 and 120),
 artist text not null check(char_length(trim(artist)) between 1 and 120),
 storage_path text unique not null, license text not null check(char_length(trim(license)) between 1 and 2000),
 duration real not null default 0 check(duration >= 0),
 status text not null default 'pending' check(status in ('pending','approved','rejected')),
 review_note text check(char_length(review_note) <= 1000), created_at timestamptz not null default now()
);
alter table public.tracks enable row level security;
create policy tracks_read on public.tracks for select using (status='approved' or owner_id=(select auth.uid()) or public.is_admin());
create policy tracks_submit on public.tracks for insert to authenticated with check (
 owner_id=(select auth.uid()) and status='pending' and review_note is null
 and split_part(storage_path,'/',1)=(select auth.uid())::text
 and exists(select 1 from storage.objects where bucket_id='music' and name=storage_path and owner_id=(select auth.uid())::text)
);
create policy tracks_moderate on public.tracks for update to authenticated using (public.is_admin()) with check (public.is_admin());
create index tracks_status_idx on public.tracks(status);
create index tracks_owner_idx on public.tracks(owner_id);

create table public.playlists (
 id uuid primary key default gen_random_uuid(),owner_id uuid not null references auth.users(id) on delete cascade,
 name text not null check(char_length(trim(name)) between 1 and 80),
 visibility text not null default 'private' check(visibility in ('private','public')),
 track_ids text[] not null default '{}' check(cardinality(track_ids)<=1000),created_at timestamptz not null default now()
);
alter table public.playlists enable row level security;
create policy playlist_read on public.playlists for select using (visibility='public' or owner_id=(select auth.uid()));
create policy playlist_insert on public.playlists for insert to authenticated with check(owner_id=(select auth.uid()));
create policy playlist_update on public.playlists for update to authenticated using(owner_id=(select auth.uid())) with check(owner_id=(select auth.uid()));
create policy playlist_delete on public.playlists for delete to authenticated using(owner_id=(select auth.uid()));
create index playlists_owner_idx on public.playlists(owner_id);

create table public.likes(owner_id uuid references auth.users(id) on delete cascade,track_id text not null check(char_length(track_id)<=80),primary key(owner_id,track_id));
alter table public.likes enable row level security;
create policy likes_owner on public.likes for all to authenticated using(owner_id=(select auth.uid())) with check(owner_id=(select auth.uid()));

create table public.reports (
 id uuid primary key default gen_random_uuid(),track_id text not null check(char_length(track_id) between 1 and 80),
 reporter_id uuid references auth.users(id) on delete set null,
 reason text not null check(reason in ('הפרת זכויות יוצרים','תוכן פוגעני','מידע שגוי או התחזות','בעיה בשמע','אחר')),
 details text not null check(char_length(trim(details)) between 1 and 2000),
 contact_email text check(char_length(contact_email)<=254),
 status text not null default 'open' check(status in ('open','resolved')),created_at timestamptz not null default now()
);
alter table public.reports enable row level security;
create policy reports_admin_read on public.reports for select to authenticated using(public.is_admin());
create policy reports_admin_update on public.reports for update to authenticated using(public.is_admin()) with check(public.is_admin());
create index reports_time_idx on public.reports(created_at);
-- Anonymous visitors may submit, but cannot read reports or modify moderation status.
-- A bounded global intake prevents unbounded storage. Add a CAPTCHA edge function before broad promotion.
create function public.submit_report(p_track_id text,p_reason text,p_details text,p_contact_email text default null)
returns void language plpgsql security definer set search_path = '' as $$
begin
 perform pg_catalog.pg_advisory_xact_lock(9164201);
 if (select count(*) from public.reports where created_at>now()-interval '1 hour')>=100 then
  raise exception 'Report intake limit reached, please retry later';
 end if;
 if not (p_track_id ~ '^(original-[0-5]|spotify:track:[a-zA-Z0-9]{22})$') and not exists(select 1 from public.tracks where id::text=p_track_id and status='approved') then
  raise exception 'Track is not available';
 end if;
 insert into public.reports(track_id,reporter_id,reason,details,contact_email) values(p_track_id,auth.uid(),p_reason,p_details,p_contact_email);
end; $$;
revoke all on function public.submit_report(text,text,text,text) from public;
grant execute on function public.submit_report(text,text,text,text) to anon,authenticated;
revoke all on public.admins,public.tracks,public.playlists,public.likes,public.reports from anon,authenticated;
grant select on public.tracks,public.playlists to anon,authenticated;
grant insert on public.tracks to authenticated;
grant update(status,review_note,duration) on public.tracks to authenticated;
grant insert,update,delete on public.playlists to authenticated;
grant select,insert,delete on public.likes to authenticated;
grant select on public.reports to authenticated;
grant update(status) on public.reports to authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('music','music',false,52428800,array['audio/mpeg','audio/mp3','audio/wav','audio/x-wav','audio/wave','audio/vnd.wave','audio/flac','audio/x-flac','audio/ogg','audio/mp4','audio/x-m4a']);
create policy music_upload on storage.objects for insert to authenticated with check(
 bucket_id='music' and (storage.foldername(name))[1]=(select auth.uid())::text
 and lower(storage.extension(name)) in ('mp3','wav','flac','ogg','m4a')
);
create policy music_read on storage.objects for select to anon,authenticated using(
 bucket_id='music' and (owner_id=(select auth.uid())::text or public.is_admin() or exists(select 1 from public.tracks where storage_path=name and status='approved'))
);
-- A user may clean up an orphaned upload, but not replace or remove reviewed audio.
create policy music_orphan_delete on storage.objects for delete to authenticated using(
 bucket_id='music' and owner_id=(select auth.uid())::text and not exists(select 1 from public.tracks where storage_path=name)
);
commit;
-- After signing up, promote YOUR account manually from SQL Editor:
-- insert into public.admins(user_id) select id from auth.users where email='YOUR_ADMIN_EMAIL';
