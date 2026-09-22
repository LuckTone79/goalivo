# wideget-core — 사람이 직접 해야 할 일 (Manual Actions)

> 코드/문서로 자동화할 수 없어 **사람의 대시보드/콘솔 작업**이 필요한 항목만 모았습니다.

## A. Supabase Dashboard (wideget-core = 기존 Goalivo project)

1. **프로젝트 표시 이름 변경**: Settings → General → Project name: `Goalivo` → `wideget-core`.
   - ⚠️ project **ref**(`ossqwphalaxhmadmffsn`)와 URL 은 바뀌지 않습니다. 표시 이름만 변경됩니다.
2. **본 migration 적용**: `WIDEGET_CORE_MIGRATION_RUNBOOK.md` 방법 A/B/C 중 택1.
3. **Exposed schemas(선택)**: Settings → API → "Exposed schemas" 에 `goalivo`, `castfolio`, `kadit`, `locawing` 를 PostgREST 로 노출할지 결정.
   - 앱이 `supa.schema('goalivo').from(...)` 로 접근하려면 노출 필요.
   - `qkiki`, `one_more_rep` 는 **추가하지 말 것**.
4. **Auth → URL Configuration → Redirect URLs**: `WIDEGET_CORE_AUTH_REDIRECT_URLS.md` 목록 등록.
5. **Auth → Providers → Google**: Client ID/Secret 및 Authorized redirect(`<PROJECT>.supabase.co/auth/v1/callback`) 확인.
6. **Advisors** 실행(Security/Performance) 후 경고 0 확인.

## B. Vercel (또는 각 앱 호스팅) 환경변수

각 통합 대상 앱 프로젝트에 **wideget-core 값**으로 표준 변수 등록:

| 변수 | 값 | 노출 |
|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | wideget-core project URL | 클라이언트 OK |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | wideget-core anon key | 클라이언트 OK |
| `SUPABASE_SERVICE_ROLE_KEY` | wideget-core service_role key | **서버 전용 · 절대 프론트 노출 금지** |

- Goalivo 는 `SUPABASE_URL`/`SUPABASE_ANON_KEY`(레거시)도 계속 인식하므로 무중단 전환 가능. 표준 변수로 옮기는 것을 권장.
- `qkiki`, `one-more-rep` 의 환경변수는 **변경하지 말 것**.

## C. 저장소 추가 (castfolio/kadit/locawing 조사·수정 전제)
- 이 세션 workspace 에는 `goalivo` 저장소만 있습니다.
- castfolio/kadit/locawing 의 코드/ENV/테이블을 조사·수정하려면 해당 저장소를 세션에 추가해야 합니다.
  - "castfolio 저장소를 세션에 추가해줘" 처럼 요청 → `add_repo` 로 편입 후 인벤토리/코드 표준화 진행.

## D. 승인이 필요한 파괴적/중단 위험 작업 (기본 미실행)
아래는 **명시적 승인 전까지 실행하지 않습니다**:
- `public.user_state`/`feedback_posts` → `goalivo.*` 스키마 이동(무중단 절차 필요).
- 기존 개별 Supabase project(castfolio/kadit/locawing)의 데이터/테이블 삭제.
- 기존 프로젝트 pause/삭제.

## E. 데이터 이관(선택, 별도 승인)
4개 앱이 **서로 다른 기존 프로젝트**에 데이터를 갖고 있다면, wideget-core 로 모으는 것은 **수동 비파괴 이관**으로만 진행:
1. 원본 프로젝트에서 `pg_dump --schema-only`/`--data-only` 또는 CSV export.
2. wideget-core 의 대상 스키마(`<app>`)로 import.
3. `auth.users` 는 프로젝트마다 UUID 가 다르므로, 사용자 매핑(email 기준) 후 `user_id` 재매핑 필요 → 반드시 사전 설계.
4. 원본은 검증 완료까지 **삭제 금지**.
> 실제 이관 SQL 은 대상 앱 스키마 확정 후 별도 작성.
