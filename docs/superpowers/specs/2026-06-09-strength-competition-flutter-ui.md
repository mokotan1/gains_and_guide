# Flutter Strength Competition — Screen & UI Design

## Design principles

| 원칙 | UI 반영 |
|------|---------|
| 실용·훈련 앱 톤 | 카드·숫자 중심, 배지/레벨/효과음 없음 |
| 성장 > 경쟁 | 카피: "시즌 최고", "이전보다", "기록 추가" |
| 부상 유도 금지 | "한계 돌파", "무조건 올리기", "실패하면…" 금지 |
| 프라이버시 | 닉네임·체급·경력 구간만 노출; 이메일/ID 없음 |

**톤 레퍼런스:** Strava 시즌 요약 / Hevy PR 화면 — 정보 밀도 높고 차분함.

---

## Information architecture

```
신체 프로필
  └─ 시즌 3대 기록 (ListTile)  ← 기존 "3대 경쟁" 문구 완화
       └─ StrengthCompetitionScreen (hub)
            ├─ [탭] 내 시즌
            ├─ [탭] 순위표
            ├─ FAB / 버튼 → StrengthRecordSubmitSheet (bottom sheet)
            └─ AppBar ⚙ → StrengthProfileSettingsScreen
```

**제출 UX 권장:** full screen 대신 **bottom sheet** — 탭 컨텍스트 유지, 한 종목 집중 입력.

---

## 1. StrengthCompetitionScreen

### Layout (2-tab hub)

```
┌ AppBar: "시즌 3대 기록"          [⚙ 설정] ┐
├ TabBar:  [ 내 시즌 ] [ 순위표 ]              │
├──────────────────────────────────────────────┤
│ TabBarView                                   │
│   Tab1: CustomScrollView + RefreshIndicator  │
│   Tab2: Column( filters, list, sticky rank ) │
└──────────────────────────────────────────────┘
         [ + 기록 추가 ]  ← opted-in 시만 (FAB 또는 하단 고정 버튼)
```

### Tab 1 — 내 시즌 (성장 중심)

**스크롤 순서 (위→아래):**

1. `StrengthSeasonHeader` — 시즌명·기간
2. `StrengthOptInBanner` — 미참가 시만 (접을 수 있는 안내)
3. `StrengthSeasonScoreCard` — 시즌 합산·완성도
4. `StrengthLiftPrRow` — 스쿼트/벤치/데드 3카드 (가로 스크롤 또는 세로 스택)
5. `StrengthMyRankChip` — 순위 요약 (참가·노출 시)
6. `StrengthRecentEntriesList` — 최근 제출 3건 (optional, 접기)

**미참가:** 3~6 숨기고 Opt-in 배너 + "어떻게 동작하나요?" 링크.

### Tab 2 — 순위표 (비교는 보조)

```
┌ StrengthLeaderboardFilters ─────────────┐
│ Segmented: [ 합산(kg) | 체중 대비 ]      │
│ Chips:     [ 전체 | 체급 | 경력 ]        │  ← 경력 MVP: disabled + tooltip
├─────────────────────────────────────────┤
│ Expanded: StrengthLeaderboardList       │
├─────────────────────────────────────────┤
│ StrengthMyRankBar (sticky bottom)       │
└─────────────────────────────────────────┘
```

---

## 2. StrengthRecordSubmitSheet (bottom sheet)

**트리거:** FAB "기록 추가" 또는 lift 카드의 "기록 추가" (종목 pre-selected).

```
┌ Handle ─────────────────────────────────┐
│ 제목: "백 스쿼트 기록 추가"               │
│ 부제: "오늘 세션에서 수행한 세트 기준"     │
├─────────────────────────────────────────┤
│ SegmentedButton: [스쿼트][벤치][데드]     │  ← pre-select 시 해당 항목 고정 가능
│ TextField: 무게 (kg)                     │
│ TextField: 반복 (회)                     │
│ Text: "추정 1RM은 앱이 자동 계산합니다"    │
├─────────────────────────────────────────┤
│ [ 취소 ]              [ 저장 ]          │
└─────────────────────────────────────────┘
```

- `isScrollControlled: true`, 키보드 시 `viewInsets` padding
- 저장 성공 → sheet 닫기 + notifier `refreshMyData`

**Full screen (`StrengthRecordSubmitScreen`)** — 태블릿/딥링크용으로만 optional; 모바일 기본은 sheet.

---

## 3. StrengthProfileSettingsScreen

```
┌ AppBar: "시즌 기록 설정" ────────────────┐
│ StrengthPrivacyNoticeCard               │
│ ListTile: 공개 닉네임 → TextField       │
│ ListTile: 체중 (kg) → 숫자 입력          │  ratio 순위용, 비공개 안내
│ ListTile: 경력 구간 → Dropdown (MVP UI)  │  로컬만, 서버 미연동 시 "표시용"
│ Switch: 시즌 기록 참가                    │
│ Switch: 순위표에 표시                     │  참가 on일 때만
│ OutlinedButton: 참가 철회                 │
└─────────────────────────────────────────┘
```

---

## Widget decomposition

```
presentation/
├── screens/
│   ├── strength_competition_screen.dart
│   ├── strength_profile_settings_screen.dart
│   └── strength_record_submit_sheet.dart
└── widgets/
    ├── strength_season_header.dart
    ├── strength_opt_in_banner.dart
    ├── strength_season_score_card.dart
    ├── strength_lift_pr_card.dart
    ├── strength_lift_pr_row.dart
    ├── strength_my_rank_chip.dart          # Tab1 compact
    ├── strength_my_rank_bar.dart           # Tab2 sticky
    ├── strength_leaderboard_filters.dart
    ├── strength_leaderboard_list.dart
    ├── strength_leaderboard_tile.dart
    ├── strength_recent_entries_list.dart
    ├── strength_privacy_notice_card.dart
    ├── strength_empty_state.dart
    ├── strength_error_panel.dart
    └── strength_metric_label.dart          # kg / ratio 포맷
```

### Widget spec summary

| Widget | 입력 | 출력/동작 |
|--------|------|-----------|
| `StrengthSeasonHeader` | `StrengthSeason` | 시즌명, `1월 1일 – 6월 30일` |
| `StrengthOptInBanner` | `onJoin`, `loading` | 참가 CTA, 프라이버시 2줄 |
| `StrengthSeasonScoreCard` | `StrengthSeasonRecords`, `metric` | 큰 숫자 1개 + 3종목 완성도 ring/text |
| `StrengthLiftPrCard` | liftType, `1rm?`, `onAdd` | 종목명, PR 또는 "—", 추가 버튼 |
| `StrengthLeaderboardFilters` | metric, division, callbacks | Segmented + FilterChips |
| `StrengthLeaderboardTile` | `StrengthLeaderboardEntry` | rank, alias, S/B/D 한 줄, trailing score |
| `StrengthMyRankBar` | `StrengthRankSummary` | 고정 하단: "내 순위 12위 / 84명" 또는 reason |
| `StrengthRecordSubmitSheet` | liftType?, notifier | 폼 + validation |

---

## Visual spec (AppTheme 정합)

| 요소 | 스펙 |
|------|------|
| 배경 | `AppTheme.backgroundGray` |
| 카드 | `CardTheme` 16px radius, elevation 2 |
| 강조색 | `primaryBlue` — 합산 숫자·선택 탭만 |
| 순위 1~3 | 금/은/동 **아이콘 없음** — 숫자만 약간 굵게 |
| FAB | `FilledButton.icon` 또는 작은 FAB, 트로피 아이콘 대신 `add_chart_outlined` |
| 타이포 | PR: `titleLarge` 숫자 + `bodySmall` "추정 1RM (Epley)" |

### StrengthSeasonScoreCard 와이어

```
┌─────────────────────────────────────┐
│ 2026 상반기 · 시즌 합산              │
│                                     │
│        382.5 kg                     │  ← total 모드
│   또는   4.82  (체중 대비)           │  ← ratio 모드 (체중 있을 때)
│                                     │
│  스쿼트 142 · 벤치 102 · 데드 138.5  │  ← 보조 한 줄
│  ●●● 3/3 종목 기록 완료              │  ← 완성도 (게이지 아님, 텍스트 점) │
└─────────────────────────────────────┘
```

### StrengthLiftPrCard 와이어

```
┌──────────────────┐
│ 백 스쿼트         │
│ 142.0 kg         │
│ 추정 1RM         │
│ [ 기록 추가 ]     │
└──────────────────┘
```

---

## UX copy examples

### 네비·탭

| 위치 | 문구 |
|------|------|
| 프로필 진입 | **시즌 3대 기록** / "스쿼트·벤치·데드 시즌별 최고 기록" |
| AppBar | **시즌 3대 기록** |
| Tab | **내 시즌** / **순위표** |
| FAB | **기록 추가** |

### Opt-in / 프라이버시

| 상황 | 문구 |
|------|------|
| 배너 제목 | **이번 시즌 기록을 남기려면 참가가 필요해요** |
| 배너 본문 | 순위표에는 **닉네임만** 표시됩니다. 이메일과 계정 ID는 공개되지 않습니다. |
| CTA | **시즌 참가하기** |
| 설정 상단 | **공개 정보는 닉네임·체급·경력 구간으로만 표시됩니다.** |
| 순위표 스위치 | **순위표에 표시** / 끄면 기록은 유지되고 이름만 숨깁니다. |
| 닉네임 힌트 | 2~24자, 한글·영문·숫자 (예: **리프터-서울**) |

### 성장·기록 (경쟁 톤 지양)

| 상황 | 문구 |
|------|------|
| PR 있음 | **시즌 최고 추정 1RM** |
| PR 없음 | **아직 이번 시즌 기록이 없어요** |
| 합산 | **시즌 합산 (3종목)** |
| 제출 성공 | **기록이 저장되었어요. 시즌 최고가 갱신되면 자동 반영됩니다.** |
| 3종목 미완 | **벤치·데드 기록을 추가하면 합산 순위에 포함됩니다.** |

### 순위표

| 상황 | 문구 |
|------|------|
| Segmented | **합산 (kg)** / **체중 대비** |
| Filter chips | **전체** / **체급** / **경력** |
| 경력 disabled | **경력 구간 순위는 준비 중이에요** |
| 빈 목록 | **아직 합산 순위에 표시할 참가자가 없어요** |
| 내 순위 (ranked) | **내 순위 12위** · 전체 84명 |
| hidden | **순위표에서 숨김 상태예요. 설정에서 다시 켤 수 있어요.** |
| incomplete | **3종목 기록이 모두 있어야 순위가 표시됩니다.** |
| no bodyweight | **체중을 입력하면 체중 대비 순위를 볼 수 있어요.** |

### 피해야 할 문구

- ❌ "한계에 도전", "경쟁에서 이기기", "무조건 갱신", "실패"
- ❌ "주간 10% 규칙"을 사용자에게 압박하는 표현
- ❌ "부상 주의"를 공포 마케팅처럼 강조

**서버 거부(급증) 시 중립 메시지:**  
"이전 기록 대비 변화가 커서 저장되지 않았어요. 무게와 반복을 다시 확인해 주세요."

### 에러

| 상황 | 문구 |
|------|------|
| 네트워크 | 네트워크 연결을 확인해 주세요. |
| 시즌 없음 | **진행 중인 시즌이 없어요.** 다음 시즌을 기다려 주세요. |
| 409 별칭 | **이미 사용 중인 닉네임이에요.** |

---

## Accessibility & mobile layout

### 접근성

| 항목 | 가이드 |
|------|--------|
| 터치 타깃 | 버튼·Chip·Switch 최소 **48×48** dp |
| Semantics | PR 카드: `label: "백 스쿼트 시즌 최고 142킬로그램 추정 원RM"` |
| Segmented control | `ButtonSegment`에 `tooltip` + 선택 상태 `announce` |
| 순위 고정 바 | `Semantics(container: true, label: "내 순위 12위, 전체 84명")` |
| 색만으로 상태 구분 금지 | 완성도 `3/3 종목` **텍스트** 병행 |
| Dynamic type | `titleLarge` PR 숫자 `FittedBox` 또는 `maxLines: 1` + scale clamp |
| 스크린 리더 | 리더보드 타일: rank → alias → score 순 읽기 |

### 모바일 레이아웃

| 항목 | 가이드 |
|------|--------|
| Safe area | Tab2 하단 `StrengthMyRankBar` + `SafeArea` |
| 키보드 | Submit sheet: `Padding(viewInsets.bottom)` |
| 가로 모드 | Lift PR row → 가로 `ListView` 3카드 스냅 |
| 좁은 화면 (320dp) | 리더보드 tile: S/B/D를 두 줄로 wrap |
| Pull-to-refresh | Tab1·Tab2 모두 `RefreshIndicator` → `refreshAll` / `refreshLeaderboard` |
| 로딩 | 전체 화면 스피너 대신 **카드 스켈레톤** (shimmer optional) |
| Bottom sheet | `maxHeight: 90%` of screen; 드래그 dismiss |

### 상태별 화면

| 상태 | UI |
|------|-----|
| `isBootstrapping` | Tab1 스켈레톤 |
| `!hasSeason` | `StrengthEmptyState` 전체 |
| `!optedIn` | Opt-in 배너 + 설명만 |
| `isLeaderboardLoading` | 리스트 상단 `LinearProgressIndicator` |
| `leaderboardError` | 리스트 영역만 `StrengthErrorPanel` + 재시도 |

---

## Notifier 연동 (화면 → 액션)

| UI 이벤트 | Notifier |
|-----------|----------|
| Pull refresh | `refreshAll()` |
| Tab2 진입 | `refreshLeaderboard()` |
| Segmented 변경 | `setSelectedMetric` |
| Chip 변경 | `setSelectedDivision` |
| FAB / 기록 추가 | sheet → `submitLift` |
| Opt-in 배너 | `optIn` |
| 설정 저장 | `updateProfile` / `setLeaderboardOptIn` |

---

## Entry point 업데이트 (body_profile_screen)

```dart
title: '시즌 3대 기록',
subtitle: '시즌별 최고 기록과 순위표 (선택 참가)',
// icon: Icons.timeline_outlined  (emoji_events 대신)
```
