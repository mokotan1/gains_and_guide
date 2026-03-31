-- 유산소 세션 기록 (로컬 앱과 동일 스키마; Supabase 동기화용)

create table if not exists public.cardio_history (
    id uuid primary key default gen_random_uuid(),
    user_id text not null,
    cardio_name text not null,
    duration_minutes double precision not null check (duration_minutes >= 0),
    distance_km double precision,
    calories double precision,
    rpe double precision,
    date date not null
);

create index if not exists idx_cardio_history_user_date
    on public.cardio_history (user_id, date desc);

comment on table public.cardio_history is '유산소 운동 세션 (시간/거리/칼로리/RPE); user_id는 JWT sub 또는 user_profiles.subject와 정렬';

alter table public.cardio_history enable row level security;

-- Supabase Auth 사용 시: 인증된 사용자만 본인 행 접근
create policy "Users manage own cardio_history"
    on public.cardio_history
    for all
    using (auth.uid()::text = user_id)
    with check (auth.uid()::text = user_id);
