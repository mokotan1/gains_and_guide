# Gains & Guide — 전체 코드 리뷰 및 리팩터링 브리핑

## 1. 전체 코드 리뷰

### 1.1 프로젝트 개요

- **앱**: 웨이트 트레이닝 루틴 관리 + AI 코치 (Stronglifts 5x5, 주간 프로그램, 운동 기록·증량).
- **스택**: Flutter(Dart), Riverpod, SQLite(sqflite), SharedPreferences, 외부 AI API.

### 1.2 아키텍처 구조 (리팩터링 후)

```
lib/
├── main.dart                    # 앱 진입, DB 부트스트랩, ProviderScope
├── core/
│   ├── bootstrap/               # 앱 기동 시 1회 실행 (DB 시딩)
│   ├── constants/               # 도메인 상수 (매직 넘버/문자열 제거)
│   ├── database/                # SQLite 래퍼 (구체 구현)
│   ├── domain/repositories/     # 저장소 추상화 (인터페이스)
│   ├── data/                    # 저장소 구현체 (DB 의존)
│   ├── providers/               # Riverpod DI (저장소·서비스 주입)
│   ├── theme/
│   ├── workout_provider.dart    # 운동 세션 상태 (StateNotifier)
│   └── chat_provider.dart
└── features/
    ├── routine/                 # 루틴·운동 도메인
    │   ├── domain/              # Entity, Repository 인터페이스
    │   ├── data/                 # RoutineRepository 구현
    │   └── application/          # WorkoutService (유스케이스)
    ├── home/                     # 홈·프로필 UI
    ├── ai_coach/                 # AI 채팅·추천 UI
    └── ...
```

- **도메인**: `Exercise`, `Routine`, `ExerciseCatalog` — 비즈니스 개념만 보유.
- **애플리케이션**: `WorkoutService` — 세션/주간 프로그램 로드·저장, 증량·히스토리 위임.
- **인프라**: `DatabaseHelper` + Repository 구현체 — DB/SharedPreferences 접근만 담당.
- **프레젠테이션**: 화면 + Riverpod Provider — UI 이벤트와 상태만 다루고, 데이터는 Repository/Service 통해 접근.

### 1.3 설계상 강점

| 항목 | 내용 |
|------|------|
| **의존성 역전(DIP)** | UI·Notifier는 `WorkoutHistoryRepository` 등 **추상**에만 의존. 구현은 `core/data/`에서 주입. |
| **단일 책임** | `DatabaseBootstrap`은 시딩만, `WorkoutConstants`는 상수만, Repository는 CRUD/쿼리만. |
| **상수 추출** | RPE·증량·Stronglifts 메인/보조 구분이 `WorkoutConstants`로 한곳에 모여 유지보수·테스트에 유리. |
| **방어적 파싱** | `Exercise.fromJson`에서 필수 필드·타입 검증 후 `ExerciseParseException`으로 실패를 도메인 레벨에서 처리. |

### 1.4 개선 여지 (리뷰 포인트)

| 항목 | 현재 | 제안 |
|------|------|------|
| **테스트** | 단위 테스트 없음 | `_getSmartStrongliftsRoutine`, 증량 규칙, `Exercise.fromJson` 등에 Unit Test + Mock Repository 도입 |
| **도메인/영속 분리** | `Exercise`가 세션·DB 공용 | 장기적으로 Persistence DTO ↔ Domain Entity 분리 시 마이그레이션·버전 관리 용이 |
| **에러 타입** | AI/네트워크 실패가 문자열 메시지 위주 | `AiServiceUnavailable` 등 도메인 예외로 승격 후 UI에서만 메시지 매핑 |
| **설정** | AI URL·user_id 하드코딩 | 환경별 설정(flavor / .env)으로 분리 |

---

## 2. 왜 이렇게 짰는지 (설계 결정 이유)

### 2.1 레이어 분리 (Feature + Core)

- **Feature 단위**: `routine`, `home`, `ai_coach` 등으로 나누어 “어디를 수정할지”를 쉽게 찾을 수 있게 함.
- **Core 공유**: 운동 기록·증량·프로필·카탈로그는 여러 feature에서 쓰이므로 `core/domain`, `core/data`, `core/providers`에 두어 중복을 막고 일관된 접근 방식 유지.

### 2.2 Repository 추상화 (인터페이스 + 구현체)

- **이유**: UI·`WorkoutNotifier`가 `DatabaseHelper`에 직접 의존하면 테스트 시 DB를 Mock으로 바꾸기 어렵고, DB 스키마 변경 시 화면/비즈니스 로직까지 수정해야 함.
- **선택**: `WorkoutHistoryRepository`, `ProgressionRepository`, `BodyProfileRepository`, `ExerciseCatalogRepository`를 **abstract class**로 두고, 구현체만 `DatabaseHelper`를 사용. 고수준(서비스·Notifier)은 “저장소 계약”만 알도록 함.

### 2.3 WorkoutService가 세션 + 주간 + 기록을 중개

- **이유**: SharedPreferences(세션·마지막 날짜)·DB(히스토리·증량)를 한 곳에서 조합해야 “오늘 루틴 복원”과 “다음 날 A/B 결정”이 일관되게 동작.
- **선택**: `WorkoutService`가 `RoutineRepository`, `WorkoutHistoryRepository`, `ProgressionRepository`를 받아서 로드/저장을 위임. `WorkoutNotifier`는 `WorkoutService`만 호출하고 DB를 직접 보지 않음.

### 2.4 Stronglifts A/B + 보조 운동

- **요구**: “직전에 한 운동”을 보고 오늘은 A인지 B인지 정하고, **그날 루틴에 있던 보조 운동은 그대로 유지**.
- **선택**:
  - A/B 구분은 “직전 운동일”의 운동 이름 집합으로 판단 (`strongliftsRoutineAKeys` / `strongliftsRoutineBKeys`).
  - “메인”만 A/B 템플릿으로 교체하고, 나머지는 `_mergeWithAccessories(mainRoutine, dayRoutine, mainNames)`로 그날 루틴에서 필터해 이어붙임.

### 2.5 날짜 정규화 (`_normalizeDateString`)

- **이유**: DB·플랫폼에 따라 `"2025-03-12"` vs `"2025-03-12 00:00:00"` 등 형식이 달라지면 “같은 날” 비교가 깨질 수 있음.
- **선택**: 모든 날짜 비교를 **YYYY-MM-DD** 한 형식으로 맞춰서 “마지막 운동일” 추출과 필터링을 안정화.

### 2.6 “기록만 저장하고 종료” 버튼

- **이유**: AI 정산을 하지 않고 앱만 닫으면 `workout_history`에 기록이 안 쌓여, 다음 날 A/B 판단이 이전 날짜 기준으로만 동작함.
- **선택**: “기록만 저장하고 종료”에서 `saveCurrentWorkoutToHistory()` + `finishWorkout()`을 호출해, AI 없이도 오늘 운동이 히스토리에 남고 다음 날 루틴이 올바르게 바뀌도록 함.

---

## 3. 왜 이런 식으로 리팩터링 했는지

### 3.1 목표

- **유지보수성**: 변경이 한 레이어에 묶이도록 하고, 테스트·추가 기능을 쉽게 하기 위함.
- **안정성**: 입력·저장 데이터 검증과 날짜/이름 처리 일관성 확보.
- **도메인 규칙 명확화**: Stronglifts A/B, 증량, RPE 기준을 상수와 서비스/Notifier 로직으로 분리.

### 3.2 리팩터링 단계별 이유

| 단계 | 전 | 후 | 이유 |
|------|----|----|------|
| **Repository 도입** | UI·Notifier가 `DatabaseHelper.instance` 직접 호출 | Repository 인터페이스 + 구현체, Provider로 주입 | DIP·테스트 용이성·DB 변경 격리 |
| **상수 추출** | 5.0, 2.5, 3, 8, 운동 이름이 코드 곳곳에 산재 | `WorkoutConstants` 한곳에 정의 | 의미 부여·변경 지점 단일화 |
| **main 시딩 분리** | `main()` 안에 JSON 파싱·시딩 로직 | `DatabaseBootstrap.run()`으로 분리 | 단일 책임·에러 처리·재사용 가능 |
| **Exercise.fromJson 검증** | `json['name']` 등 직접 접근 시 런타임 오류 가능 | 필수 필드·타입 검사 + `ExerciseParseException` | 방어적 코딩·안전한 실패 |
| **Stronglifts 날짜/보조** | 날짜 비교·보조 운동 유지 없음/불명확 | `_normalizeDateString` + `_mergeWithAccessories` | A/B 판단 정확도·사용자 루틴(메인+보조) 유지 |
| **Cursor Rule** | 없음 | `.cursor/rules/dart-clean-architecture.mdc` | AI·팀이 DIP·상수·검증 규칙을 일관되게 따르도록 유도 |

### 3.3 하지 않은 것과 이유

- **도메인 모델과 DTO 완전 분리**: 현재 규모에서는 `Exercise` 하나로 세션·직렬화를 같이 써도 충분하고, 과도한 레이어는 복잡도만 올릴 수 있어 당단 적용하지 않음.
- **Repository를 feature별로만 분리**: 운동 기록·증량·카탈로그·프로필은 여러 feature에서 공유하므로 core에 두고, routine 전용은 `RoutineRepository`만 feature에 둠.

---

## 4. 사용한 알고리즘·개념 정리

### 4.1 자료 구조·연산

| 개념 | 사용처 | 설명 |
|------|--------|------|
| **해시/집합(Set)** | `_getSmartStrongliftsRoutine`의 `lastExercises` | 직전 운동일의 운동 이름을 중복 없이 모아, A/B 판별 시 O(1) 포함 여부 확인. |
| **필터 + 매핑** | `lastExercises` 생성, `_mergeWithAccessories` | `where`로 “그날” / “메인이 아닌 운동”만 걸러서 리스트/집합으로 만듦. |
| **정렬 가정** | `getAllHistory()` → `orderBy: 'date DESC'` | “가장 최근 날짜”를 `history.first` 한 번에 가져오기 위해 정렬된 순서에 의존 (정렬은 DB가 수행). |

### 4.2 상태 머신·플로우

| 개념 | 사용처 | 설명 |
|------|--------|------|
| **세션 vs 날짜** | `_loadAllData()` | `lastSavedDate == today`이면 세션 복원, 아니면 “새 날”로 보고 `updateRoutineByDay()` 호출 후 `updateLastDate(today)` — 날짜 기준 상태 전이. |
| **A/B 교대** | `_getSmartStrongliftsRoutine` | 직전 운동에 A 키(플랫 벤치) 있으면 → 오늘 B, B 키(OHP) 있으면 → 오늘 A. 이전 상태(직전 루틴)에 따른 다음 상태(오늘 루틴) 결정. |

### 4.3 증량 규칙 (조건부 업데이트)

- **입력**: 운동별 완료 세트, RPE.
- **규칙**:  
  - “완료 세트 수 ≥ 목표 세트 수”이고, **모든 완료 세트 RPE < 3** → +5kg  
  - 그렇지 않고 **모든 완료 세트 RPE < 8** → +2.5kg  
  - 그 외 → 유지  
- **구현**: `saveCurrentWorkoutToHistory()` 안에서 `countBelow3`, `countBelow8`, `ex.sets` 비교 후 `saveProgression()` 호출.  
- **개념**: **임계값 기반 분기(threshold-based decision)** + **상태 누적(progression_history)**.

### 4.4 날짜 정규화 (문자열 전처리)

- **목적**: 다양한 날짜 문자열을 “YYYY-MM-DD”로 통일해 비교.
- **방법**: `split(' ').first`로 날짜 부분만 취한 뒤, 길이 10이면 `substring(0, 10)`으로 자르기.  
- **개념**: **정규화(normalization)** 로 비교 연산을 안정화.

### 4.5 합치기(merge) 전략

- **목적**: 메인 루틴(A 또는 B 3종) + 그날 설정된 보조 운동을 하나의 리스트로.
- **방법**: 메인 리스트 + `dayRoutine`에서 “메인 이름에 없는” 항목만 필터한 리스트를 이어붙임 (`[...mainRoutine, ...accessories]`).  
- **개념**: **템플릿 + 오버레이**: 고정 메인 + 사용자 정의 보조를 합성.

---

## 5. 요약

- **아키텍처**: 레이어 분리(도메인/애플리케이션/인프라/프레젠테이션) + DIP(Repository 추상화) + Riverpod DI로 “왜 이렇게 짰는지”가 드러나도록 구성.
- **리팩터링**: “직접 의존 제거 → 상수·시딩·검증 분리 → Stronglifts/날짜/보조 로직 명확화” 순으로 진행해, 동작은 유지하면서 유지보수·테스트·확장을 쉽게 함.
- **알고리즘·개념**: Set 기반 A/B 판별, 날짜 정규화, 임계값 기반 증량, 메인+보조 merge 등으로 “다음 루틴 결정”과 “기록 저장·증량”을 명시적으로 구현함.

이 문서는 푸시된 코드 기준으로 작성되었으며, 이후 변경 시 이 브리핑을 함께 갱신하는 것을 권장합니다.
