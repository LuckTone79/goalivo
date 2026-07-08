# SUPABASE 4-App Inventory (wideget-core 통합 대상)

> 작성일: 2026-07-07 · 갱신: 2026-07-08 (Supabase MCP 로 4개 앱 DB 실측 반영)
> 기준 프로젝트: 기존 **Goalivo** Supabase project → **wideget-core** 로 표시 이름 변경 **완료**.

## 0. 범위 / 조사 경로

- 이 세션 workspace 에는 **`goalivo` 저장소 하나만** 존재합니다(코드/ENV/콜백 라우트는 Goalivo 만 직접 확인 가능).
- 단, **Supabase MCP** 로는 조직 내 모든 프로젝트 DB 에 접근되어, castfolio/kadit/locawing 의 **DB 구조(테이블/컬럼/스토리지/유저수)는 실측 완료**했습니다.
- 따라서 아래 표기 기준:
  - **DB 구조** = 실측 완료(MCP)
  - **앱 코드 / ENV 변수명 / auth callback 라우트** = 저장소 미포함 → `확인 필요`
- `qkiki`(=yapp), `one-more-rep` 은 통합 제외이며 **DB 도 조회하지 않았습니다**(건드리지 않음). `EXCLUDED_PROJECTS.md` 참고.

## 프로젝트 ref 맵 (조직 `xnstgtymyoiqyhxrudtm`)

| 앱 | project ref | region | auth users | 통합 |
|---|---|---|---|---|
| **wideget-core** (구 Goalivo) | `ossqwphalaxhmadmffsn` | ap-south-1 | (기존) | 통합 메인 |
| castfolio | `vrbawgqrhigtkyiengkm` | ap-southeast-1 | 2 | 대상 |
| kadit | `chkjnszxisljiywjtqve` | ap-northeast-2 | 2 | 대상 |
| locawing | `nkizvcbesznhvwgskxhy` | ap-northeast-2 | 1 | 대상 |
| qkiki | `xoxnkezwrrbwkdjlupkp` | us-west-1 | — | **제외(독립)** |
| one-more-rep | `uuuogjemtqahnztnxicn` | ap-northeast-2 | — | **제외(독립)** |

---

## 1. Goalivo → wideget-core (조사 완료)

| 항목 | 값 |
|---|---|
| 형태 | 정적 웹앱(`index.html`) + Vercel Node serverless(`api/*.js`). Next.js 아님. |
| 클라이언트 | `window.supabase.createClient(URL, ANON)` — 값은 `GET /api/config` 로 런타임 수신 |
| ENV | `SUPABASE_URL`, `SUPABASE_ANON_KEY`(→ 표준 `NEXT_PUBLIC_*` 로 이전, 레거시 폴백 유지), `OPENAI_API_KEY`/`ANTHROPIC_API_KEY`(서버 전용), `SUPABASE_SERVICE_ROLE_KEY`(신규 표준·현재 코드 미사용) |
| Auth | Email/PW + Google OAuth (SPA, 서버 콜백 없음), redirect = `origin+pathname` |
| 테이블(public) | `user_state`(user_id PK, state_data jsonb, updated_at), `feedback_posts`(user_id, user_email, title, body, category, status, images_json, created_at, id) |
| Realtime | `public.user_state` 활성 |
| Storage | ❌ 미사용(피드백 이미지 base64) |
| Edge fn | ❌ |
| 통합 후 상태 | 공통 스키마 + `goalivo` 스키마 **적용 완료**. user_state/feedback_posts 는 현행 유지(점진 이관 대상). |

---

## 2. castfolio (DB 실측 완료 · **두 앱 공존 발견**)

- project: `vrbawgqrhigtkyiengkm` (ap-southeast-1) · auth users: 2
- ⚠️ **한 프로젝트에 서로 다른 두 앱이 공존**:
  - `public`(21테이블): **트레이딩/배틀 앱**. 활성 데이터(battles 88, strategies 10, signal_boxes 10). **자체 커스텀 인증**(`users.password_hash`, Supabase Auth 아님, user_id → public.users).
  - `castfolio`(28테이블 Prisma PascalCase): **탤런트 에이전시 커머스 앱**. 시드만(User/Talent/Project 각 1). **Supabase Auth 통합**(`User.supabaseUid`).
- Storage bucket: **`payment-proof`**
- 사용자 결정 = **둘 다 스키마 분리 이관** → wideget-core `castfolio`(트레이딩) + `castfolio_agency`(에이전시). 구조 미러 **적용 완료**.
- 확인 필요: 각 앱 저장소/코드/ENV/callback, 트레이딩 앱의 인증 통합 방식(커스텀 유지 vs Supabase Auth 이전).

## 3. kadit (DB 실측 완료 · 코드/ENV 확인 필요)

- project: `chkjnszxisljiywjtqve` (ap-northeast-2) · auth users: 2
- 기존 스키마: `public` 만
- Storage bucket: **`kadit-images`**
- public 테이블 9개 — **전부 `kadit_` 접두사 + 전부 `user_id uuid` 보유**:
  `kadit_artifacts`, `kadit_generation_schedules`, `kadit_image_jobs`, `kadit_render_jobs`, `kadit_renders`, `kadit_scheduled_runs`, `kadit_source_feeds`, `kadit_source_items`, `kadit_versions`
- 특징: 이미 사용자별 데이터 모델이 깔끔함(전부 user_id). 통합 시 `kadit` 스키마로 옮기고 `kadit_` 접두사 제거 여지 있음.
- 확인 필요: URL/anon/service 변수명, Auth/콜백.

## 4. locawing (DB 실측 완료 · 코드/ENV 확인 필요)

- project: `nkizvcbesznhvwgskxhy` (ap-northeast-2) · auth users: 1
- 기존 스키마: `public` 만
- Storage buckets: **`scenario-exports`, `test-reports`**
- public 테이블 9개, 분류:

| 분류 | 테이블 |
|---|---|
| 사용자 소유(user_id uuid) | `devices`, `scenarios`, `schedules`, `test_reports`, `commands`(user_id+device_id) |
| 디바이스 스코프(device_id uuid) | `location_logs` |
| 유저 컬럼 없음 | `blocks`, `profiles`, `scenario_points` |

- 확인 필요: URL/anon/service 변수명, Auth/콜백, `profiles` 의 PK(=auth user 매핑?), `location_logs` 접근 권한 경로(device→user).

---

## 5. 통합 대상 요약

| 앱 | DB 실측 | 대상 스키마(wideget-core) | Storage | 코드/ENV |
|---|---|---|---|---|
| Goalivo | ✅ | `goalivo` (생성됨) | 미사용 | 확인+반영 완료 |
| castfolio | ✅ 21+28테이블 | `castfolio`(트레이딩)+`castfolio_agency`(에이전시) 미러 완료 | `payment-proof` | 저장소 추가 필요 |
| kadit | ✅ 9테이블(전부 user_id) | `kadit` (생성됨) | `kadit-images` | 저장소 추가 필요 |
| locawing | ✅ 9테이블 | `locawing` (생성됨) | `scenario-exports`, `test-reports` | 저장소 추가 필요 |
| ~~qkiki~~ | 조회 안 함 | (제외) | (제외) | (제외) |
| ~~one-more-rep~~ | 조회 안 함 | (제외) | (제외) | (제외) |

## 6. 핵심 사실: 각 앱은 서로 다른 auth.users 풀

- castfolio/kadit/locawing 은 **각자 별도 프로젝트의 `auth.users`** 를 갖고 있습니다(user_id UUID 가 프로젝트마다 다름).
- wideget-core 로 데이터를 실제 이관하려면 **email 기준 사용자 매핑 → user_id 재매핑**이 필수입니다. 이는 파괴적/위험 작업이므로 **자동 실행하지 않고** 사람 결정을 받습니다(`WIDEGET_CORE_MANUAL_ACTIONS.md` E, 본 리포트 결정 항목).
- 현재 실사용자 수가 적음(castfolio 2, kadit 2, locawing 1)이라 매핑 부담은 작습니다.
