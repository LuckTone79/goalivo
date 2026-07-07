# SUPABASE 4-App Inventory (wideget-core 통합 대상)

> 작성일: 2026-07-07 · 기준 프로젝트: 기존 **Goalivo** Supabase project → 사람이 대시보드에서 **wideget-core** 로 표시 이름 변경 예정.

## 0. 중요한 범위 사실 (반드시 먼저 읽을 것)

이 세션의 **workspace 에는 `goalivo` 저장소 하나만 존재**합니다.

- `git`/`ls` 확인 결과 루트에 있는 것은 Goalivo 웹앱뿐입니다 (`index.html`, `api/`, `supabase/`, `scripts/`).
- `castfolio`, `kadit`, `locawing` 는 **별도 저장소**이며 이 세션에 클론되어 있지 않습니다.
- 세션 저장소 스코프도 `lucktone79/goalivo` 로 한정되어 있고, `list_repos` 는 이 계정 세션에서 사용 불가로 응답했습니다.
- 따라서 **castfolio/kadit/locawing 의 실제 코드/ENV/테이블은 이 세션에서 직접 조사·수정할 수 없습니다.**
  - 이 문서에서 해당 3개 앱 항목은 "확인 필요(저장소 추가 후 조사)" 로 표시합니다.
  - 통합 SQL(공통 스키마)과 앱별 적용 체크리스트는 모두 준비되어 있으며, 저장소만 추가되면 바로 적용 가능합니다.

`qkiki`(=yapp), `one-more-rep` 은 통합 제외 대상이며 이 세션에 폴더도 없습니다. `EXCLUDED_PROJECTS.md` 참고.

---

## 1. Goalivo (조사 완료 · 이 세션에 존재)

| 항목 | 값 |
|---|---|
| 형태 | 정적 웹앱 (`index.html`) + Vercel Node serverless (`api/*.js`). **Next.js 아님.** |
| Supabase SDK | CDN UMD: `@supabase/supabase-js@2` (`index.html` `<script>`), 서버 `@supabase/supabase-js@^2.101.1` (package.json) |
| 클라이언트 생성 | `window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY)` — 값은 런타임에 `GET /api/config` 로 수신 |
| 현재 기존 Supabase project ref | `ossqwphalaxhmadmffsn` (기존 migration 주석에 명시. = 통합 기반 프로젝트) |

### 1.1 환경변수 (변수명/존재만 기록 — 실제 키 값은 미기재)

| 변수명 | 위치 | 노출 경로 | 비고 |
|---|---|---|---|
| `SUPABASE_URL` | Vercel env → `api/config.js` | `/api/config` 로 클라이언트 전달 | 통합 후 `NEXT_PUBLIC_SUPABASE_URL` 우선, 레거시 폴백 유지 |
| `SUPABASE_ANON_KEY` | Vercel env → `api/config.js` | `/api/config` 로 클라이언트 전달 | anon key (공개 가능) |
| `OPENAI_API_KEY` | Vercel env → `api/ai.js`, `api/image.js` | **서버 전용** | 프론트 노출 안 함 |
| `ANTHROPIC_API_KEY` | Vercel env → `api/ai.js` | **서버 전용** | 프론트 노출 안 함 |
| `OPENAI_MODEL`/`OPENAI_WEB_MODEL`/`OPENAI_IMAGE_MODEL`/`ANTHROPIC_MODEL` | Vercel env (선택) | 서버 전용 | 모델 오버라이드 |
| `SUPABASE_SERVICE_ROLE_KEY` | **현재 미사용** | — | 통합 표준에 추가(서버 전용). 현재 코드에서 참조 없음 |

> service_role key 는 현재 코드 어디에서도 참조하지 않습니다. 통합 표준 변수로만 추가하며 서버 라우트에서만 사용합니다.

### 1.2 Auth

| 항목 | 값 |
|---|---|
| 사용 여부 | **사용함** |
| 방식 | 이메일/비밀번호 (`signInWithPassword`, `signUp`) + Google OAuth (`signInWithOAuth({provider:'google'})`) |
| 세션 처리 | `supa.auth.getSession()` + `supa.auth.onAuthStateChange(...)` (SPA, 서버 콜백 라우트 없음) |
| OAuth redirect | `window.location.origin + window.location.pathname` (동적) — 별도 `/auth/callback` 라우트 없음 |
| 관리자 식별 | `FEEDBACK_ADMIN_EMAIL = 'luck2s7912@gmail.com'` (피드백 보드 UI 용도) |

### 1.3 테이블 / 스키마 (현재 사용, 모두 `public`)

| 테이블 | 용도 | 접근 코드 | user 컬럼 |
|---|---|---|---|
| `public.user_state` | 앱 상태 전체를 JSONB 1행/유저로 저장·동기화 | `supa.from('user_state').upsert/select` (`syncToCloud`/`syncFromCloud`) | `user_id` (PK), `state_data jsonb`, `updated_at` |
| `public.feedback_posts` | 피드백 게시판 | `supa.from('feedback_posts').insert/select/update` | `user_id`, `user_email`, `title`, `body`, `category`, `status`, `images_json`, `created_at`, `id` |

- Realtime: `public.user_state` 에 활성화됨 (`supabase/migrations/20260620_enable_realtime_user_state.sql`).
- `feedback_posts` DDL 은 저장소에 `supabase-feedback.sql` 로 존재했으나 `.gitignore` 처리되어 현재 트리에는 없음(운영 프로젝트에는 적용됨). → 통합 시 `goalivo` 스키마로 이관 대상(설계서 참고).

### 1.4 Storage / Edge Functions

| 항목 | 값 |
|---|---|
| Storage bucket | **미사용.** 피드백 이미지는 Storage 가 아니라 base64(`images_json`)로 `feedback_posts` 에 저장. |
| Edge Functions | **미사용.** (`supabase/functions/` 없음) |

---

## 2. castfolio (확인 필요 · 저장소 미포함)

| 항목 | 상태 |
|---|---|
| workspace 존재 | ❌ 이 세션에 없음 |
| Supabase URL 변수명 | 확인 필요 |
| anon key 변수명 | 확인 필요 |
| service role 변수명 | 확인 필요 |
| Auth 사용 | 확인 필요 |
| auth callback route | 확인 필요 |
| 테이블/스키마 | 확인 필요 → 통합 시 `castfolio` 스키마 |
| Storage bucket | 확인 필요 |
| Edge function | 확인 필요 |

> 조사 방법: 이 세션에 `castfolio` 저장소를 추가(`add_repo`)한 뒤 §1 과 동일한 항목을 채운다.

## 3. kadit (확인 필요 · 저장소 미포함)

| 항목 | 상태 |
|---|---|
| workspace 존재 | ❌ 이 세션에 없음 |
| Supabase URL/anon/service 변수명 | 확인 필요 |
| Auth / callback route | 확인 필요 |
| 테이블/스키마 | 확인 필요 → 통합 시 `kadit` 스키마 |
| Storage / Edge function | 확인 필요 |

## 4. locawing (확인 필요 · 저장소 미포함)

| 항목 | 상태 |
|---|---|
| workspace 존재 | ❌ 이 세션에 없음 |
| Supabase URL/anon/service 변수명 | 확인 필요 |
| Auth / callback route | 확인 필요 |
| 테이블/스키마 | 확인 필요 → 통합 시 `locawing` 스키마 |
| Storage / Edge function | 확인 필요 |

---

## 5. 통합 대상 요약표

| 앱 | 이 세션 존재 | 대상 스키마 | Auth | Storage | 조사 상태 |
|---|---|---|---|---|---|
| Goalivo | ✅ | `goalivo` | Email + Google | 미사용 | 완료 |
| castfolio | ❌ | `castfolio` | 확인 필요 | 확인 필요 | 대기(저장소 추가) |
| kadit | ❌ | `kadit` | 확인 필요 | 확인 필요 | 대기(저장소 추가) |
| locawing | ❌ | `locawing` | 확인 필요 | 확인 필요 | 대기(저장소 추가) |
| ~~qkiki~~ | ❌ | (제외) | — | — | 통합 제외(독립 유지) |
| ~~one-more-rep~~ | ❌ | (제외) | — | — | 통합 제외(독립 유지) |
