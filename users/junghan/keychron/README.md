# Keychron 키맵 백업

ZMK 키보드(Keychron Launcher / ZMK Studio) export 파일 보관소.

- **SSOT는 키보드 펌웨어 + Keychron Launcher**(`launcher.keychron.com`).
  여기 JSON은 *백업·재현용 스냅샷*이지 빌드에 쓰이지 않는다(빌드 무관, no-op).
- 키맵을 바꾸면 Launcher에서 **Export → 이 폴더에 같은 이름으로 덮어쓰기 → 커밋**.
- 복원: Launcher에서 **Import**로 해당 JSON 선택.
- 파일명 규칙: Launcher가 주는 이름 그대로 쓰되 **공백은 `-`로** 치환.

## 파일

| 파일 | 키보드 | 비고 |
|---|---|---|
| `Keymap-V10-Pro-ZMK-ANSI-Knob-18-8-4.json` | Keychron V10 Pro (ZMK, ANSI, Knob) | USB `3434:13a8` |

## 관련

- hidraw 접근 udev rule: `machines/shared.nix` (Keychron VID `3434`, `GROUP=input`)
- 운영 메모: `NEXT.md` §10
