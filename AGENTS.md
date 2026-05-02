# Goalivo Version & Report Policy (Permanent)

This policy is mandatory for any update in this repository scope.

## Required On Every Update

1. Bump app version exactly once per completed change set.
2. Use version format: `vYYYY.MM.DD-NN`.
3. If multiple updates happen on the same day, increase `NN` sequentially from `01`.
4. Update the app version constant in code (current source: `APP_VERSION` in `index.html`).
5. Create a report file at project root sibling folder: `../Report/report_<APP_VERSION>.md`.
6. Write the report in Korean and include:
   - 버전
   - 작업일시
   - 변경 요약
   - 변경 파일 목록
7. Keep current version visible in app settings/info UI.

## Validation Before Finish

- Confirm `APP_VERSION` matches the report filename version.
- Confirm report file exists in `../Report/`.
- Confirm settings/info section still renders current version text.
