# Goalivo Google OAuth 검증 제출값

최종 갱신: 2026-04-27 (Asia/Seoul)

## 1) 이미 적용 완료(에이전트 수행)

- 프로덕션 배포: `https://goalivo.widegetlab.com`
- 개인정보처리방침 페이지 생성/배포:
  - `https://goalivo.widegetlab.com/privacy.html`
- 서비스 약관 페이지 생성/배포:
  - `https://goalivo.widegetlab.com/terms.html`
- 홈페이지에서 정책 링크 노출:
  - `index.html` 하단 고정 법적 링크 바 추가

## 2) Google Auth Platform > Branding 입력값

- Application name: `Goalivo`
- User support email: `luck2s7912@gmail.com`
- Application home page: `https://goalivo.widegetlab.com/`
- Application privacy policy link: `https://goalivo.widegetlab.com/privacy.html`
- Application terms of service link: `https://goalivo.widegetlab.com/terms.html`
- Developer contact information email: `luck2s7912@gmail.com`

## 3) Authorized domains (상위 도메인 기준)

- `widegetlab.com`
- `supabase.co`

## 4) OAuth Client 설정 체크

Google OAuth 클라이언트(웹 타입)에서 최소 아래 Redirect URI 포함:

- `https://ossqwphalaxhmadmffsn.supabase.co/auth/v1/callback`

필요 시 운영 URL도 추가:

- `https://goalivo.widegetlab.com`

## 5) Data Access(Scopes) 등록값

코드에서 실제 요청 중인 스코프:

- `openid`
- `email`
- `profile`
- `https://www.googleapis.com/auth/calendar.events.readonly`
- `https://www.googleapis.com/auth/calendar.app.created`

참고: Google 로그인은 기본 프로필 범위만 요청하고, Google Calendar 연결 시점에만 Calendar 범위를 별도로 요청함.

## 6) 검증 제출 설명문(붙여넣기용)

### App functionality

Goalivo is a goal-oriented planning calendar web app. Users sign in, create goals and schedules, and optionally connect Google Calendar to import events and write user-approved planning blocks to an app-created calendar.

### Why each Google scope is needed

- `openid`, `email`, `profile`: Required for Google sign-in and account identity.
- `calendar.events.readonly`: Required to read the user's calendar events for schedule overlay and planning context.
- `calendar.app.created`: Required to create an app-specific secondary calendar and create/update planning events only inside calendars created by Goalivo.

### Data handling summary

User data is used only to provide core app features (authentication, calendar sync, planning). Data is not sold. Users can revoke access anytime from Google Account permissions.

## 7) 제출 전 점검 체크리스트

- [ ] Branding 페이지의 홈/개인정보/약관 URL 모두 저장됨
- [ ] Authorized domains에 `widegetlab.com`, `supabase.co` 등록됨
- [ ] Audience가 External + In production 상태임
- [ ] Data access에 위 5개 scope 등록됨
- [ ] Verification Center에서 Branding 검증 요청
- [ ] 이어서 Data Access(Scopes) 검증 요청

## 8) 변경 시 재검증 필요 항목

아래 변경 시 Google 재검증이 필요할 수 있음:

- 앱 이름/로고
- 홈페이지 URL
- 개인정보처리방침 URL
- 서비스 약관 URL
- 요청 scope 추가/변경
