# Strength Competition Service Layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `backend_ai/services/strength_competition.py`에 3대 경쟁 도메인 로직을 단일 책임 모듈로 정리하고, `routers/strength_competition.py`는 HTTP·인증·에러 매핑만 담당하게 한다.

**Architecture:** 순수 함수(1RM·합산·ratio·검증)와 asyncpg I/O(시즌·프로필·제출·집계)를 분리한다. 리더보드 집계는 SQL CTE로 `per_lift → pivoted → ranked` 파이프라인을 공유하고, `total` / `ratio` 랭킹은 `ranked` CTE의 `ORDER BY`만 다르게 한다. 라우터는 `require_memory_subject` + `get_pool()`만 호출한다.

**Tech Stack:** Python 3.10+, FastAPI, asyncpg, Postgres (`strength_*` tables), pytest/unittest

**현재 상태:** 대부분의 로직이 `services/big3_competition_service.py`에 이미 존재. `strength_competition_service.py`는 re-export shim. **본 계획은 rename + gap 채우기(bodyweight ratio, workout_log source, 시즌 정책 명문화)** 중심.

---

## 모듈 구조 (목표)

```
backend_ai/
├── services/
│   ├── strength_competition.py      # ★ canonical domain + DB (신규/이전)
│   ├── strength_competition_schema.py  # Pydantic (기존 유지)
│   └── big3_competition_service.py  # deprecated shim → strength_competition re-export
├── routers/
│   └── strength_competition.py      # HTTP thin layer (기존 확장)
└── tests/
    ├── test_strength_competition_pure.py   # 순수 함수 (DB 없음)
    └── test_strength_competition_db.py       # asyncpg mock/integration (선택)
```

### 관심사 분리

| 레이어 | 책임 | DB 접근 |
|--------|------|---------|
| **Pure** | Epley, alias, input validation, total/ratio 계산 | 없음 |
| **Repository-style async** | season/profile/entry CRUD, CTE 집계 | asyncpg pool |
| **Router** | JWT subject, HTTP status, response_model | pool 주입만 |

---

## 도메인 규칙 (불변)

| 규칙 | 구현 위치 |
|------|-----------|
| 종목별 `max(estimated_1rm_kg)`만 PR·랭킹 반영 | `fetch_user_bests`, `_LEADERBOARD_RANKED_CTE` |
| 3종목 PR 모두 있어야 **total** 랭킹 참여 | `compute_total_1rm`, CTE `where squat/bench/deadlift is not null` |
| `body_weight_kg` 없으면 **ratio** 랭킹 제외 | `compute_bodyweight_ratio`, ratio CTE `where body_weight_kg is not null` |
| `manual` 제출 → `source='manual'`, `verification_status='self_reported'` | `submit_lift` |
| workout 연동 → `source='workout_log'`, `verification_status='from_workout_log'` | `submit_lift_from_workout` (신규) |
| 랭킹 집계 대상 verification | `self_reported`, `verified` (`from_workout_log`는 MVP 집계 제외 여부 결정 — 아래 정책 참고) |

### verification 집계 정책 (결정 필요)

**권장 (MVP):** `COUNTABLE_VERIFICATION = ('self_reported', 'verified')` — workout_log 자동 기록은 `from_workout_log`로 저장하되, 관리자 `verified` 전까지 total/ratio 랭킹 미반영.  
**대안:** `from_workout_log`도 집계 포함 → `COUNTABLE_VERIFICATION`에 추가.

---

## 시즌 정책

### `fetch_current_season(pool)`

- 조건: `is_active = true AND now() BETWEEN starts_at AND ends_at`
- `ORDER BY starts_at DESC LIMIT 1`
- 없으면 `None` 반환 (자동 생성 **하지 않음** — 운영 시드/관리자가 `strength_seasons` 관리)

### `ensure_current_season(pool)` (선택, env-gated)

- `STRENGTH_AUTO_CREATE_SEASON=true` 일 때만 동작
- 활성 시즌 없으면 slug `YYYY-h{1|2}` 자동 insert (현재 반기)
- **기본값 false** — 프로덕션은 마이그레이션 시드(`2026-h1`) 의존

### `resolve_season(pool, season_id: UUID | None)`

- `season_id` 있으면 `fetch_season_by_id`
- 없으면 `fetch_current_season` (또는 `ensure_current_season` if enabled)

---

## 함수 단위 작업 목록

### A. 타입·상수·예외

| # | 함수/심볼 | 책임 | 상태 |
|---|-----------|------|------|
| A1 | `LiftType`, `LiftSource`, `VerificationStatus` | Literal enum | 기존 |
| A2 | `COUNTABLE_VERIFICATION`, `MAX_*` 상수 | 가드레일 | 기존 |
| A3 | `StrengthCompetitionError` | 400 도메인 에러 | 기존 |
| A4 | `StrengthSeasonRow`, `StrengthProfileRow`, `StrengthLiftEntryRow` | dataclass | 기존 |
| A5 | `ProfileUpdate`, `MyRankResult`, `LeaderboardMode` | DTO (ratio용 enum 신규) | **신규** |

### B. 순수 함수 (단위 테스트 우선)

| # | 함수 | 입력 → 출력 | 상태 |
|---|------|-------------|------|
| B1 | `epley_one_rm_kg(weight_kg, reps)` | Epley 1RM | 기존 |
| B2 | `validate_submission_input(lift, weight, reps)` | lift, w, r, est_1rm | 기존 |
| B3 | `normalize_display_alias(raw)` | 별칭 정규화 | 기존 |
| B4 | `default_display_alias(subject)` | `리프터-XXXX` | 기존 |
| B5 | `compute_total_1rm(bests)` | 3종목 None 하나라도 → `None` | 기존 |
| B6 | `compute_bodyweight_ratio(total_kg, body_weight_kg)` | `None` if either missing/≤0; else `round(total/bw, 4)` | **신규** |
| B7 | `bests_to_records(bests)` | API records dict | 기존 |
| B8 | `records_with_ratio(bests, body_weight_kg)` | records + `bodyweight_ratio` | **신규** |
| B9 | `resolve_source_verification(source: LiftSource)` | `(source, verification_status)` 쌍 | **신규** |

```python
def resolve_source_verification(source: LiftSource) -> tuple[str, str]:
    if source == "manual":
        return "manual", "self_reported"
    return "workout_log", "from_workout_log"
```

### C. 시즌

| # | 함수 | 책임 | 상태 |
|---|------|------|------|
| C1 | `fetch_current_season(pool)` | 활성 시즌 1건 | 기존 |
| C2 | `fetch_season_by_id(pool, season_id)` | ID 조회 | 기존 |
| C3 | `resolve_season(pool, season_id?)` | 현재 또는 지정 | 기존 |
| C4 | `ensure_current_season(pool)` | env-gated 자동 생성 | **신규** |

### D. 프로필

| # | 함수 | 책임 | 상태 |
|---|------|------|------|
| D1 | `ensure_user_profile(pool, subject)` | `user_profiles` FK 선행 | 기존 |
| D2 | `get_profile(pool, subject)` | 단건 조회 | 기존 |
| D3 | `upsert_profile(pool, subject, ProfileUpdate)` | merge upsert | 기존 |
| D4 | `opt_in` / `opt_out` / `set_leaderboard_visibility` | 레거시 래퍼 (deprecated) | 기존 유지 |

### E. Lift 제출

| # | 함수 | 책임 | 상태 |
|---|------|------|------|
| E1 | `_count_submissions_today(...)` | 일일 제한 | 기존 |
| E2 | `_best_1rm_in_window(..., days=7)` | 주간 급증 가드 | 기존 |
| E3 | `submit_lift(pool, *, subject, season_id, lift, w, r, est, session_date, source='manual')` | manual 기본; source 파라미터화 | **확장** |
| E4 | `submit_lift_from_workout(pool, *, ..., workout_history_id)` | `workout_log` + `from_workout_log` | **신규** |

제출 전 검증 순서:

1. `validate_submission_input` (순수)
2. profile `competition_opted_in`
3. 일 3회/종목
4. 7일 10% 가드 (countable entries만)
5. INSERT with resolved source/verification

### F. 집계·리더보드·순위

| # | 함수 | 책임 | 상태 |
|---|------|------|------|
| F1 | `fetch_user_bests(pool, subject, season_id)` | 종목별 MAX 1RM | 기존 |
| F2 | `fetch_recent_entries(pool, subject, season_id, limit)` | 최근 제출 | 기존 |
| F3 | `_LEADERBOARD_BASE_CTE` | per_lift + pivoted | 기존 이름 변경 권장 |
| F4 | `_LEADERBOARD_TOTAL_CTE` | total `rank() over (order by total desc)` | 기존 |
| F5 | `_LEADERBOARD_RATIO_CTE` | ratio `rank() over (order by total/body_weight desc)` + bw 필수 | **신규** |
| F6 | `fetch_leaderboard(pool, season_id, *, mode='total', limit, offset)` | mode 분기 | **확장** |
| F7 | `count_leaderboard_eligible(pool, season_id, mode)` | 참가자 수 | **확장** |
| F8 | `fetch_my_rank(pool, subject, season_id, mode)` | reason 코드 포함 | **확장** |

`fetch_my_rank` reason 확장:

| reason | 조건 |
|--------|------|
| `not_opted_in` | profile 없음 또는 competition_opted_in=false |
| `leaderboard_hidden` | leaderboard_opt_in=false |
| `incomplete_lifts` | 3종목 PR 미완 |
| `missing_body_weight` | mode=ratio 이고 body_weight_kg 없음 |
| `null` | ranked=True |

### G. 직렬화 (API helper)

| # | 함수 | 책임 |
|---|------|------|
| G1 | `season_to_dict` | SeasonOut 필드 |
| G2 | `profile_to_public_dict` | subject 미노출 |
| G3 | `submission_to_dict` | LiftEntryOut 필드 |
| G4 | `leaderboard_entry_to_dict` | total 또는 ratio 필드 |

### H. 라우터 (`routers/strength_competition.py`)

| Endpoint | Service 호출 |
|----------|----------------|
| `GET /strength/seasons/current` | `fetch_current_season` |
| `GET/PUT /strength/profile/me` | `get_profile` / `upsert_profile` |
| `POST /strength/lifts` | `resolve_season` → `submit_lift` |
| `GET /strength/records/me` | `fetch_user_bests` + `records_with_ratio` |
| `GET /strength/leaderboard?mode=total\|ratio` | `fetch_leaderboard` |
| `GET /strength/rank/me?mode=total\|ratio` | `fetch_my_rank` |

HTTP 매핑: `StrengthCompetitionError` → 400, unique alias → 409, no season → 404, no pool → 503.

---

## SQL 쿼리 초안

### 1. 현재 시즌

```sql
select id, slug, name, starts_at, ends_at, is_active
from public.strength_seasons
where is_active = true
  and starts_at <= now()
  and ends_at >= now()
order by starts_at desc
limit 1;
```

### 2. 프로필 upsert

```sql
insert into public.strength_profiles (
    subject, display_alias, competition_opted_in,
    leaderboard_opt_in, opted_in_at, body_weight_kg, updated_at
)
values ($1, $2, $3, $4, $5, $6, $7)
on conflict (subject) do update set
    display_alias = excluded.display_alias,
    competition_opted_in = excluded.competition_opted_in,
    leaderboard_opt_in = excluded.leaderboard_opt_in,
    opted_in_at = excluded.opted_in_at,
    body_weight_kg = excluded.body_weight_kg,
    updated_at = excluded.updated_at
returning subject, display_alias, competition_opted_in,
          leaderboard_opt_in, opted_in_at, body_weight_kg;
```

### 3. Lift insert (source 분기)

```sql
insert into public.strength_lift_entries (
    subject, season_id, lift_type, weight_kg, reps,
    estimated_1rm_kg, source, verification_status,
    session_date, workout_history_id
)
values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
returning id, lift_type, weight_kg, reps, estimated_1rm_kg,
          source, verification_status, session_date, submitted_at;
```

### 4. 사용자별 시즌 PR (종목별 MAX)

```sql
select lift_type, max(estimated_1rm_kg) as best_1rm
from public.strength_lift_entries
where subject = $1
  and season_id = $2
  and verification_status = any($3::text[])
group by lift_type;
```

### 5. Total 리더보드 CTE (핵심)

```sql
with per_lift as (
    select e.subject, e.lift_type, max(e.estimated_1rm_kg) as best_1rm
    from public.strength_lift_entries e
    inner join public.strength_profiles p
        on p.subject = e.subject
       and p.competition_opted_in = true
       and p.leaderboard_opt_in = true
    where e.season_id = $1
      and e.verification_status = any($2::text[])
    group by e.subject, e.lift_type
),
pivoted as (
    select
        subject,
        max(case when lift_type = 'squat' then best_1rm end) as squat_1rm,
        max(case when lift_type = 'bench' then best_1rm end) as bench_1rm,
        max(case when lift_type = 'deadlift' then best_1rm end) as deadlift_1rm
    from per_lift
    group by subject
),
ranked as (
    select
        pv.subject,
        p.display_alias,
        p.body_weight_kg,
        pv.squat_1rm,
        pv.bench_1rm,
        pv.deadlift_1rm,
        (pv.squat_1rm + pv.bench_1rm + pv.deadlift_1rm) as total_1rm,
        case
            when p.body_weight_kg is not null and p.body_weight_kg > 0
            then (pv.squat_1rm + pv.bench_1rm + pv.deadlift_1rm) / p.body_weight_kg
        end as bodyweight_ratio,
        rank() over (
            order by (pv.squat_1rm + pv.bench_1rm + pv.deadlift_1rm) desc,
                     p.display_alias asc
        ) as rank_total,
        rank() over (
            order by
                case when p.body_weight_kg is not null and p.body_weight_kg > 0
                     then (pv.squat_1rm + pv.bench_1rm + pv.deadlift_1rm) / p.body_weight_kg
                end desc nulls last,
                p.display_alias asc
        ) as rank_ratio
    from pivoted pv
    inner join public.strength_profiles p on p.subject = pv.subject
    where pv.squat_1rm is not null
      and pv.bench_1rm is not null
      and pv.deadlift_1rm is not null
)
select display_alias, squat_1rm, bench_1rm, deadlift_1rm,
       total_1rm, bodyweight_ratio,
       rank_total, rank_ratio
from ranked
order by rank_total asc   -- mode=total
-- order by rank_ratio asc -- mode=ratio (bodyweight_ratio is not null filter)
limit $3 offset $4;
```

Ratio 리더보드 조회 시 추가: `where bodyweight_ratio is not null`.

### 6. 내 순위

```sql
-- ranked CTE 동일 후
select rank_total, rank_ratio, display_alias, bodyweight_ratio
from ranked
where subject = $3;
```

### 7. 일일 제출 수

```sql
select count(*)::int
from public.strength_lift_entries
where subject = $1 and season_id = $2 and lift_type = $3
  and submitted_at >= date_trunc('day', timezone('utc', now()));
```

---

## 실패·엣지 케이스

### 인증·인프라

| 케이스 | 동작 |
|--------|------|
| JWT 없음/만료 | 401 (`require_memory_subject`) |
| `DATABASE_URL` 미설정 / pool None | 503 |
| DB 연결 끊김 | 500 + 로그 (subject 미노출) |

### 시즌

| 케이스 | 동작 |
|--------|------|
| 활성 시즌 없음 | `fetch_current_season` → None; 제출/리더보드 → 404 "Season not found" |
| `season_id` UUID 잘못됨 | 404 |
| 시즌 기간 종료 후 제출 | 정책: 현재 시즌만 허용 → `resolve_season`이 None이면 404 |
| 겹치는 활성 시즌 2개 | `starts_at desc` 최신 1건 — 운영에서 방지 권장 |

### 프로필

| 케이스 | 동작 |
|--------|------|
| 미 opt-in 제출 | 400 `opt-in required` |
| opt-out 시 `opted_in_at` | NULL로 클리어 (DB check 제약) |
| leaderboard만 on, competition off | 400 |
| 별칭 중복 (`idx_strength_profiles_display_alias_lower`) | 409 |
| 별칭 2자 미만 / 특수문자 | 400 |
| `body_weight_kg` 29.9 또는 250.1 | 400 |

### Lift 제출

| 케이스 | 동작 |
|--------|------|
| 잘못된 lift_type | 400 |
| reps > 12 (API) / > 20 (DB) | API에서 12로 차단 |
| weight 초과 cap | 400 |
| 일 3회 초과 | 400 |
| 7일 10% 초과 1RM | 400 |
| `session_date` 미래 | 400 (선택 검증) |
| 동일 weight/reps 재제출 | 허용 (MAX만 갱신되면 랭킹 변동 없음) |
| `rejected` 상태 과거 기록 | 집계 제외; 새 제출로 PR 갱신 가능 |
| workout_log without `workout_history_id` | 400 (workout 경로) |

### 집계·랭킹

| 케이스 | 동작 |
|--------|------|
| 스쿼트만 있고 벤치/데드 없음 | total/ratio 미참여; `incomplete_lifts` |
| 한 종목에 countable + rejected 혼재 | MAX는 countable만 |
| 동일 total, 다른 alias | alias asc 타이브레이크 |
| ratio: body_weight NULL | ratio 리더보드 제외; rank/me → `missing_body_weight` |
| leaderboard_opt_in=false | 기록 유지, ranked=false `leaderboard_hidden` |
| 페이징 offset > total | 빈 배열 |

### 보안

| 케이스 | 동작 |
|--------|------|
| API 응답에 `subject` 노출 | 금지 — `display_alias`만 |
| 타인 profile 조회 | 엔드포인트 없음 (me only) |

---

## pytest / unittest 테스트 목록

### `tests/test_strength_competition_pure.py` (DB 없음, TDD 우선)

| ID | 테스트명 | 검증 |
|----|----------|------|
| P01 | `test_epley_known_values` | 100kg×5 reps |
| P02 | `test_epley_rejects_non_positive_weight` | ValueError |
| P03 | `test_validate_submission_happy_path` | squat/bench/deadlift |
| P04 | `test_validate_rejects_invalid_lift` | unknown lift |
| P05 | `test_validate_rejects_reps_over_12` | |
| P06 | `test_validate_rejects_weight_over_cap` | bench 350 |
| P07 | `test_normalize_alias_valid_korean` | trim + 허용 문자 |
| P08 | `test_normalize_alias_too_short` | StrengthCompetitionError |
| P09 | `test_normalize_alias_invalid_chars` | |
| P10 | `test_default_alias_deterministic` | 동일 subject → 동일 alias |
| P11 | `test_compute_total_requires_all_three` | None if missing lift |
| P12 | `test_compute_total_sums_three` | 300.0 |
| P13 | `test_compute_bodyweight_ratio_happy` | 300/75 = 4.0 |
| P14 | `test_compute_bodyweight_ratio_none_without_bw` | |
| P15 | `test_compute_bodyweight_ratio_none_zero_bw` | |
| P16 | `test_bests_to_records_shape` | keys + total |
| P17 | `test_records_with_ratio_includes_ratio` | |
| P18 | `test_resolve_source_verification_manual` | manual/self_reported |
| P19 | `test_resolve_source_verification_workout` | workout_log/from_workout_log |

### `tests/test_strength_competition_db.py` (asyncpg mock 또는 testcontainers)

> `unittest.mock.AsyncMock`으로 `pool.fetchrow/fetch/fetchval/execute` 스텁. 통합 테스트는 `DATABASE_URL` 있을 때만 `@pytest.mark.integration`.

| ID | 테스트명 | 검증 |
|----|----------|------|
| D01 | `test_fetch_current_season_returns_active_window` | SQL 호출·row 매핑 |
| D02 | `test_fetch_current_season_none_when_empty` | |
| D03 | `test_upsert_profile_sets_opted_in_at_on_first_opt_in` | |
| D04 | `test_upsert_profile_clears_opted_in_at_on_opt_out` | check 제약 호환 |
| D05 | `test_submit_lift_requires_opt_in` | 400 path |
| D06 | `test_submit_lift_inserts_manual_self_reported` | INSERT args |
| D07 | `test_submit_lift_from_workout_sets_source` | workout_log |
| D08 | `test_submit_lift_daily_limit_enforced` | count=3 → error |
| D09 | `test_submit_lift_weekly_improvement_guard` | 10% cap |
| D10 | `test_fetch_user_bests_groups_max_per_lift` | |
| D11 | `test_leaderboard_excludes_incomplete_three_lifts` | CTE filter |
| D12 | `test_leaderboard_ratio_excludes_missing_body_weight` | |
| D13 | `test_fetch_my_rank_incomplete_lifts_reason` | |
| D14 | `test_fetch_my_rank_missing_body_weight_ratio_mode` | |
| D15 | `test_count_leaderboard_eligible_matches_ranked_rows` | |

### `tests/test_strength_competition_router.py` (FastAPI TestClient, pool mock)

| ID | 테스트명 | 검증 |
|----|----------|------|
| R01 | `test_get_current_season_404_when_none` | |
| R02 | `test_put_profile_401_without_auth` | |
| R03 | `test_post_lift_400_domain_error` | message passthrough |
| R04 | `test_leaderboard_mode_ratio_query_param` | |
| R05 | `test_rank_me_returns_reason_when_hidden` | |

### 실행 명령

```bash
cd backend_ai
python -m unittest tests.test_strength_competition_pure -v
# integration (optional):
# DATABASE_URL=... python -m pytest tests/test_strength_competition_db.py -v -m integration
```

---

## 구현 태스크 (실행 순서)

### Task 1: 파일 이전

- [ ] `big3_competition_service.py` → `strength_competition.py` 복사/이전
- [ ] `big3_competition_service.py`를 `from services.strength_competition import *` shim으로 변경
- [ ] import 경로 일괄 업데이트 (`routers`, `tests`)

### Task 2: Pure 함수 gap

- [ ] `compute_bodyweight_ratio`, `records_with_ratio`, `resolve_source_verification` 추가
- [ ] P13–P19 테스트 작성 후 구현

### Task 3: submit source 확장

- [ ] `submit_lift(..., source: LiftSource = "manual")` 파라미터화
- [ ] `submit_lift_from_workout` 추가
- [ ] D06–D09 테스트

### Task 4: Ratio 리더보드

- [ ] CTE에 `bodyweight_ratio`, `rank_ratio` 추가
- [ ] `fetch_leaderboard(mode=...)`, `fetch_my_rank(mode=...)` 확장
- [ ] schema: `LeaderboardMode`, `bodyweight_ratio` 필드 optional
- [ ] D11–D15, R04–R05

### Task 5: 라우터 query param

- [ ] `GET /strength/leaderboard?mode=total|ratio` (default total)
- [ ] `GET /strength/rank/me?mode=total|ratio`

### Task 6: 문서 동기화

- [ ] `docs/superpowers/specs/2026-06-09-big3-competition-design.md` → `/strength`, ratio 랭킹 반영

---

## 마이그레이션·호환

- DB 스키마 `006_strength_competition.sql`은 이미 `source` / `verification_status` 제약 충족 — **추가 migration 불필요** (ratio는 계산 필드).
- 레거시 `/competition/*` 라우터는 deprecation 주석 후 유지 또는 제거는 별도 PR.
- Flutter는 이미 `/strength/*` 전환됨 — `mode=ratio` UI는 후속.

---

## 완료 기준 (Definition of Done)

1. `python -m unittest tests.test_strength_competition_pure` 전부 PASS
2. 기존 `test_big3_competition.py` shim import로 PASS 유지
3. `strength_competition.py` 단일 canonical; router는 I/O만
4. total/ratio 랭킹 규칙이 SQL CTE + pure 함수 테스트로 문서화됨
5. API 응답에 `subject` 미포함
