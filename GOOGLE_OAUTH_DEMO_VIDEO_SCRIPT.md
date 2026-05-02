# Goalivo Google OAuth 데모 영상 스크립트

최종 갱신: 2026-04-27

Google 검증팀 제출용 데모 영상은 `영어 UI`, `전체 OAuth 동의 화면`, `요청 스코프`, `실제 기능 사용 흐름`이 모두 보여야 합니다.

## 영상 준비

- 브라우저 언어 또는 Google 동의 화면 언어를 `English`로 설정
- 시크릿 창 또는 로그아웃 상태에서 시작
- 사용할 계정은 테스트용 Google 계정 권장
- 촬영 시간 목표: 2분 ~ 4분

## 화면 순서

1. 홈페이지 열기
- URL 표시: `https://goalivo.widegetlab.com/`
- 홈 화면에서 앱 이름 `Goalivo`가 보이도록 촬영
- 하단 또는 설정에서 `Privacy Policy`, `Terms of Service` 링크가 보이게 잠깐 보여주기

2. 앱 기능 소개
- Goalivo가 goal planning and calendar scheduling app 임을 짧게 보여주기
- 로그인 버튼 또는 설정 페이지의 Google 연동 진입점 보여주기

3. Google 로그인 시작
- `Login with Google` 또는 Google Calendar connect 버튼 클릭
- Google OAuth consent screen 전체가 보이도록 촬영
- 앱 이름 `Goalivo`가 표시되는지 확인

4. 요청 스코프 보여주기
- 동의 화면에서 scope 설명이 보이도록 천천히 스크롤
- 최소 아래 항목이 보여야 함
  - basic profile / email
  - view calendars
  - edit calendar events

5. 동의 후 앱 복귀
- Google 계정 선택
- 동의 완료 후 Goalivo로 돌아오는 흐름 촬영

6. 스코프 사용 기능 시연
- Google Calendar events import 실행
- 일정이 앱 캘린더에 overlay 되는 모습 보여주기
- 앱에서 계획 블록을 생성한 뒤 Google Calendar로 내보내기 또는 동기화 기능 시연
- Google Calendar에서 생성/변경 결과가 반영되는 화면까지 보여주면 가장 좋음

7. 종료 장면
- 설정 또는 계정 영역에서 연동 상태가 보이는 화면으로 마무리

## 영상 중 말할 내용 예시

This is Goalivo, a goal planning and scheduling web app.
Users sign in with Google to connect their account.
We request basic identity scopes for sign-in, calendar.readonly to import a user's calendar events for planning context, and calendar.events to create or update planning events only when the user explicitly chooses to sync them to Google Calendar.
The imported data is used only for user-facing scheduling features inside Goalivo.

## 제출 전 체크

- 동의 화면 언어가 영어인지
- 앱 이름이 `Goalivo`로 보이는지
- 요청 스코프가 실제 제출 scope와 일치하는지
- 앱 URL, 개인정보처리방침 URL, 약관 URL이 현재 운영 도메인과 일치하는지
