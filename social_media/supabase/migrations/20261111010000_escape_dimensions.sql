create extension if not exists pgcrypto with schema extensions;

create table if not exists public.escape_dimensions (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 40),
  vibe text not null check (vibe in ('lofi', 'cyber', 'deep')),
  invite_code_hash text not null unique,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '30 days'
);

create table if not exists public.escape_dimension_members (
  id uuid primary key default gen_random_uuid(),
  dimension_id uuid not null references public.escape_dimensions(id) on delete cascade,
  membership_token_hash text not null unique,
  codename text not null check (char_length(codename) between 1 and 24),
  created_at timestamptz not null default now(),
  unique (dimension_id, membership_token_hash)
);

create table if not exists public.escape_dimension_posts (
  id uuid primary key default gen_random_uuid(),
  dimension_id uuid not null references public.escape_dimensions(id) on delete cascade,
  member_id uuid not null references public.escape_dimension_members(id) on delete cascade,
  content text not null check (char_length(content) between 1 and 1000),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '24 hours',
  hidden_at timestamptz
);

create table if not exists public.escape_dimension_reports (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.escape_dimension_posts(id) on delete cascade,
  reporter_member_id uuid not null references public.escape_dimension_members(id) on delete cascade,
  reason text not null default 'Community report'
    check (char_length(reason) between 1 and 300),
  created_at timestamptz not null default now(),
  unique (post_id, reporter_member_id)
);

create index if not exists escape_dimension_posts_room_expiry_idx
  on public.escape_dimension_posts (dimension_id, expires_at desc);
create index if not exists escape_dimension_members_room_idx
  on public.escape_dimension_members (dimension_id);
create index if not exists escape_dimension_reports_post_idx
  on public.escape_dimension_reports (post_id);

alter table public.escape_dimensions enable row level security;
alter table public.escape_dimension_members enable row level security;
alter table public.escape_dimension_posts enable row level security;
alter table public.escape_dimension_reports enable row level security;

revoke all on public.escape_dimensions from anon, authenticated;
revoke all on public.escape_dimension_members from anon, authenticated;
revoke all on public.escape_dimension_posts from anon, authenticated;
revoke all on public.escape_dimension_reports from anon, authenticated;

create or replace function public.create_escape_dimension(
  p_name text,
  p_vibe text,
  p_codename text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_dimension_id uuid;
  v_invite_code text;
  v_membership_token text := encode(extensions.gen_random_bytes(32), 'hex');
  v_codename text := btrim(p_codename);
begin
  if char_length(btrim(p_name)) not between 1 and 40
     or char_length(v_codename) not between 1 and 24
     or p_vibe not in ('lofi', 'cyber', 'deep') then
    raise exception 'Invalid Dimension details.';
  end if;

  loop
    v_invite_code := upper(encode(extensions.gen_random_bytes(6), 'hex'));
    exit when not exists (
      select 1 from public.escape_dimensions
      where invite_code_hash = encode(extensions.digest(v_invite_code, 'sha256'), 'hex')
    );
  end loop;

  insert into public.escape_dimensions (name, vibe, invite_code_hash)
  values (
    btrim(p_name),
    p_vibe,
    encode(extensions.digest(v_invite_code, 'sha256'), 'hex')
  )
  returning id into v_dimension_id;

  insert into public.escape_dimension_members (
    dimension_id,
    membership_token_hash,
    codename
  )
  values (
    v_dimension_id,
    encode(extensions.digest(v_membership_token, 'sha256'), 'hex'),
    v_codename
  );

  return jsonb_build_object(
    'room_id', v_dimension_id,
    'name', btrim(p_name),
    'vibe', p_vibe,
    'codename', v_codename,
    'invite_code', v_invite_code,
    'membership_token', v_membership_token
  );
end;
$$;

create or replace function public.join_escape_dimension(
  p_invite_code text,
  p_codename text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_dimension public.escape_dimensions%rowtype;
  v_membership_token text := encode(extensions.gen_random_bytes(32), 'hex');
  v_codename text := btrim(p_codename);
begin
  if char_length(v_codename) not between 1 and 24
     or char_length(btrim(p_invite_code)) not between 8 and 32 then
    raise exception 'Invalid invite code or codename.';
  end if;

  select * into v_dimension
  from public.escape_dimensions
  where invite_code_hash = encode(
    extensions.digest(upper(btrim(p_invite_code)), 'sha256'),
    'hex'
  )
    and expires_at > now()
  limit 1;

  if not found then
    raise exception 'That Dimension code is invalid or expired.';
  end if;

  insert into public.escape_dimension_members (
    dimension_id,
    membership_token_hash,
    codename
  )
  values (
    v_dimension.id,
    encode(extensions.digest(v_membership_token, 'sha256'), 'hex'),
    v_codename
  );

  return jsonb_build_object(
    'room_id', v_dimension.id,
    'name', v_dimension.name,
    'vibe', v_dimension.vibe,
    'codename', v_codename,
    'membership_token', v_membership_token
  );
end;
$$;

create or replace function public.list_escape_posts(
  p_room_id uuid,
  p_membership_token text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_member_id uuid;
  v_posts jsonb;
begin
  select id into v_member_id
  from public.escape_dimension_members
  where dimension_id = p_room_id
    and membership_token_hash = encode(
      extensions.digest(p_membership_token, 'sha256'),
      'hex'
    );
  if not found then raise exception 'You are not a member of this Dimension.'; end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', post.id,
        'codename', member.codename,
        'message', post.content,
        'createdAt', post.created_at
      )
      order by post.created_at
    ),
    '[]'::jsonb
  )
  into v_posts
  from public.escape_dimension_posts post
  join public.escape_dimension_members member on member.id = post.member_id
  where post.dimension_id = p_room_id
    and post.expires_at > now()
    and post.hidden_at is null;

  return v_posts;
end;
$$;

create or replace function public.send_escape_post(
  p_room_id uuid,
  p_membership_token text,
  p_content text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_member public.escape_dimension_members%rowtype;
  v_post public.escape_dimension_posts%rowtype;
begin
  if char_length(btrim(p_content)) not between 1 and 1000 then
    raise exception 'Messages must contain between 1 and 1000 characters.';
  end if;

  select * into v_member
  from public.escape_dimension_members
  where dimension_id = p_room_id
    and membership_token_hash = encode(
      extensions.digest(p_membership_token, 'sha256'),
      'hex'
    );
  if not found then raise exception 'You are not a member of this Dimension.'; end if;

  insert into public.escape_dimension_posts (dimension_id, member_id, content)
  values (p_room_id, v_member.id, btrim(p_content))
  returning * into v_post;

  return jsonb_build_object(
    'id', v_post.id,
    'codename', v_member.codename,
    'message', v_post.content,
    'createdAt', v_post.created_at
  );
end;
$$;

create or replace function public.report_escape_post(
  p_room_id uuid,
  p_membership_token text,
  p_post_id uuid,
  p_reason text default 'Community report'
)
returns void
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_member_id uuid;
begin
  select id into v_member_id
  from public.escape_dimension_members
  where dimension_id = p_room_id
    and membership_token_hash = encode(
      extensions.digest(p_membership_token, 'sha256'),
      'hex'
    );
  if not found then raise exception 'You are not a member of this Dimension.'; end if;

  insert into public.escape_dimension_reports (post_id, reporter_member_id, reason)
  select post.id, v_member_id, left(btrim(p_reason), 300)
  from public.escape_dimension_posts post
  where post.id = p_post_id
    and post.dimension_id = p_room_id
    and post.expires_at > now()
  on conflict (post_id, reporter_member_id) do nothing;

  update public.escape_dimension_posts
  set hidden_at = now()
  where id = p_post_id
    and (
      select count(distinct reporter_member_id)
      from public.escape_dimension_reports
      where post_id = p_post_id
    ) >= 3;
end;
$$;

revoke all on function public.create_escape_dimension(text, text, text) from public;
revoke all on function public.join_escape_dimension(text, text) from public;
revoke all on function public.list_escape_posts(uuid, text) from public;
revoke all on function public.send_escape_post(uuid, text, text) from public;
revoke all on function public.report_escape_post(uuid, text, uuid, text) from public;
grant execute on function public.create_escape_dimension(text, text, text) to anon, authenticated;
grant execute on function public.join_escape_dimension(text, text) to anon, authenticated;
grant execute on function public.list_escape_posts(uuid, text) to anon, authenticated;
grant execute on function public.send_escape_post(uuid, text, text) to anon, authenticated;
grant execute on function public.report_escape_post(uuid, text, uuid, text) to anon, authenticated;
