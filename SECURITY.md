# Oracle VM 보안 강화 체크리스트

분석 원본: `~/org/botlog/20260304T134334--임베디드-llm-시대의-크립토재킹-방어` (힣봇 분석)

빌드 경로: `flake.nix` → `mksystem.nix` → `machines/oracle.nix` → `shared.nix`
(`hosts/oracle/configuration.nix`은 초기 설치 템플릿, **빌드에 미포함**)

## P0 — 즉시 조치

- [x] **SSH 패스워드 인증 끄기** — `shared.nix:335`에 `true`, oracle에 override 없음
  - 위치: `machines/oracle.nix`에 `PasswordAuthentication = false` 추가
  - 위험: 인터넷에 22번 포트 노출 + 패스워드 인증 = 무차별 대입 공격 대상

- [x] **fail2ban 활성화** — 설정 어디에도 없음
  - 위치: `machines/oracle.nix`에 `services.fail2ban` 추가
  - NixOS 모듈 제공, 설정 난이도 낮음 (5줄)

## P1 — 조치 권장

- [x] **NOPASSWD sudo 제거 (oracle만)** — `shared.nix:81-94` 이중 설정
  - oracle만 sudo 패스워드 요구, 개인 PC는 현행 유지
  - 위치: `machines/oracle.nix`에 override

- [x] **mosh UDP 60000-61000 포트 제거** — 22번 포트로 사용 중, 외부 포트 불필요
  - 위치: `machines/oracle.nix` 방화벽에서 mosh 범위 제거
  - `shared.nix`의 mosh 포트는 개인 PC용이므로 유지

## P2 — 검토 후 적용

- [ ] **커널 모듈 로딩 제한** — `security.lockKernelModules = true`
  - BYOVD 공격 차단 (부팅 후 모듈 로딩 금지)
  - 주의: Docker/iptables 등이 동적 모듈 필요할 수 있음 → 테스트 필수
  - 난이도: 중간 (필요 모듈 화이트리스트 파악 필요)

- [ ] **사용자 cron 비활성화** — `services.cron.enable = false`
  - systemd 타이머만 허용 (선언적 관리)
  - 난이도: 낮음

- [ ] **Docker rootless 전환** — `virtualisation.docker.rootless.enable = true`
  - Docker 소켓 = root 권한 탈취 경로 차단
  - 난이도: 높음 (기존 컨테이너 마이그레이션 필요)

## P3 — 장기 개선

- [ ] **무결성 모니터링** — `/home` 의심 실행파일 탐지 (systemd timer)
- [ ] **CPU 이상 감지** — 크립토재킹 징후 모니터링
- [ ] **채굴풀 도메인 차단** — `networking.extraHosts`로 known pool 차단
- [ ] **Syncthing relay 비활성화 검토** — 직접 연결 가능하면 relay 불필요

## 잘 되어 있는 것 (변경 불필요)

- `PermitRootLogin = "no"` — root SSH 접속 차단
- 방화벽 활성화 (`networking.firewall.enable = true`)
- Syncthing GUI `127.0.0.1` 바인딩
- 불필요 서비스 비활성화 (avahi, printing, libinput)
- TCP BBR 혼잡 제어
- 포트 80/443 — Caddy 리버스 프록시 (의도적 설계)

## 적용 이력

| 날짜 | 항목 | 커밋 |
|------|------|------|
| 2026-03-05 | P0+P1 최초 적용 | — |
