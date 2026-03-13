# Gains & Guide — DDD 아키텍처

## 개요

도메인 주도 설계(Domain-Driven Design)에 맞춰 **바운디드 컨텍스트** 단위로 레이어를 나눕니다.

- **Domain**: 엔티티, 값 객체, 리포지토리 **인터페이스** (의존성 없음)
- **Application**: 유스케이스/애플리케이션 서비스 (도메인 + 인프라 인터페이스만 사용)
- **Infrastructure**: 리포지토리 구현체, DB, API (도메인/애플리케이션에 의존)
- **Presentation**: UI, Riverpod Provider (애플리케이션 레이어에만 의존)

의존 방향: **Presentation → Application → Domain ← Infrastructure**

---

## 바운디드 컨텍스트

| 컨텍스트 | 역할 | 도메인 엔티티 |
|----------|------|----------------|
| **workout** | 오늘 운동 세션, 세트/반복/무게/RPE, 기록 저장 | Exercise |
| **routine** | 주간 프로그램, 루틴 CRUD | Routine |
| **body_profile** | 체중, 골격근량 등 | BodyProfile |
| **exercise_catalog** | 운동 목록 검색/시딩 | ExerciseCatalog |
| **ai_coach** | AI 채팅, 루틴 추천 (다른 컨텍스트 조합) | — |

---

## 폴더 구조

```
lib/
├── main.dart
├── core/                        # 공유
│   ├── database/                # DB 연결·스키마 (인프라 공통)
│   │   └── database_helper.dart
│   └── theme/
│       └── app_theme.dart
│
├── features/
│   ├── workout/                 # 운동 세션 + 기록
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── exercise.dart
│   │   │   └── repositories/
│   │   │       ├── workout_history_repository.dart   # abstract
│   │   │       └── workout_session_repository.dart   # abstract (주간 프로그램·현재 세션)
│   │   ├── application/
│   │   │   ├── workout_service.dart
│   │   │   └── providers.dart
│   │   ├── infrastructure/
│   │   │   ├── workout_history_repository_impl.dart
│   │   │   └── workout_session_repository_impl.dart
│   │   └── presentation/
│   │       └── (home_screen 등은 공통 하단 네비에 있으므로 유지)
│   │
│   ├── routine/
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── routine.dart
│   │   │   └── repositories/
│   │   │       └── routine_repository.dart           # abstract
│   │   ├── application/
│   │   ├── infrastructure/
│   │   │   └── routine_repository_impl.dart
│   │   └── presentation/
│   │
│   ├── body_profile/
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── body_profile.dart
│   │   │   └── repositories/
│   │   │       └── body_profile_repository.dart     # abstract
│   │   ├── application/
│   │   ├── infrastructure/
│   │   └── presentation/
│   │
│   ├── exercise_catalog/
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── exercise_catalog.dart
│   │   │   └── repositories/
│   │   │       └── exercise_catalog_repository.dart # abstract
│   │   ├── application/
│   │   ├── infrastructure/
│   │   └── (presentation은 routine/workout에서 사용)
│   │
│   └── ai_coach/
│       ├── application/
│       │   └── ai_coach_service.dart
│       └── presentation/
│           └── ai_coach_screen.dart
│
└── shared/                      # 여러 feature에서 쓰는 Provider 등 (선택)
    └── providers/
        └── workout_provider.dart
```

---

## 레이어 규칙

1. **Domain**: Flutter/SQLite/HTTP 등 외부 패키지 import 금지. 순수 Dart + 엔티티·인터페이스만.
2. **Application**: Domain 인터페이스와 Riverpod만 사용. UI 위젯/DB 직접 접근 금지.
3. **Infrastructure**: `DatabaseHelper` 또는 직접 DB/API 호출. Domain 엔티티를 반환.
4. **Presentation**: Application(Provider, Service)만 참조. Domain 엔티티는 Application을 통해 접근.

---

## 마이그레이션 순서

1. Domain 레이어: 엔티티 이동, 리포지토리 **인터페이스** 정의
2. Infrastructure: 기존 DB/SharedPrefs 로직을 리포지토리 **구현체**로 이동
3. Application: Service/UseCase가 인터페이스에만 의존하도록 수정, Provider에서 impl 주입
4. Presentation: import 경로만 수정 (가능하면 Application/Provider만 참조)
5. Core: `DatabaseHelper`는 그대로 두고, 필요한 테이블(routine 등)만 보강
