# wideget-core — Rollback Plan

> 본 통합 migration 은 **비파괴/부가 전용**이라 롤백이 단순합니다. 기존 `public.user_state`/`feedback_posts` 및 데이터는 전혀 건드리지 않으므로, 롤백해도 현재 Goalivo 운영은 그대로 유지됩니다.

## 1. 코드 변경 롤백 (Goalivo)
git 되돌리기:
```bash
git revert <이번 커밋 해시>   # 또는 해당 파일만 이전 버전으로 복구
```
영향 파일:
- `index.html` (`WIDEGET_APP_ID`, `ensureWidegetMembership()`, APP_VERSION)
- `api/config.js` (표준 ENV 인식 — 레거시 폴백 포함이라 되돌려도 안전)
- `.env.example`

> `ensureWidegetMembership()` 는 실패를 조용히 무시하므로, DB migration 을 적용하지 않은 상태에서도 앱은 정상 동작합니다(멤버십/프로필 upsert 만 no-op).

## 2. DB migration 롤백 (필요 시)
본 migration 이 **새로 만든 객체만** 제거합니다. 기존 객체/데이터는 대상이 아닙니다.

⚠️ 아래는 "방금 적용한 통합 스키마를 되돌리고 싶을 때"만 실행하세요. 공통 테이블에 이미 실제 멤버십/프로필 데이터가 쌓였다면, 삭제 전에 백업하세요.

```sql
begin;

-- 공통 테이블 (데이터 포함 삭제 — 필요 시 먼저 백업)
drop table if exists public.app_memberships;
drop table if exists public.global_profiles;
drop table if exists public.apps;

-- 트리거 함수 (다른 곳에서 안 쓰면)
drop function if exists public.wideget_set_updated_at();

-- 앱별 스키마: 비어 있을 때만 안전하게 제거 (CASCADE 사용 금지 — 데이터 보호)
drop schema if exists goalivo  restrict;
drop schema if exists castfolio restrict;
drop schema if exists kadit    restrict;
drop schema if exists locawing  restrict;

commit;
```

- `drop schema ... restrict` 는 스키마 안에 객체가 있으면 **실패**합니다(의도된 안전장치). 앱별 테이블을 이미 만들었다면 그 앱 데이터를 백업/이관 후 개별 처리하세요.
- **절대 `drop schema ... cascade` 를 습관적으로 쓰지 마세요.** 데이터 유실 위험.

## 3. 롤백하면 안 되는 것 (금지)
- 기존 `public.user_state`, `public.feedback_posts` 및 그 데이터 → **삭제/변경 금지** (이번 작업 대상 아님).
- `auth`/`auth.users` → 변경 금지.
- `qkiki`, `one_more_rep` 관련 어떤 것도 → 손대지 말 것.

## 4. ENV 롤백
- 표준 변수(`NEXT_PUBLIC_*`)를 제거해도 Goalivo 는 레거시 `SUPABASE_URL`/`SUPABASE_ANON_KEY` 로 동작합니다. 둘 중 하나만 있으면 정상.

## 5. 검증(롤백 후)
```sql
select schema_name from information_schema.schemata
 where schema_name in ('goalivo','castfolio','kadit','locawing');  -- 0 rows 기대
select table_name from information_schema.tables
 where table_schema='public' and table_name in ('apps','app_memberships','global_profiles'); -- 0 rows 기대
select table_name from information_schema.tables
 where table_schema='public' and table_name in ('user_state','feedback_posts'); -- 여전히 존재해야 정상
```
