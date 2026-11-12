create table if not exists public.font_listings (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid not null references auth.users(id) on delete cascade,
  creator_name text not null check (char_length(creator_name) between 1 and 32),
  name text not null check (char_length(name) between 1 and 40),
  description text not null default '' check (char_length(description) <= 240),
  object_path text not null unique,
  license_name text not null check (
    license_name in (
      'Free with attribution',
      'Free for personal use',
      'Custom terms - request permission'
    )
  ),
  license_terms text not null default '' check (char_length(license_terms) <= 500),
  created_at timestamptz not null default now()
);

create table if not exists public.font_license_requests (
  id uuid primary key default gen_random_uuid(),
  font_id uuid not null references public.font_listings(id) on delete cascade,
  requester_id uuid not null references auth.users(id) on delete cascade,
  requester_name text not null check (char_length(requester_name) between 1 and 32),
  message text not null check (char_length(message) between 1 and 500),
  status text not null default 'open' check (status in ('open', 'approved', 'declined')),
  response text not null default '' check (char_length(response) <= 500),
  created_at timestamptz not null default now()
);

create index if not exists font_listings_creator_name_idx
  on public.font_listings (creator_name);
create index if not exists font_license_requests_font_id_idx
  on public.font_license_requests (font_id);
create index if not exists font_license_requests_requester_id_idx
  on public.font_license_requests (requester_id);

alter table public.font_listings enable row level security;
alter table public.font_license_requests enable row level security;

grant select on public.font_listings to anon, authenticated;
grant insert, delete on public.font_listings to authenticated;
grant select on public.font_license_requests to authenticated;
revoke insert on public.font_license_requests from authenticated;
grant insert (font_id, requester_id, requester_name, message)
  on public.font_license_requests to authenticated;
grant update (status, response) on public.font_license_requests to authenticated;

drop policy if exists "Anyone can view community fonts" on public.font_listings;
create policy "Anyone can view community fonts"
  on public.font_listings for select
  using (true);

drop policy if exists "Creators can publish their own fonts" on public.font_listings;
create policy "Creators can publish their own fonts"
  on public.font_listings for insert to authenticated
  with check (
    creator_id = (select auth.uid())
    and object_path like (select auth.uid())::text || '/%'
  );

drop policy if exists "Creators can delete their own fonts" on public.font_listings;
create policy "Creators can delete their own fonts"
  on public.font_listings for delete to authenticated
  using (creator_id = (select auth.uid()));

drop policy if exists "Requesters and font creators can view requests" on public.font_license_requests;
create policy "Requesters and font creators can view requests"
  on public.font_license_requests for select to authenticated
  using (
    requester_id = (select auth.uid())
    or exists (
      select 1
      from public.font_listings
      where font_listings.id = font_license_requests.font_id
        and font_listings.creator_id = (select auth.uid())
    )
  );

drop policy if exists "Signed-in users can request licenses" on public.font_license_requests;
create policy "Signed-in users can request licenses"
  on public.font_license_requests for insert to authenticated
  with check (
    requester_id = (select auth.uid())
    and status = 'open'
    and response = ''
    and exists (
      select 1
      from public.font_listings
      where font_listings.id = font_license_requests.font_id
        and font_listings.creator_id <> (select auth.uid())
    )
  );

drop policy if exists "Font creators can respond to license requests" on public.font_license_requests;
create policy "Font creators can respond to license requests"
  on public.font_license_requests for update to authenticated
  using (
    status = 'open'
    and exists (
      select 1
      from public.font_listings
      where font_listings.id = font_license_requests.font_id
        and font_listings.creator_id = (select auth.uid())
    )
  )
  with check (
    status in ('approved', 'declined')
    and exists (
      select 1
      from public.font_listings
      where font_listings.id = font_license_requests.font_id
        and font_listings.creator_id = (select auth.uid())
    )
  );

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'community-fonts',
  'community-fonts',
  true,
  5242880,
  array['font/ttf', 'font/otf']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Anyone can download community fonts" on storage.objects;
create policy "Anyone can download community fonts"
  on storage.objects for select
  using (bucket_id = 'community-fonts');

drop policy if exists "Creators can upload fonts to their own folder" on storage.objects;
create policy "Creators can upload fonts to their own folder"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'community-fonts'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "Creators can remove fonts from their own folder" on storage.objects;
create policy "Creators can remove fonts from their own folder"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'community-fonts'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

