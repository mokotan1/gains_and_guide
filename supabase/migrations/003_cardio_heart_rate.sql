-- 심박(웨어러블) 기반 유산소 분석용 컬럼
alter table public.cardio_history
  add column if not exists avg_heart_rate integer,
  add column if not exists max_heart_rate integer;

comment on column public.cardio_history.avg_heart_rate is '세션 평균 심박수 (bpm), Health 연동 시';
comment on column public.cardio_history.max_heart_rate is '세션 최대 심박수 (bpm), Health 연동 시';
