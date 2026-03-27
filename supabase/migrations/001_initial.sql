-- Supabase SQL editor 또는 psql 로 적용. 익명 JWT sub 또는 Supabase Auth user id 저장용.
-- RLS 는 필요 시 대시보드에서 정책 추가.

create table if not exists public.user_profiles (
    subject text primary key,
    display_name text,
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists idx_user_profiles_updated_at
    on public.user_profiles (updated_at desc);

comment on table public.user_profiles is '백엔드 JWT sub(익명 또는 Supabase auth.users.id) 단위 프로필';
