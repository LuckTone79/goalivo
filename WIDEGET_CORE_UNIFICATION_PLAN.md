# wideget-core 통합 설계안 (4-App Unification Plan)

> 기준: 기존 **Goalivo** Supabase project 를 그대로 사용하고, 대시보드 표시 이름만 **wideget-core** 로 사람이 변경.
> 대상 앱: Goalivo, castfolio, kadit, locawing. 제외: qkiki, one-more-rep(독립 유지).

## 1. 최종 아키텍처

```
Supabase Project: wideget-core  (기존 Goalivo project = ref ossqwphalaxhmadmffsn)
│
├── auth        (Supabase 내부 · 직접 수정 금지 · FK 참조만)
│
├── public      (공통 레지스트리 · 앱 공유)
│   ├── apps                (앱 목록)
│   ├── app_memberships     (유저 ↔ 앱 소속)
│   ├── global_profiles     (앱 공통 프로필)
│   ├── user_state          (※ Goalivo 레거시 — 현행 유지, 점진 이관)
│   └── feedback_posts      (※ Goalivo 레거시 — 현행 유지, 점진 이관)
│
├── goalivo     (Goalivo 전용 데이터)
├── castfolio   (castfolio 전용 데이터)
├── kadit       (kadit 전용 데이터)
└── locawing    (locawing 전용 데이터)

포함하지 않음: qkiki, one_more_rep  ← 각각 독립 Supabase project 유지
```

## 2. 공통(public) 테이블 설계

이번 migration(`supabase/migrations/20260707120000_wideget_core_4app_unification.sql`)에서 생성:

### 2.1 `public.apps`
| 컬럼 | 타입 | 제약 |
|---|---|---|
| id | text | PK |
| name | text | not null |
| slug | text | unique not null |
| status | text | default `'active'` |
| created_at | timestamptz | default now() |

초기 seed: `goalivo/Goalivo`, `castfolio/Castfolio`, `kadit/Kadit`, `locawing/Locawing`.

### 2.2 `public.app_memberships`
| 컬럼 | 타입 | 제약 |
|---|---|---|
| app_id | text | FK → public.apps(id) |
| user_id | uuid | FK → auth.users(id) on delete cascade |
| role | text | default `'user'` |
| status | text | default `'active'` |
| created_at | timestamptz | default now() |
| PK | (app_id, user_id) | |

### 2.3 `public.global_profiles`
| 컬럼 | 타입 | 제약 |
|---|---|---|
| user_id | uuid | PK, FK → auth.users(id) on delete cascade |
| display_name | text | |
| avatar_url | text | |
| created_at | timestamptz | default now() |
| updated_at | timestamptz | default now() + trigger |

## 3. 앱별 테이블 → 스키마 매핑

### Goalivo (조사 완료)
| 현재 (public) | 통합 후 위치 | 이관 전략 |
|---|---|---|
| `public.user_state` | 단기: **현행 유지**(public). 장기: `goalivo.user_state` | 코드가 하드코딩 `from('user_state')` 이므로 즉시 이동 시 앱 중단 위험 → 무중단 이관은 별도(§6) |
| `public.feedback_posts` | 장기: `goalivo.feedback_posts` | 위와 동일. 우선 현행 유지 |

> **원칙:** 이번 릴리스는 공통 레지스트리(apps/memberships/profiles)만 추가하는 **비파괴·부가** 변경. 기존 `public.user_state`/`feedback_posts` 는 건드리지 않아 현재 배포가 그대로 동작한다. 스키마 이동은 view/동기화를 통한 무중단 절차(§6)로 후속 진행.

### castfolio / kadit / locawing (DB 실측 완료 · Supabase MCP)
- 규칙:
  - 사용자 소유 데이터: `<app>.<table>` + `user_id uuid references auth.users(id)` + RLS `auth.uid() = user_id`.
  - 앱 공유/참조 데이터: RLS 는 `public.app_memberships`(app_id) 기반 또는 읽기전용.

**castfolio** (`vrbawgqrhigtkyiengkm`, 21 tables, 기존 `castfolio` 스키마 존재, bucket `payment-proof`)
| 분류 | 테이블 → `castfolio.*` | RLS 기준 |
|---|---|---|
| user 소유 | battle_votes, box_messages, box_threads(created_by), claim_votes, claims, likes, notifications, score_history, season_results, sp_transactions, unlocks | `auth.uid() = user_id`(또는 created_by) |
| 앱 공유/참조 | backtest_results, battles, follows, seasons, signal_boxes, strategies, strategy_snapshots, users, verification_queue, weekly_events | membership 기반/공개읽기 (개별 판단) |

**kadit** (`chkjnszxisljiywjtqve`, 9 tables, 전부 `user_id`, bucket `kadit-images`)
| 분류 | 테이블 → `kadit.*` | RLS 기준 |
|---|---|---|
| user 소유(전부) | kadit_artifacts, kadit_generation_schedules, kadit_image_jobs, kadit_render_jobs, kadit_renders, kadit_scheduled_runs, kadit_source_feeds, kadit_source_items, kadit_versions | `auth.uid() = user_id` · `kadit_` 접두사 제거 검토 |

**locawing** (`nkizvcbesznhvwgskxhy`, 9 tables, buckets `scenario-exports`/`test-reports`)
| 분류 | 테이블 → `locawing.*` | RLS 기준 |
|---|---|---|
| user 소유 | devices, scenarios, schedules, test_reports, commands(user_id+device_id) | `auth.uid() = user_id` |
| device 스코프 | location_logs(device_id) | `device_id ∈ (auth.uid() 소유 devices)` |
| 유저 컬럼 없음 | blocks, profiles, scenario_points | `profiles.id = auth.uid()` 여부 확인 후 결정 |

> 각 앱 스키마 테이블 생성 migration 은 위 매핑을 근거로 `..._<app>_tables.sql` 로 작성한다(런북 §5). RLS 없는 사용자 데이터 테이블 생성 금지.

## 4. Auth 사용 분석

| 앱 | Auth | 비고 |
|---|---|---|
| Goalivo | ✅ Email + Google OAuth (SPA, 서버 콜백 없음) | redirect = origin+pathname |
| castfolio | 확인 필요 | |
| kadit | 확인 필요 | |
| locawing | 확인 필요 | |

- 통합 후 4개 앱은 **동일한 auth.users 풀**을 공유한다(같은 프로젝트).
- 앱 소속 구분은 `public.app_memberships.app_id` 로 한다.
- 권한 판단은 **절대 user_metadata 로 하지 않고** `app_memberships`/`auth.uid()` 로만 한다.

## 5. Storage 분석

| 앱 | Storage bucket | 비고 |
|---|---|---|
| Goalivo | ❌ 미사용 (이미지 base64 저장) | |
| castfolio | 확인 필요 | 미디어/포트폴리오 앱일 가능성 → bucket 사용 가능성 높음 |
| kadit | 확인 필요 | |
| locawing | 확인 필요 | |

- bucket 네이밍 표준: `<app_id>-<purpose>` (예: `castfolio-media`). 자세한 내용은 `STORAGE_MIGRATION_PLAN.md`.

## 6. user_state/feedback 무중단 스키마 이관(후속, 선택)

기존 `public.user_state` 를 `goalivo.user_state` 로 옮기고 싶을 때의 **비파괴** 절차:
1. `goalivo.user_state` 생성(동일 구조 + RLS `auth.uid()=user_id`).
2. 1회 백필 복사(insert … select).
3. `public.user_state` 를 `goalivo.user_state` 를 가리키는 updatable view 로 교체하거나, 코드에서 `.schema('goalivo').from('user_state')` 로 전환 배포.
4. 안정화 확인 후 레거시 정리(문서화된 별도 승인 하에서만).

> 본 릴리스에는 포함하지 않는다(파괴적/중단 위험). 실제 실행은 `WIDEGET_CORE_MANUAL_ACTIONS.md` 승인 절차를 따른다.

## 7. 제외 프로젝트

- **qkiki (=yapp)**: 독립 Supabase project 유지. wideget-core 에 스키마/redirect/코드 포함하지 않음.
- **one-more-rep**: 독립 Supabase project 유지. 동일.
- 상세: `EXCLUDED_PROJECTS.md`.
