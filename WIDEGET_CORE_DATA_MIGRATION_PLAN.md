# wideget-core — 전체 데이터 이관 설계 (Data Migration Plan, 옵션 B)

> ⚠️ 이 문서는 **설계/절차**입니다. 실제 이관은 **사람 승인 후** 실행합니다. 모든 절차는 **비파괴**(원본 유지)이며, 원본 프로젝트/데이터는 검증 완료 전까지 삭제하지 않습니다.
> 대상: castfolio / kadit / locawing → wideget-core(`ossqwphalaxhmadmffsn`). Goalivo 는 이미 wideget-core 가 원본.

## 0. 핵심 난제: 프로젝트마다 다른 auth.users

각 앱은 **자기 프로젝트의 `auth.users`** 를 가집니다(같은 사람이라도 project마다 UUID 다름).
따라서 데이터를 옮기기 전에 **사용자 매핑**을 먼저 만들어야 합니다.

현재 실사용자(적음): castfolio 2, kadit 2, locawing 1.

### 0.1 사용자 매핑 원칙
- 매핑 키 = **email**(대소문자 정규화). 각 원본 `auth.users.email` ↔ wideget-core `auth.users.email`.
- wideget-core 에 없는 이메일은 **먼저 사용자 생성**(초대/관리자 생성) 후 매핑. auth.users 는 직접 INSERT 하지 않고 Auth Admin API 로 생성.
- 매핑 테이블(운영용, 이관 후 보관/삭제):

```sql
-- wideget-core 에 임시 매핑 테이블 (service_role 전용, RLS 무관 — public 아님 권장)
create schema if not exists migration_ops;
create table if not exists migration_ops.user_id_map (
  app_id      text not null,           -- 'castfolio'|'kadit'|'locawing'
  source_uid  uuid not null,           -- 원본 프로젝트의 user_id
  source_email text,
  target_uid  uuid,                    -- wideget-core 의 user_id (매핑/생성 후 채움)
  note        text,
  primary key (app_id, source_uid)
);
```
- 이관 스크립트는 각 행의 `user_id` 를 `target_uid` 로 치환하여 삽입합니다.

## 1. 이관 순서(공통)
1. 대상 스키마 빈 테이블 준비(✅ kadit/locawing 완료, castfolio 결정 후).
2. 원본에서 사용자 목록 export → email 기준 `user_id_map` 작성 → 부족 사용자 wideget-core 에 생성.
3. **FK 위상 순서**로 테이블 데이터 복사(부모 → 자식), `user_id`(및 profiles.id 등) 치환.
4. 시퀀스/PK 충돌 점검(전부 uuid/자연키라 충돌 위험 낮음).
5. Storage 이관(`STORAGE_MIGRATION_PLAN.md` / `scripts/wideget-migrate-storage.mjs`).
6. 검증(행수 대조, 샘플 조회, RLS 동작) → 앱 repoint(ENV 교체) → 모니터링.
7. 원본은 롤백 대비로 **일정 기간 보존 후** 별도 승인 하에 정리.

## 2. kadit 데이터 이관 (구조 준비 완료)
- 원본: `chkjnszxisljiywjtqve` public.kadit_* → wideget-core `kadit.kadit_*` (동일 구조).
- 모든 테이블에 `user_id` 존재 → `user_id` 를 `target_uid` 로 치환.
- FK 위상 순서:
  1. kadit_generation_schedules
  2. kadit_source_feeds
  3. kadit_source_items
  4. kadit_scheduled_runs
  5. kadit_artifacts, kadit_image_jobs, kadit_render_jobs, kadit_renders, kadit_versions
- Storage: `kadit-images` → wideget-core `kadit-images`.

## 3. locawing 데이터 이관 (구조 준비 완료)
- 원본: `nkizvcbesznhvwgskxhy` public.* → wideget-core `locawing.*`.
- `profiles.id = auth.users.id`. 다른 테이블 `user_id → profiles.id`.
- 매핑: `profiles.id`(=source auth uid) → target uid. 나머지 user_id 동일 치환.
- FK 위상 순서:
  1. profiles
  2. devices, scenarios
  3. blocks, scenario_points, schedules, test_reports, commands, location_logs
- Storage: `scenario-exports`, `test-reports` → 동명 버킷.

## 4. castfolio 데이터 이관 (⚠️ 스키마 결정 대기)
castfolio 프로젝트는 **두 도메인**을 포함:
- `public`(21테이블, 활성: battles 88 / strategies 10 / signal_boxes 10 / users 1) — 트레이딩/배틀 앱.
- `castfolio`(28테이블 Prisma PascalCase, 시드 수준: User 1 / Talent 1 / Project 1, 나머지 0) — 탤런트 에이전시 커머스 앱.

→ **어느 스키마(들)를 wideget-core `castfolio` 로 이관할지 사람이 결정**해야 함(본 리포트 질문 참조).
결정 후 kadit/locawing 과 동일 절차로 구조 미러 + 데이터 이관 설계를 확정한다.

## 5. 실행 방식(도구)
- **테이블 데이터**: `user_id` 치환이 필요하므로 단순 pg_dump 로는 부족. 권장:
  - 원본에서 `copy (select ...) to stdout csv` 또는 supabase-js select → wideget-core 로 insert 시 `user_id` 치환.
  - 소량이므로 스크립트/SQL 로 테이블별 처리(부모→자식). 배치 insert, `on conflict do nothing`.
- **Auth 사용자 생성**: Supabase Auth Admin API(`auth.admin.createUser`) — service_role 서버에서만. 비밀번호는 초대 이메일/매직링크 방식 권장(평문 이동 금지).
- **service_role 키**: 서버/CLI 환경변수로만. 프론트/레포에 하드코딩 금지.

## 6. 롤백
- 이관은 wideget-core 대상 스키마에 **추가**만 하므로, 실패 시 대상 스키마 데이터만 정리하면 원본은 무손상.
- 앱 repoint(ENV) 는 이관·검증 완료 후 마지막에. 문제 시 ENV 를 원본으로 되돌리면 즉시 원복.
