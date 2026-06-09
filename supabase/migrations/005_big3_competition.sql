-- 3대 운동(스쿼트·벤치·데드) 경쟁 시스템
-- MVP: 자가 신고(self_reported), opt-in, 시즌 리더보드
-- PII: 리더보드에는 display_alias만 노출 (user_id/subject 비공개)

-- ---------------------------------------------------------------------------
-- 시즌
-- ---------------------------------------------------------------------------
create table if not exists public.competition_seasons (
    id uuid primary key default gen_random_uuid(),
    slug text not null unique,
    name text not null,
    starts_at timestamptz not null,
    ends_at timestamptz not null,
    is_active boolean not null default false,
    created_at timestamptz not null default now(),
    constraint competition_seasons_dates check (ends_at > starts_at)
);

comment on table public.competition_seasons is '3대 경쟁 시즌 메타데이터';

-- ---------------------------------------------------------------------------
-- opt-in 프로필 (내부 user_id ↔ 공개 display_alias)
-- ---------------------------------------------------------------------------
create table if not exists public.competition_profiles (
    user_id text primary key,
    display_alias text not null,
    opted_in boolean not null default false,
    opted_in_at timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint competition_profiles_alias_len check (char_length(display_alias) between 2 and 24),
    constraint competition_profiles_alias_format check (
        display_alias ~ '^[가-힣A-Za-z0-9_-]+$'
    )
);

create unique index if not exists idx_competition_profiles_display_alias
    on public.competition_profiles (lower(display_alias));

comment on table public.competition_profiles is '경쟁 참가 opt-in; display_alias만 리더보드에 노출';

-- ---------------------------------------------------------------------------
-- 기록 제출
-- ---------------------------------------------------------------------------
create table if not exists public.big3_lift_submissions (
    id uuid primary key default gen_random_uuid(),
    user_id text not null,
    season_id uuid not null references public.competition_seasons (id) on delete restrict,
    lift_type text not null,
    weight_kg numeric(6, 2) not null,
    reps integer not null,
    estimated_1rm_kg numeric(7, 2) not null,
    verification_status text not null default 'self_reported',
    session_date date not null default (timezone('utc', now()))::date,
    submitted_at timestamptz not null default now(),
    constraint big3_lift_submissions_lift_type check (
        lift_type in ('squat', 'bench', 'deadlift')
    ),
    constraint big3_lift_submissions_weight check (weight_kg > 0 and weight_kg <= 500),
    constraint big3_lift_submissions_reps check (reps >= 1 and reps <= 20),
    constraint big3_lift_submissions_verification check (
        verification_status in ('pending', 'self_reported', 'verified', 'rejected')
    )
);

create index if not exists idx_big3_submissions_user_season_lift
    on public.big3_lift_submissions (user_id, season_id, lift_type, submitted_at desc);

create index if not exists idx_big3_submissions_season_lift_1rm
    on public.big3_lift_submissions (season_id, lift_type, estimated_1rm_kg desc);

comment on table public.big3_lift_submissions is '3대 운동 제출 기록; verification_status는 향후 영상/관리자 검수 확장용';

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.competition_seasons enable row level security;
alter table public.competition_profiles enable row level security;
alter table public.big3_lift_submissions enable row level security;

-- 시즌: 인증 사용자 읽기 전용 (쓰기는 서비스 롤/마이그레이션)
create policy "Authenticated read competition seasons"
    on public.competition_seasons
    for select
    to authenticated
    using (true);

-- 프로필: 본인만 CRUD
create policy "Users manage own competition profile"
    on public.competition_profiles
    for all
    to authenticated
    using (auth.uid()::text = user_id)
    with check (auth.uid()::text = user_id);

-- 제출: 본인만 삽입·조회 (수정/삭제는 MVP에서 서버만)
create policy "Users insert own big3 submissions"
    on public.big3_lift_submissions
    for insert
    to authenticated
    with check (auth.uid()::text = user_id);

create policy "Users read own big3 submissions"
    on public.big3_lift_submissions
    for select
    to authenticated
    using (auth.uid()::text = user_id);

-- ---------------------------------------------------------------------------
-- 시드: 2026 상반기 시즌
-- ---------------------------------------------------------------------------
insert into public.competition_seasons (slug, name, starts_at, ends_at, is_active)
values (
    '2026-h1',
    '2026 상반기 3대 경쟁',
    '2026-01-01T00:00:00Z',
    '2026-06-30T23:59:59Z',
    true
)
on conflict (slug) do nothing;
