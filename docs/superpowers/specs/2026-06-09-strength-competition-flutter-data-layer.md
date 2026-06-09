# Flutter Strength Competition — Data Layer Design

## Context

- Backend: FastAPI `/strength/*` (JWT Bearer via `apiClientProvider` extra headers)
- Existing feature: `lib/features/big3_competition/` — 동일 API를 이미 호출 중
- Goal: `lib/features/strength_competition/` 로 도메인 명칭·모델·repository를 정리

## Approach (recommended)

**Option B — 신규 `strength_competition` + `big3_competition` deprecation shim**

| Option | 설명 | 장점 | 단점 |
|--------|------|------|------|
| A. big3 in-place rename | 폴더·클래스 일괄 rename | diff 작음 | breaking import 다수 |
| **B. 신규 feature + shim** | strength 신규, big3는 export/위임 | 점진 마이그레이션 | 일시적 중복 |
| C. data만 분리 | big3 UI 유지, data 공유 | UI 변경 없음 | 이중 모델 유지 |

**권장: B** — UI는 `presentation`을 나중에 이전하고, data/domain/application을 먼저 canonical화.

## Privacy

- API JSON에 `subject` 필드가 없음을 전제로 `fromJson`에서 **무시·미매핑**
- `fromJson`에 `subject`/`user_id` 키가 와도 파싱하지 않음 (방어적 drop)

## ApiClient 현황

`api_client.dart`는 이미 **GET / PUT / POST** 를 지원한다. Strength feature에 필요한 HTTP 메서드는 충족됨.

추가 검토 항목은 §ApiClient 확장 참고.

---

## File Structure

```
lib/features/strength_competition/
├── domain/
│   ├── models/
│   │   ├── strength_season.dart
│   │   ├── strength_profile.dart
│   │   ├── strength_lift_record.dart      # 단건 제출 (LiftEntryOut)
│   │   ├── strength_season_records.dart   # 시즌 PR 집계 (RecordsOut) — 보조 모델
│   │   ├── strength_leaderboard_entry.dart
│   │   ├── strength_rank_summary.dart
│   │   ├── strength_profile_update.dart   # PUT body DTO
│   │   └── strength_lift_type.dart        # enum squat | bench | deadlift
│   └── repositories/
│       └── strength_competition_repository.dart
├── data/
│   ├── strength_competition_repository_impl.dart
│   └── mappers/
│       └── strength_api_mapper.dart       # JSON → domain (선택, repo 인라인도 가능)
├── application/
│   ├── strength_competition_service.dart
│   └── strength_competition_exceptions.dart  # ValidationException (선택)
└── presentation/
    ├── providers/
    │   └── strength_competition_providers.dart
    └── strength_competition_screen.dart   # big3 화면 이전 시

test/features/strength_competition/
├── models/
│   ├── strength_profile_test.dart
│   ├── strength_lift_record_test.dart
│   ├── strength_season_records_test.dart
│   ├── strength_leaderboard_entry_test.dart
│   └── strength_rank_summary_test.dart
├── data/
│   └── strength_competition_repository_impl_test.dart
└── application/
    └── strength_competition_service_test.dart

test/fixtures/strength_competition/
├── season_current.json
├── profile_me.json
├── records_me.json
├── submit_lift.json
├── leaderboard.json
└── rank_me.json
```

### Layer responsibilities

| Layer | Depends on | Responsibility |
|-------|------------|----------------|
| **domain** | nothing | Models, repository interface |
| **data** | `ApiClient`, domain | HTTP paths, JSON parse, `AppException` pass-through |
| **application** | domain | Client-side validation (reps≤12, lift type), orchestration |
| **presentation** | application + Riverpod | UI state, `ref.invalidate` after mutations |

---

## Dart Models — Fields

### `StrengthLiftType` (enum)

```dart
enum StrengthLiftType { squat, bench, deadlift }
// api: "squat" | "bench" | "deadlift"
```

### `StrengthSeason`

| Field | Type | JSON key | Notes |
|-------|------|----------|-------|
| `id` | `String` | `id` | UUID string |
| `slug` | `String` | `slug` | e.g. `2026-h1` |
| `name` | `String` | `name` | 표시명 |
| `startsAt` | `DateTime` | `starts_at` | ISO8601 |
| `endsAt` | `DateTime` | `ends_at` | ISO8601 |
| `isActive` | `bool` | `is_active` | |

### `StrengthProfile`

| Field | Type | JSON key | Notes |
|-------|------|----------|-------|
| `displayAlias` | `String` | `display_alias` | 필수, UI 노출명 |
| `competitionOptedIn` | `bool` | `competition_opted_in` | legacy `opted_in` 폴백 |
| `leaderboardOptIn` | `bool` | `leaderboard_opt_in` | default true |
| `optedInAt` | `DateTime?` | `opted_in_at` | |
| `bodyWeightKg` | `double?` | `body_weight_kg` | ratio 랭킹용 |

**Computed:** `bool get canSubmit => competitionOptedIn;`

**Excluded:** `subject`, `user_id` — never parsed.

### `StrengthLiftRecord` (단건 제출)

| Field | Type | JSON key | Notes |
|-------|------|----------|-------|
| `id` | `String` | `id` | |
| `liftType` | `StrengthLiftType` | `lift_type` | |
| `weightKg` | `double` | `weight_kg` | |
| `reps` | `int` | `reps` | |
| `estimated1rmKg` | `double` | `estimated_1rm_kg` | 서버 계산값 |
| `source` | `String` | `source` | `manual` \| `workout_log` |
| `verificationStatus` | `String` | `verification_status` | |
| `sessionDate` | `DateTime` | `session_date` | date only → local date |
| `submittedAt` | `DateTime` | `submitted_at` | |

### `StrengthSeasonRecords` (집계 PR — `RecordsOut`)

| Field | Type | JSON key | Notes |
|-------|------|----------|-------|
| `squat1rmKg` | `double?` | `squat_1rm_kg` | 종목별 MAX |
| `bench1rmKg` | `double?` | `bench_1rm_kg` | |
| `deadlift1rmKg` | `double?` | `deadlift_1rm_kg` | |
| `total1rmKg` | `double?` | `total_1rm_kg` | 3종목 모두 있을 때만 |
| `bodyweightRatio` | `double?` | `bodyweight_ratio` | **향후** API 필드 |

**Computed:** `bool get isComplete => squat/bench/deadlift 모두 non-null`

### `StrengthLeaderboardEntry`

| Field | Type | JSON key | Notes |
|-------|------|----------|-------|
| `rank` | `int` | `rank` | |
| `displayAlias` | `String` | `display_alias` | |
| `squat1rmKg` | `double` | `squat_1rm_kg` | |
| `bench1rmKg` | `double` | `bench_1rm_kg` | |
| `deadlift1rmKg` | `double` | `deadlift_1rm_kg` | |
| `total1rmKg` | `double` | `total_1rm_kg` | |
| `bodyweightRatio` | `double?` | `bodyweight_ratio` | optional |

### `StrengthRankSummary`

| Field | Type | JSON key | Notes |
|-------|------|----------|-------|
| `season` | `StrengthSeason` | `season` | |
| `ranked` | `bool` | `ranked` | |
| `rank` | `int?` | `rank` | ranked=false 시 null |
| `displayAlias` | `String?` | `display_alias` | |
| `reason` | `StrengthRankReason?` | `reason` | see enum below |
| `records` | `StrengthSeasonRecords` | `records` | |
| `totalParticipants` | `int` | `total_participants` | |

```dart
enum StrengthRankReason {
  notOptedIn,        // not_opted_in
  leaderboardHidden, // leaderboard_hidden
  incompleteLifts,   // incomplete_lifts
  missingBodyWeight, // missing_body_weight (ratio mode)
}
```

### `StrengthProfileUpdate` (PUT body, domain DTO)

| Field | Type | JSON key | Send when |
|-------|------|----------|-----------|
| `displayAlias` | `String?` | `display_alias` | non-null, trimmed |
| `competitionOptedIn` | `bool?` | `competition_opted_in` | |
| `leaderboardOptIn` | `bool?` | `leaderboard_opt_in` | |
| `bodyWeightKg` | `double?` | `body_weight_kg` | |

### Composite results (repository return types, not persisted)

```dart
class StrengthSubmitResult {
  final StrengthLiftRecord entry;
  final StrengthSeason season;
  final StrengthSeasonRecords records;
}

class StrengthMyRecordsResult {
  final StrengthSeason season;
  final StrengthProfile? profile;
  final StrengthSeasonRecords records;
  final List<StrengthLiftRecord> recentEntries;
}

class StrengthLeaderboardPage {
  final StrengthSeason season;
  final List<StrengthLeaderboardEntry> entries;
  final int limit;
  final int offset;
  final int totalEligible;
}
```

---

## Repository Interface

```dart
abstract class StrengthCompetitionRepository {
  /// GET /strength/seasons/current
  Future<StrengthSeason?> fetchCurrentSeason();

  /// GET /strength/profile/me — profile null = 미생성
  Future<StrengthProfile?> fetchMyProfile();

  /// PUT /strength/profile/me — partial update
  Future<StrengthProfile> updateProfile(StrengthProfileUpdate update);

  /// Convenience wrappers (application에서도 가능)
  Future<StrengthProfile> optIn({String? displayAlias});
  Future<StrengthProfile> optOut();
  Future<StrengthProfile> setLeaderboardVisibility({required bool visible});

  /// POST /strength/lifts
  Future<StrengthSubmitResult> submitLift({
    required StrengthLiftType liftType,
    required double weightKg,
    required int reps,
    DateTime? sessionDate,
  });

  /// GET /strength/records/me?season_id=&recent_limit=
  Future<StrengthMyRecordsResult> fetchMyRecords({
    String? seasonId,
    int recentLimit = 10,
  });

  /// GET /strength/leaderboard?season_id=&limit=&offset=&mode=
  Future<StrengthLeaderboardPage> fetchLeaderboard({
    String? seasonId,
    int limit = 50,
    int offset = 0,
    StrengthLeaderboardMode mode = StrengthLeaderboardMode.total,
  });

  /// GET /strength/rank/me?season_id=&mode=
  Future<StrengthRankSummary> fetchMyRank({
    String? seasonId,
    StrengthLeaderboardMode mode = StrengthLeaderboardMode.total,
  });
}

enum StrengthLeaderboardMode { total, ratio }
```

### Endpoint mapping

| Repository method | HTTP | Path |
|-------------------|------|------|
| `fetchCurrentSeason` | GET | `/strength/seasons/current` |
| `fetchMyProfile` | GET | `/strength/profile/me` |
| `updateProfile` | PUT | `/strength/profile/me` |
| `submitLift` | POST | `/strength/lifts` |
| `fetchMyRecords` | GET | `/strength/records/me` |
| `fetchLeaderboard` | GET | `/strength/leaderboard` |
| `fetchMyRank` | GET | `/strength/rank/me` |

### `StrengthCompetitionRepositoryImpl`

- 단일 의존성: `ApiClient`
- 쿼리 문자열: `Uri(queryParameters: ...)` 또는 private `_buildQuery()`
- JSON 파싱 실패: `FormatException` → 그대로 throw (application/UI에서 `ParseException`으로 매핑 가능)
- `ServerException(400/409)`: repository는 변환하지 않고 상위에서 statusCode 분기 (향후 `StrengthApiException`)

---

## Application Layer (`StrengthCompetitionService`)

| Method | Responsibility |
|--------|----------------|
| `currentSeason()` | delegate |
| `myProfile()` | delegate |
| `updateProfile(...)` | delegate |
| `optIn` / `optOut` / `setLeaderboardVisibility` | delegate |
| `submitLift(...)` | `WorkoutConstants.big3LiftTypes` 또는 `StrengthLiftType` 검증, reps 1–12, weight > 0 |
| `myRecords(...)` | delegate |
| `leaderboard(...)` | delegate |
| `myRank(...)` | delegate |

Client validation은 서버 가드와 **중복 허용** (UX 즉시 피드백).

---

## ApiClient Extension Review

### Already sufficient (no blocker)

| Method | Used by |
|--------|---------|
| `get(path)` | season, profile, records, leaderboard, rank |
| `put(path, body)` | profile update |
| `post(path, body)` | submit lift |

### Recommended enhancements (optional, separate PR)

| Enhancement | Why |
|-------------|-----|
| `get(path, {Map<String, String>? queryParameters})` | 수동 query concat 제거, encoding 안전 |
| `request<T>(method, path, {body, query})` private core | GET/PUT/POST DRY |
| Error body decode on 4xx | FastAPI `detail` → `userMessage` (409 alias duplicate) |
| `ServerException`에 `detail` 필드 | UI: "별칭이 이미 사용 중입니다" |

### Not needed now

- DELETE, PATCH, multipart

---

## Riverpod Providers

```dart
final strengthCompetitionRepositoryProvider =
    Provider<StrengthCompetitionRepository>((ref) {
  return StrengthCompetitionRepositoryImpl(ref.watch(apiClientProvider));
});

final strengthCompetitionServiceProvider = ...

final strengthCurrentSeasonProvider = FutureProvider<StrengthSeason?>(...);
final strengthMyProfileProvider = FutureProvider<StrengthProfile?>(...);
final strengthMyRecordsProvider = FutureProvider<StrengthMyRecordsResult>(...);
final strengthLeaderboardProvider = FutureProvider<StrengthLeaderboardPage>(...);
final strengthMyRankProvider = FutureProvider<StrengthRankSummary>(...);
```

Mutation 후: `ref.invalidate(strengthMyProfileProvider)` 등.

---

## Migration from `big3_competition`

1. `strength_competition` domain/data/application 구현
2. `big3_competition_repository_impl.dart` → `StrengthCompetitionRepositoryImpl` 위임 shim
3. `big3_competition` models → `export` 또는 typedef alias (`CompetitionProfile` = deprecated)
4. UI `big3_competition_screen` → import 경로만 변경
5. 테스트 이전 후 `big3_*` 파일 삭제

---

## Test Strategy

### 1. Model unit tests (`test/features/strength_competition/models/`)

- **Happy path:** fixture JSON → `fromJson` → 필드 assert
- **Missing optional:** `profile: null`, partial records
- **Legacy keys:** `opted_in` fallback on profile
- **Privacy:** JSON with `subject` key does not appear on model
- **Invalid payload:** missing `display_alias` → `FormatException`
- **Enum mapping:** unknown `lift_type` → `FormatException` or safe throw

Fixtures: `test/fixtures/strength_competition/*.json` (backend `strength_competition_schema.py` 기준)

### 2. Repository tests (`strength_competition_repository_impl_test.dart`)

- **Fake `ApiClient`** or mock `http.Client` — 기존 프로젝트에 mock 패키지 없으면 **manual fake**:

```dart
class FakeApiClient implements ... // or inject closure-based test double
```

- Verify correct path/method/body per method
- Verify mapper: `records` vs legacy `bests` key fallback
- `ServerException` propagates unchanged

### 3. Service tests (`strength_competition_service_test.dart`)

- `_FakeStrengthRepository` (pattern from existing `big3_competition_service_test.dart`)
- Client-side validation: invalid lift, reps > 12, weight ≤ 0
- Does not call repository when validation fails

### 4. Provider tests (optional)

- `ProviderContainer` + override `strengthCompetitionRepositoryProvider`
- Smoke: provider resolves without throw

### 5. Integration / manual

- 실제 서버 + JWT: profile opt-in → submit → records → leaderboard
- Not required in CI for MVP

### Test commands

```bash
flutter test test/features/strength_competition/
flutter test test/features/big3_competition/  # shim 유지 기간
```

---

## Error Handling Convention

| Origin | Type | UI handling |
|--------|------|-------------|
| Network | `NetworkException` | retry snackbar |
| Timeout | `ApiTimeoutException` | retry |
| 5xx | `ServerException` | generic message |
| 409 | `ServerException(409)` | alias conflict copy (after enhancement) |
| Parse | `FormatException` / `ParseException` | dev log + generic |
| Validation | `ArgumentError` | inline form error |

Repository **does not** catch `AppException` — service/presentation maps to user copy.

---

## Definition of Done

- [ ] All domain models with `fromJson` + tests
- [ ] `StrengthCompetitionRepositoryImpl` 7 endpoints wired
- [ ] `StrengthCompetitionService` client validation tests
- [ ] Riverpod providers registered
- [ ] `big3_competition` delegates to strength (shim) OR UI migrated
- [ ] No `subject` in any Dart model
