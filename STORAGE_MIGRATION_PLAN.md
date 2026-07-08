# wideget-core — Storage Migration Plan

> 기존 Storage 파일은 **삭제하지 않습니다.** 아래는 필요 시 **수동 비파괴 이관** 절차입니다.

## 1. 현재 파악된 Storage 사용 (Supabase MCP 실측 완료)

| 앱 | project ref | Storage bucket | 이관 필요 |
|---|---|---|---|
| Goalivo(wideget-core) | `ossqwphalaxhmadmffsn` | ❌ 없음(base64 저장) | 불필요 |
| castfolio | `vrbawgqrhigtkyiengkm` | `payment-proof` | 예(결제증빙 → 프라이빗 유지 권장) |
| kadit | `chkjnszxisljiywjtqve` | `kadit-images` | 예 |
| locawing | `nkizvcbesznhvwgskxhy` | `scenario-exports`, `test-reports` | 예 |

> 실제 bucket 존재를 MCP 로 확인했습니다. 파일 내용/용량/객체 수는 이관 실행 단계에서 별도 산출.
> wideget-core 통합 시 권장 bucket 이름: `castfolio-payment-proof`, `kadit-images`, `locawing-scenario-exports`, `locawing-test-reports`.

## 2. wideget-core Storage 표준

- Bucket 네이밍: `<app_id>-<purpose>` (예: `castfolio-media`, `kadit-uploads`, `locawing-assets`).
- 접근성: 사용자 프라이빗 파일은 **private bucket** + RLS 정책(경로 prefix = `user_id`).
- 권장 경로 규칙: `<bucket>/<user_id>/<...>` → RLS 에서 `auth.uid()::text = (storage.foldername(name))[1]`.
- 공개 자산만 public bucket 사용.

### 예시 Storage RLS (private, 유저 소유 경로)
```sql
-- 읽기/쓰기: 본인 폴더만
create policy "<app> read own"
  on storage.objects for select to authenticated
  using (bucket_id = '<app>-media' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "<app> write own"
  on storage.objects for insert to authenticated
  with check (bucket_id = '<app>-media' and (storage.foldername(name))[1] = auth.uid()::text);
```

## 3. 수동 이관 절차 (기존 project → wideget-core)
각 앱이 별도 프로젝트에 bucket 을 갖고 있다면:
1. wideget-core 에 대상 bucket 생성(위 네이밍/정책).
2. 원본에서 파일 다운로드:
   - Supabase CLI/스크립트 또는 `supabase storage` API 로 객체 목록 → 다운로드.
3. wideget-core 대상 bucket 으로 업로드(동일 경로 구조 유지, 가능하면 `user_id` prefix 재매핑).
4. 앱 코드의 bucket 이름/경로를 wideget-core 기준으로 교체.
5. 검증(샘플 파일 접근 확인) **완료 전까지 원본 삭제 금지.**
6. 원본 정리는 별도 승인 후에만(`WIDEGET_CORE_MANUAL_ACTIONS.md` D/E 참고).

## 4. 확인 필요
- [ ] castfolio bucket 존재/이름/정책
- [ ] kadit bucket 존재/이름/정책
- [ ] locawing bucket 존재/이름/정책
- [ ] `user_id` 재매핑 필요 여부(프로젝트 간 auth.users UUID 상이)
