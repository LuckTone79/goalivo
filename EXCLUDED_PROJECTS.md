# 통합 제외 프로젝트 (독립 유지 대상)

> 아래 프로젝트는 **wideget-core 통합에서 완전히 제외**되며, 각각 **독립 Supabase project 로 계속 운영**됩니다.
> 이들에 대한 코드/ENV/Supabase URL/Auth/migration/Storage 는 이번 작업에서 **일절 수정하지 않았습니다.**

## 1. qkiki  (= yapp 프로그램)
- 상태: **독립 유지**. 자체 Supabase project 그대로 사용.
- wideget-core 에 `qkiki` 스키마 **생성하지 않음**.
- Auth Redirect URLs 에 qkiki 도메인 **포함하지 않음**.
- 이 세션 workspace 에 폴더 없음(별도 저장소).

## 2. one-more-rep
- 상태: **독립 유지**. 자체 Supabase project 그대로 사용.
- wideget-core 에 `one_more_rep` 스키마 **생성하지 않음**.
- Auth Redirect URLs 에 one-more-rep 도메인 **포함하지 않음**.
- 이 세션 workspace 에 폴더 없음(별도 저장소).

## 준수한 금지사항
- [x] qkiki 코드/ENV/Supabase 설정/migration 수정 안 함
- [x] one-more-rep 코드/ENV/Supabase 설정/migration 수정 안 함
- [x] wideget-core migration 에 `qkiki`, `one_more_rep` 스키마 미포함(코드로 검증)
- [x] 기존 프로젝트/데이터/테이블 삭제 안 함

## 확인 방법
```bash
# 통합 migration 에 제외 스키마가 없음을 확인
grep -iE 'qkiki|one_more_rep|one-more-rep' supabase/migrations/20260707120000_wideget_core_4app_unification.sql
# → (매칭 없음이 정상. 주석의 '생성하지 않음' 설명만 존재)
```
> 참고: workspace 에 qkiki/one-more-rep 폴더가 실제로 존재하지 않으므로, "폴더가 있으면 기록만" 이라는 지침에 따라 여기 목록에만 기록합니다.
