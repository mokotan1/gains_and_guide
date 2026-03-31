# HealthKit / Health Connect 설정

## iOS

1. Xcode에서 **Signing & Capabilities** → **+ Capability** → **HealthKit** 추가.
2. 읽기 범위는 앱에서 요청하는 타입(운동, 심박)에 맞게 선택.
3. [`ios/Runner/Info.plist`](../ios/Runner/Info.plist)의 `NSHealthShareUsageDescription` / `NSHealthUpdateUsageDescription` 문구가 사용자에게 표시된다.

## Android

1. 기기에 **Health Connect** 앱이 설치되어 있어야 한다.
2. [`AndroidManifest.xml`](../android/app/src/main/AndroidManifest.xml)에 Health Connect 권한 및 `com.google.android.apps.healthdata` 패키지 `queries`가 선언되어 있다.
3. 권한 부여 후 **30일 이전** 데이터가 필요하면 `READ_HEALTH_DATA_HISTORY` 권한과 `requestHealthDataHistoryAuthorization()` 호출이 필요하다(현재 앱은 기본 7일 lookback).

## Supabase cardio 동기화

- `--dart-define=SUPABASE_URL=...` 및 `SUPABASE_ANON_KEY=...` 가 있으면 `main`에서 Supabase를 초기화한다.
- `cardio_history` RLS는 `auth.uid()::text = user_id` 이므로 **Supabase Auth 로그인 세션**이 있을 때만 원격 반영이 된다. 세션이 없으면 로컬 SQLite 동기화만 수행된다.

## 수동 QA 체크리스트

- [ ] 프로필 → 건강 앱에서 유산소 동기화: 세션 수·스낵바 메시지.
- [ ] 앱을 백그라운드로 보냈다가 복귀: 약 90초 이내 자동 동기화(디바운스) 동작.
- [ ] 출생연도 저장 후 주간 레포트 AI 컨텍스트에 `220-나이` 참고 문구 포함 여부.
- [ ] Supabase URL/키 + Auth 연동 시 원격 `cardio_history` 행 생성 여부.
