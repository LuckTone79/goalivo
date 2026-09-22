# wideget-core — Auth Redirect URLs

> Supabase Dashboard → Authentication → URL Configuration → **Redirect URLs** 에 등록할 목록.
> ⚠️ 실제 운영 도메인을 확정하지 못했습니다. 아래 placeholder 는 **확인 필요** 이며 실제 도메인으로 교체해야 합니다.
> `qkiki`, `one-more-rep` 의 redirect 는 **여기에 포함하지 않습니다**(독립 프로젝트).

## 1. Site URL
- 대표 앱(예: Goalivo) 운영 도메인 1개를 Site URL 로 지정. → `확인 필요`

## 2. Redirect URLs (앱별)

Goalivo 는 OAuth redirect 를 `window.location.origin + window.location.pathname` 로 동적 생성하므로, **앱이 실제로 서비스되는 origin/경로**를 모두 등록해야 합니다.

| 앱 | 로컬 개발 | 프로덕션 | 상태 |
|---|---|---|---|
| Goalivo | `http://localhost:3000/**` | `https://<goalivo-domain>/**` | 도메인 `확인 필요` |
| castfolio | `http://localhost:3000/**` | `https://<castfolio-domain>/**` | 저장소/도메인 `확인 필요` |
| kadit | `http://localhost:3000/**` | `https://<kadit-domain>/**` | 저장소/도메인 `확인 필요` |
| locawing | `http://localhost:3000/**` | `https://<locawing-domain>/**` | 저장소/도메인 `확인 필요` |

> Supabase Redirect URLs 는 와일드카드(`**`)를 지원합니다. SPA(해시/경로 이동)에는 `https://<domain>/**` 형태가 안전합니다.
> 각 앱이 별도 포트/도메인으로 로컬 개발한다면 해당 포트도 각각 등록하세요.

## 3. Google OAuth (해당 시)
- Google Cloud Console → OAuth 2.0 Client → **Authorized redirect URIs** 에:
  - `https://<wideget-core-ref>.supabase.co/auth/v1/callback`  ← Supabase 콜백(프로젝트 1개이므로 공통)
- Supabase Dashboard → Auth → Providers → Google 에 동일 Client ID/Secret 등록.

## 4. 등록 후 확인
- [ ] 각 앱에서 Google 로그인 → 리디렉트가 원래 앱으로 정상 복귀하는지 확인.
- [ ] 이메일 인증(회원가입) 메일의 confirm 링크가 Site URL 기준으로 열리는지 확인.

## 5. 확인 필요 항목 (사용자 입력 대기)
- [ ] Goalivo 프로덕션 도메인
- [ ] castfolio 프로덕션 도메인
- [ ] kadit 프로덕션 도메인
- [ ] locawing 프로덕션 도메인
- [ ] 각 앱 로컬 개발 포트(기본 3000 가정)
