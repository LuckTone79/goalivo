# wideget-core Migration Runbook

> 대상 프로젝트: 기존 **Goalivo** Supabase project (ref `ossqwphalaxhmadmffsn`, 표시명 → `wideget-core`).
> 마이그레이션 파일: `supabase/migrations/20260707120000_wideget_core_4app_unification.sql`

## 0. 사전 확인
- [ ] 이 migration 은 **비파괴/부가 전용**입니다. DROP/DELETE/TRUNCATE 없음. 재실행 안전(IF NOT EXISTS/CREATE OR REPLACE).
- [ ] `qkiki`, `one_more_rep` 스키마는 **생성하지 않습니다**.
- [ ] `auth` 스키마/`auth.users` 는 **수정하지 않습니다**(FK 참조만).
- [ ] service_role key 는 서버에서만 사용. 프론트 노출 금지.

## 1. 로컬 문법/RLS 검증 (이미 수행됨)
이 저장소에서 로컬 PostgreSQL 16 + Supabase 호환 shim 으로 검증 완료:
- migration 2회 연속 적용 성공(멱등성 확인).
- RLS 기능 테스트 통과:
  - 유저 본인 멤버십 self-join(role='user') 성공
  - `role='admin'` 자가 승격 시도 → **차단**
  - 타 유저 대상 insert → **차단**
  - 타 유저 프로필/멤버십 조회 → **불가**(본인 것만 보임)
  - `updated_at` 트리거 동작 확인

재현(선택):
```bash
# 로컬 PG + shim 필요. scratchpad/supabase_shim.sql 참고.
createdb widegettest
psql -d widegettest -f supabase_shim.sql
psql -v ON_ERROR_STOP=1 -d widegettest -f supabase/migrations/20260707120000_wideget_core_4app_unification.sql
```

## 2. 원격 적용 방법 (택1)

### 방법 A — Supabase CLI (권장, 로컬 파일/셸 있는 경우)
```bash
supabase link --project-ref ossqwphalaxhmadmffsn
# 원격 상태를 먼저 확인
supabase migration list
# 신규 migration 적용
supabase db push
```

### 방법 B — Supabase Dashboard SQL Editor (수동)
1. wideget-core(=Goalivo) 프로젝트 → SQL Editor.
2. `supabase/migrations/20260707120000_wideget_core_4app_unification.sql` 전체 붙여넣기.
3. Run. (재실행해도 안전)

### 방법 C — MCP `apply_migration` (원격 직접, 신중히)
- 이 세션의 Supabase MCP 를 통해 원격에 직접 적용 가능. 되돌리기 어려우므로 **사용자 명시 승인 후**에만 실행.

## 3. 적용 순서 (전체 통합 관점)
1. **본 migration**(공통 레지스트리 + 4개 스키마) 적용. ← 지금 준비된 산출물.
2. Goalivo 클라이언트/서버 변경 배포(이미 코드 반영):
   - `api/config.js` 표준 ENV 인식, `.env.example` 갱신
   - `index.html`: `WIDEGET_APP_ID`, `ensureWidegetMembership()`(로그인 시 프로필/멤버십 보장)
3. castfolio/kadit/locawing 저장소 추가 → 각 앱 조사 → 앱별 스키마 테이블 migration 작성/적용(별도 파일 `..._<app>_tables.sql`).
4. 각 앱 ENV 를 wideget-core 값으로 전환(§ `.env.example`).
5. Dashboard Auth Redirect URLs 등록(`WIDEGET_CORE_AUTH_REDIRECT_URLS.md`).
6. (선택) user_state/feedback 무중단 스키마 이관(`WIDEGET_CORE_UNIFICATION_PLAN.md` §6).

## 4. 적용 후 검증 (원격)
```sql
-- 스키마 생성 확인 (qkiki/one_more_rep 는 없어야 정상)
select schema_name from information_schema.schemata
where schema_name in ('goalivo','castfolio','kadit','locawing','qkiki','one_more_rep');

-- 공통 테이블
select table_name from information_schema.tables
where table_schema='public' and table_name in ('apps','app_memberships','global_profiles');

-- seed
select * from public.apps order by id;

-- RLS 활성 확인
select relname, relrowsecurity from pg_class
where relname in ('apps','app_memberships','global_profiles');
```
- Supabase **Advisors**(Security/Performance) 를 실행하여 RLS 경고가 없는지 확인.

## 5. 앱별 스키마 테이블 작성 가이드(castfolio/kadit/locawing 후속)
파일명 예: `supabase/migrations/YYYYMMDDHHMMSS_<app>_tables.sql`
```sql
-- 사용자 소유 테이블 예시
create table if not exists <app>.<thing> (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  ...,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table <app>.<thing> enable row level security;
create policy <thing>_rw_own on <app>.<thing>
  for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
create trigger trg_<thing>_updated before insert or update on <app>.<thing>
  for each row execute function public.wideget_set_updated_at();
-- PostgREST 노출이 필요하면 대시보드 API settings 의 "Exposed schemas" 에 <app> 추가.
```
> RLS 없는 사용자 데이터 테이블 생성 금지. 권한은 `auth.uid()`/`app_memberships` 로만.
