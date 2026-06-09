# 3대 운동 경쟁 시스템 설계

## 목표

- 스쿼트·벤치·데드 기록을 서버에 제출
- 사용자별 최고 Epley 1RM 및 3대 합산 점수 산출
- 시즌 단위 리더보드
- PII 최소화, 허위·급격 증량 완화
- 기존 Flutter + FastAPI + Supabase/Postgres + JWT 인증 재사용

## 아키텍처

```
Flutter (big3_competition feature)
  → ApiClient (Bearer JWT)
    → FastAPI /competition/*
      → asyncpg (DATABASE_URL)
        → Postgres (strength_seasons, strength_profiles, strength_lift_entries)
```

리더보드는 **FastAPI 경유만** 제공. `user_id`/subject/email은 API 응답에 포함하지 않음.

## 데이터 모델

| 테이블 | 역할 |
|--------|------|
| `strength_seasons` | 시즌 메타 (slug, 기간, is_active) |
| `strength_profiles` | `subject` FK, `competition_opted_in`, `leaderboard_opt_in`, `display_alias` |
| `strength_lift_entries` | 제출 행, `source`, `verification_status` |

`source`: `manual` \| `workout_log`  
`verification_status`: `self_reported` \| `from_workout_log` \| `verified` \| `rejected`  
MVP 집계: `self_reported`, `verified`만 반영.

## API

| Method | Path | 설명 |
|--------|------|------|
| GET | `/competition/seasons/current` | 활성 시즌 |
| GET | `/competition/profile/me` | 내 opt-in 상태 |
| POST | `/competition/opt-in` | 참가 (별칭 선택) |
| POST | `/competition/opt-out` | 참가 취소 |
| POST | `/competition/leaderboard-visibility` | 리더보드 노출 on/off |
| POST | `/competition/submit` | 기록 제출 |
| GET | `/competition/me/stats` | 내 시즌 최고·합산 |
| GET | `/competition/leaderboard` | 별칭·1RM·순위만 |

## 보안·신뢰 (MVP)

- **opt-in**: 미참가 시 제출 불가, 리더보드 미노출
- **별칭**: 기본 `리프터-XXXX` (SHA256 파생), 사용자 지정 가능
- **가드레일**: lift별 상한 kg, reps ≤ 12, 일 3회/종목, 7일 내 10% 초과 1RM 증가 거부
- **RLS**: Supabase 직접 접근 시 본인 행만 (방어적)

## Flutter

`lib/features/big3_competition/` — domain / data / application / presentation  
프로필 탭에서 「3대 경쟁」 진입.

## 미구현 (확장 포인트)

- 영상 업로드·관리자 검수 UI
- 체중급·성별 부문
- workout_history 자동 import
