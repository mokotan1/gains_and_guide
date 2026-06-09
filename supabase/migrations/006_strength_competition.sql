-- 3대 운동(Strength) 경쟁 시스템 — 도메인 테이블 (strength_*)
--
-- 선행: 001_initial.sql (public.user_profiles.subject)
-- 참고: 005_big3_competition.sql 의 competition_* / big3_* 명칭을 strength_* 로 정리한 스키마.
--       005 가 이미 적용된 환경이면 rename/데이터 이전 후 본 파일만 유지하거나,
--       greenfield 환경에서는 005 대신 본 마이그레이션만 적용하는 것을 권장.
--
-- subject: JWT sub / Supabase auth.uid()::text / user_profiles.subject 와 동일 값

-- ---------------------------------------------------------------------------
-- updated_at 공통 트리거 (이미 있으면 idempotent)
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- strength_seasons
-- ---------------------------------------------------------------------------
create table if not exists public.strength_seasons (
    id uuid primary key default gen_random_uuid(),
    slug text not null,
    name text not null,
    starts_at timestamptz not null,
    ends_at timestamptz not null,
    is_active boolean not null default false,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint strength_seasons_slug_unique unique (slug),
    constraint strength_seasons_dates check (ends_at > starts_at)
);

comment on table public.strength_seasons is '3대 경쟁 시즌 메타데이터';
comment on column public.strength_seasons.is_active is '관리자 활성 플래그; 현재 시즌 후보는 is_active ∧ now() ∈ [starts_at, ends_at]';

create index if not exists idx_strength_seasons_active_window
    on public.strength_seasons (is_active, starts_at desc)
    where is_active = true;

drop trigger if exists trg_strength_seasons_updated_at on public.strength_seasons;
create trigger trg_strength_seasons_updated_at
    before update on public.strength_seasons
    for each row
    execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- strength_profiles
-- ---------------------------------------------------------------------------
create table if not exists public.strength_profiles (
    subject text primary key
        references public.user_profiles (subject) on delete cascade,
    display_alias text not null,
    competition_opted_in boolean not null default false,
    leaderboard_opt_in boolean not null default true,
    opted_in_at timestamptz,
    body_weight_kg numeric(5, 2),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint strength_profiles_alias_len check (
        char_length(display_alias) between 2 and 24
    ),
    constraint strength_profiles_alias_format check (
        display_alias ~ '^[가-힣A-Za-z0-9_-]+$'
    ),
    constraint strength_profiles_body_weight check (
        body_weight_kg is null
        or (body_weight_kg >= 30 and body_weight_kg <= 250)
    ),
    constraint strength_profiles_opted_in_at check (
        (competition_opted_in = false and opted_in_at is null)
        or (competition_opted_in = true and opted_in_at is not null)
    )
);

comment on table public.strength_profiles is
    '3대 경쟁 참가 프로필; subject=user_profiles.subject. 리더보드에는 display_alias만 노출';
comment on column public.strength_profiles.competition_opted_in is
    '경쟁 기능 참가(기록 제출 허용). false면 제출·리더보드 모두 제외';
comment on column public.strength_profiles.leaderboard_opt_in is
    '공개 리더보드 노출. competition_opted_in=true 여도 false면 순위에서만 제외(기록은 유지)';

create unique index if not exists idx_strength_profiles_display_alias_lower
    on public.strength_profiles (lower(display_alias));

create index if not exists idx_strength_profiles_leaderboard_eligible
    on public.strength_profiles (subject)
    where competition_opted_in = true and leaderboard_opt_in = true;

drop trigger if exists trg_strength_profiles_updated_at on public.strength_profiles;
create trigger trg_strength_profiles_updated_at
    before update on public.strength_profiles
    for each row
    execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- strength_lift_entries
-- ---------------------------------------------------------------------------
create table if not exists public.strength_lift_entries (
    id uuid primary key default gen_random_uuid(),
    subject text not null
        references public.strength_profiles (subject) on delete cascade,
    season_id uuid not null
        references public.strength_seasons (id) on delete restrict,
    lift_type text not null,
    weight_kg numeric(6, 2) not null,
    reps integer not null,
    estimated_1rm_kg numeric(7, 2) not null,
    source text not null default 'manual',
    verification_status text not null default 'self_reported',
    session_date date not null default ((timezone('utc', now()))::date),
    submitted_at timestamptz not null default now(),
    workout_history_id bigint,
    constraint strength_lift_entries_lift_type check (
        lift_type in ('squat', 'bench', 'deadlift')
    ),
    constraint strength_lift_entries_source check (
        source in ('manual', 'workout_log')
    ),
    constraint strength_lift_entries_verification check (
        verification_status in (
            'self_reported',
            'from_workout_log',
            'verified',
            'rejected'
        )
    ),
    constraint strength_lift_entries_weight check (
        weight_kg > 0 and weight_kg <= 500
    ),
    constraint strength_lift_entries_reps check (
        reps >= 1 and reps <= 20
    ),
    constraint strength_lift_entries_1rm_positive check (
        estimated_1rm_kg > 0
    ),
    constraint strength_lift_entries_source_status check (
        (source = 'manual' and verification_status in ('self_reported', 'verified', 'rejected'))
        or (source = 'workout_log' and verification_status in ('from_workout_log', 'verified', 'rejected'))
    )
);

comment on table public.strength_lift_entries is
    '3대 운동 제출 기록. 서버가 Epley 1RM 계산 후 estimated_1rm_kg 저장';
comment on column public.strength_lift_entries.workout_history_id is
    '로컬 workout_history 행 ID (source=workout_log 시). MVP 미사용';

-- 본인 기록·일일 제한·시즌 PR 조회
create index if not exists idx_strength_lift_entries_subject_season_lift_time
    on public.strength_lift_entries (subject, season_id, lift_type, submitted_at desc);

-- 리더보드 집계: 시즌·종목별 상위 1RM 스캔
create index if not exists idx_strength_lift_entries_season_lift_1rm
    on public.strength_lift_entries (season_id, lift_type, estimated_1rm_kg desc);

-- 리더보드 집계: countable 상태만 (partial index)
create index if not exists idx_strength_lift_entries_leaderboard_aggregate
    on public.strength_lift_entries (
        season_id,
        subject,
        lift_type,
        estimated_1rm_kg desc
    )
    where verification_status in ('self_reported', 'verified');

-- 시즌 내 세션일 기준 조회
create index if not exists idx_strength_lift_entries_season_session_date
    on public.strength_lift_entries (season_id, session_date desc);

-- ---------------------------------------------------------------------------
-- 시드: 2026 상반기 시즌
-- ---------------------------------------------------------------------------
insert into public.strength_seasons (slug, name, starts_at, ends_at, is_active)
values (
    '2026-h1',
    '2026 상반기 3대 경쟁',
    timestamptz '2026-01-01 00:00:00+00',
    timestamptz '2026-06-30 23:59:59+00',
    true
)
on conflict (slug) do nothing;

-- ---------------------------------------------------------------------------
-- RLS (MVP: 권장안 — 적용 시 아래 주석 해제)
-- FastAPI(service_role / DATABASE_URL) 경유 리더보드가 주 경로이므로
-- 클라이언트 직접 접근은 본인 행만 허용하는 정책을 권장.
-- ---------------------------------------------------------------------------
--
-- alter table public.strength_seasons enable row level security;
-- alter table public.strength_profiles enable row level security;
-- alter table public.strength_lift_entries enable row level security;
--
-- -- 시즌: 인증 사용자 읽기 전용
-- create policy "strength_seasons_select_authenticated"
--     on public.strength_seasons
--     for select
--     to authenticated
--     using (true);
--
-- -- 프로필: 본인만 읽기·쓰기 (subject = auth.uid()::text)
-- create policy "strength_profiles_select_own"
--     on public.strength_profiles
--     for select
--     to authenticated
--     using (auth.uid()::text = subject);
--
-- create policy "strength_profiles_insert_own"
--     on public.strength_profiles
--     for insert
--     to authenticated
--     with check (auth.uid()::text = subject);
--
-- create policy "strength_profiles_update_own"
--     on public.strength_profiles
--     for update
--     to authenticated
--     using (auth.uid()::text = subject)
--     with check (auth.uid()::text = subject);
--
-- -- 제출: 본인만 삽입·조회 (수정/삭제는 서버 전용)
-- create policy "strength_lift_entries_insert_own"
--     on public.strength_lift_entries
--     for insert
--     to authenticated
--     with check (auth.uid()::text = subject);
--
-- create policy "strength_lift_entries_select_own"
--     on public.strength_lift_entries
--     for select
--     to authenticated
--     using (auth.uid()::text = subject);
--
-- -- 리더보드 공개 조회는 anon/authenticated 에게 strength_lift_entries 전체 SELECT 를
-- -- 열지 말 것. VIEW + security_invoker 또는 FastAPI 전용 API 로만 노출.
