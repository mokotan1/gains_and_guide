-- 출처(수동/웨어러블), 외부 ID, 클라우드 동기화 시각
alter table public.cardio_history
  add column if not exists source text not null default 'manual',
  add column if not exists external_id text,
  add column if not exists synced_at timestamptz;

comment on column public.cardio_history.source is 'manual | health';
comment on column public.cardio_history.external_id is 'HealthKit/Health Connect 샘플 uuid (중복 방지)';
comment on column public.cardio_history.synced_at is 'Supabase 반영 시각 (클라이언트 기준)';

-- 웨어러블 행만 user_id + external_id 유일
create unique index if not exists idx_cardio_history_user_external_unique
  on public.cardio_history (user_id, external_id)
  where external_id is not null;

update public.cardio_history
set source = 'health'
where cardio_name like 'HealthSync|%';
