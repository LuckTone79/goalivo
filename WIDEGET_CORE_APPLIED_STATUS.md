# wideget-core — 적용 현황 (Applied Status)

> 갱신: 2026-07-08 · 대상: wideget-core (`ossqwphalaxhmadmffsn`, 구 Goalivo)

## ✅ 자동으로 완료된 것 (Supabase MCP)

1. **프로젝트 표시명**: `Goalivo` → `wideget-core` (사람이 변경 완료. ref/URL 불변).
2. **통합 마이그레이션 적용** (`wideget_core_four_app_unification`):
   - 스키마 생성: `goalivo`, `castfolio`, `kadit`, `locawing` (qkiki/one_more_rep **미생성**).
   - `public.apps`(+seed 4행), `public.app_memberships`, `public.global_profiles` 생성.
   - RLS enable + 정책 6개, `updated_at` 트리거, 인덱스 2개.
3. **보안 하드닝 마이그레이션** (`harden_updated_at_search_path`):
   - `public.wideget_set_updated_at`, `public.set_user_state_updated_at` 에 `set search_path=''` 적용.
   - → Security Advisor 의 `function_search_path_mutable` 경고 **2건 해소**.
4. **기존 데이터 무손상 확인**: `public.user_state`, `public.feedback_posts` 그대로 존재. 삭제/변경 없음.
5. **제외 프로젝트 무접촉**: qkiki, one-more-rep 은 DB 조회조차 하지 않음.

### 적용 후 검증 결과
| 항목 | 결과 |
|---|---|
| 신규 스키마 | castfolio, goalivo, kadit, locawing (제외 2개 부재) ✅ |
| 공통 테이블 | apps, app_memberships, global_profiles ✅ |
| apps seed | goalivo, castfolio, kadit, locawing (4) ✅ |
| RLS enabled | 3개 테이블 모두 true, 정책 6개 ✅ |
| Security Advisor | ERROR 0 / WARN 0 (leaked-password 포함 해소, 2026-07-08). INFO 49건은 미러 테이블 service_role 전용(의도됨) |

## ⏳ 사람이 직접 해야 하는 것 (대시보드/호스팅)

| # | 작업 | 위치 | 상태 |
|---|---|---|---|
| H1 | Leaked Password Protection **켜기** | Auth → Providers → Email → "Prevent use of leaked passwords" | ✅ 완료(2026-07-08). Advisor WARN 해소 |
| H2 | Exposed schemas 에 `goalivo/castfolio/kadit/locawing` 추가 여부 결정 | Settings → API | 앱이 `schema()` 접근 시 필요 |
| H3 | Auth Redirect URLs 등록(실제 도메인) | Auth → URL Config | 도메인 확인 필요 |
| H4 | 각 앱 호스팅 ENV 를 wideget-core 값으로 등록 | Vercel 등 | castfolio/kadit/locawing 저장소 필요 |
| H5 | 4개 앱 **데이터 실이관 여부/방식 결정** | (아래 결정 항목) | **결정 대기** |

## ⚠️ 결정 대기 (사람) — 데이터/Auth 통합 전략

각 앱은 **별도 프로젝트의 auth.users** 를 가짐(user_id 상이). wideget-core 로 데이터를 실제로 옮기려면
email 기준 사용자 매핑 → user_id 재매핑이 필요(파괴적/위험 → 자동 실행 안 함). 선택지:

- **A) 신규만 통합(권장, 무위험)**: 지금부터 새 가입/새 데이터만 wideget-core 사용. 기존 앱 데이터는 각 프로젝트에 잔존, 필요 시 점진 이관.
- **B) 전체 이관(중단·위험)**: 기존 castfolio/kadit/locawing 데이터를 스키마별로 이관 + user_id 재매핑 + 앱 repoint. 별도 승인/설계 필요.

> 현재 실사용자 수(castfolio 2, kadit 2, locawing 1)로 B 부담은 작지만, auth.users 재매핑은 반드시 사람 확인 후 진행.

## 진행 현황 업데이트 (2026-07-08, 2차)

사용자 결정: **데이터 = 전체 이관 설계(B)** / 자동작업 = 빈 테이블 구조+RLS, 저장소 추가 안내, Storage 스크립트.

- ✅ **kadit** 스키마: 9테이블 빈 미러 + RLS(9) + FK(13) + 트리거(5) **적용 완료**.
- ✅ **locawing** 스키마: 9테이블 빈 미러 + RLS(9) + FK(14) + 검사(9) **적용 완료**.
  (`profiles.id=auth.users.id`, 나머지 `user_id→profiles.id` 관계 충실 반영, 시나리오/디바이스 스코프 RLS 포함)
- ✅ **castfolio** (사용자 결정: 둘 다 스키마 분리):
  - `castfolio` 스키마: **21테이블 미러** (트레이딩/배틀 앱, source public). FK 30. RLS 활성.
    ⚠️ 이 앱은 **자체 커스텀 인증**(`castfolio.users.password_hash`, Supabase Auth 아님). FK 는 `castfolio.users(id)`.
    → RLS 활성 + **정책 없음 = service_role 전용**(안전 기본값). 온보딩 시 정책 정의(커스텀 users → Supabase Auth 이전 검토).
  - `castfolio_agency` 스키마(신규 추가): **28테이블 미러** (Prisma 탤런트 에이전시). enum 17, FK 34, unique 12. RLS 활성.
    이 앱은 Supabase Auth 통합(`User.supabaseUid`). RLS 활성 + service_role 전용(온보딩 시 supabaseUid 기반 정책 정의).
  - Advisor: castfolio/castfolio_agency 49테이블에 `rls_enabled_no_policy`(INFO). **의도된 안전 기본값**(authenticated 접근 차단). ERROR/신규 WARN 없음.
- ✅ 문서: `WIDEGET_CORE_DATA_MIGRATION_PLAN.md`(B 상세), `WIDEGET_CORE_APP_REPO_ONBOARDING.md`(저장소 추가/코드 표준화), `scripts/wideget-migrate-storage.mjs`(비파괴 Storage 복사) 준비.

### 이관 실행은 아직 안 함(설계만)
- 실제 데이터/사용자 이관은 사람 승인 후. auth.users 는 Auth Admin API 로만 생성(직접 INSERT 금지).

## 다음 자동화 가능 작업(승인/결정 시)
- castfolio: 이관 대상 스키마 결정되면 빈 미러 + RLS 생성.
- (B 실행 시) user_id_map 작성 + FK 위상 순서 데이터 복사 + Storage 스크립트 실행 + 앱 repoint.
