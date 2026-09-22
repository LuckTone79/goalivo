# wideget-core — 앱 저장소 추가 & 코드 표준화 안내

> castfolio / kadit / locawing 은 별도 GitHub 저장소이며, 이 세션에는 `goalivo` 만 클론되어 있습니다.
> 각 앱의 **코드/ENV/auth callback** 을 wideget-core 기준으로 바꾸려면 해당 저장소를 세션에 추가해야 합니다.

## 1. 저장소를 세션에 추가하는 법
- 채팅에 예: **"castfolio 저장소를 세션에 추가해줘"** 처럼 요청하면 제가 `add_repo` 로 편입합니다.
- (조직/워크스페이스 정책상 접근이 막혀 있으면 관리자가 https://claude.ai/admin-settings 에서 권한을 부여해야 할 수 있습니다.)
- 저장소가 추가되면 저는 아래 체크리스트대로 표준화를 진행합니다.

## 2. 앱별 코드 표준화 체크리스트 (저장소 추가 후 제가 수행)

각 앱(castfolio/kadit/locawing) 공통:

1. **ENV 표준화** (`.env.example` 갱신, 실제 키는 미기재):
   - `NEXT_PUBLIC_SUPABASE_URL` = wideget-core URL
   - `NEXT_PUBLIC_SUPABASE_ANON_KEY` = wideget-core anon key
   - `SUPABASE_SERVICE_ROLE_KEY` = wideget-core service_role (서버 전용, 프론트 노출 금지)
2. **Supabase client 표준화**:
   - 개별 URL/key 하드코딩 제거 → 위 ENV 기반 생성.
   - 앱별 스키마 접근은 `supabase.schema('<app>')` 로 분리(예: `supabase.schema('kadit').from('kadit_source_feeds')`).
3. **app_id 상수 추가**: `export const APP_ID = 'castfolio' | 'kadit' | 'locawing'`.
4. **로그인 후 멤버십/프로필 보장**: `public.app_memberships`(app_id)·`public.global_profiles` upsert (Goalivo `ensureWidegetMembership()` 패턴 이식).
5. **RLS 정합성 확인**: 사용자 데이터 접근이 `auth.uid()` 기반인지 점검. user_metadata 기반 권한 판단 금지.
6. **service_role 사용처 점검**: 서버 라우트/액션에서만. 브라우저 번들 유입 금지.
7. **Auth Redirect**: 실제 도메인 확인 → `WIDEGET_CORE_AUTH_REDIRECT_URLS.md` 갱신 + 대시보드 등록.
8. **검증**: install/lint/typecheck/build + auth callback 컴파일 + ENV 누락 시 오류 처리.

## 3. 앱별 유의점 (실측 기반)
- **kadit**: 테이블 전부 `user_id` 보유. wideget-core `kadit` 스키마에 동일 구조 준비 완료 → client 를 `schema('kadit')` 로 전환.
- **locawing**: `profiles.id = auth.users.id`, 나머지 `user_id → profiles.id`. wideget-core `locawing` 스키마 준비 완료. 로그인 시 `locawing.profiles` 행 보장 로직 필요.
- **castfolio**: `public`(트레이딩/배틀) 과 `castfolio`(탤런트 에이전시, Prisma) 두 도메인 공존 → **이관 대상 스키마 결정 후** 진행. Prisma 사용 시 `schema` 설정/마이그레이션 방식 확인 필요.

## 4. 지금 상태
| 앱 | wideget-core 스키마 준비 | 코드 표준화 |
|---|---|---|
| goalivo | ✅(공통+goalivo) | ✅ 완료 |
| kadit | ✅ 9테이블 미러+RLS | ⏳ 저장소 추가 필요 |
| locawing | ✅ 9테이블 미러+RLS | ⏳ 저장소 추가 필요 |
| castfolio | ⏳ 스키마 결정 대기 | ⏳ 저장소 추가 필요 |
