# NixOS 보안 강화 체크리스트

분석 원본:
- `~/org/botlog/20260304T134334` — XMRig 크립토재킹 대응 NixOS 방어전략
- `~/org/botlog/20260304T135152` — 임베디드 LLM 크립토재킹 방어 Yocto/NixOS

빌드 경로: `flake.nix` → `mksystem.nix` → `machines/<profile>.nix` → `shared.nix`
(`hosts/<profile>/configuration.nix`은 초기 설치 템플릿, **빌드에 미포함**)

---

## Oracle VM (공인 IP 노출 서버)

### P0 — 즉시 조치

- [x] **SSH 패스워드 인증 끄기** — `shared.nix`에서 `true`로 설정된 것을 `mkForce false` override
  - 적용: `machines/oracle.nix` — `PasswordAuthentication`, `KbdInteractiveAuthentication` 모두 끔
  - 커밋: `d9c393c`

- [x] **fail2ban 활성화** — SSH 무차별 대입 공격 차단
  - 적용: `machines/oracle.nix` — `maxretry=3`, `bantime=1h`, 점진적 증가 최대 7일
  - 커밋: `d9c393c`

### P1 — 조치 권장

- [x] **NOPASSWD sudo 제한** — `shared.nix`의 `ALL NOPASSWD` override
  - 적용: `machines/oracle.nix` — `wheelNeedsPassword = mkForce true`
  - NOPASSWD 허용 명령어: `systemctl`, `nixos-rebuild`, `nix-env`, `nix-collect-garbage`, `nix-store`
  - 나머지 모든 sudo 명령어는 패스워드 요구
  - 커밋: `d9c393c`, `c11d8f3` (nix 관리 명령어 추가)

- [x] **mosh UDP 60000-61000 포트 제거** — 22번 포트로 사용 중, 외부 UDP 불필요
  - 적용: `machines/oracle.nix` 방화벽에서 mosh 범위 제거
  - `shared.nix`의 mosh 포트는 개인 PC용이므로 유지
  - 커밋: `d9c393c`

### P2 — 검토 후 적용

- [ ] **커널 모듈 로딩 제한** — `security.lockKernelModules = true`
  - BYOVD 공격 차단 (부팅 후 모듈 로딩 금지)
  - 주의: Docker/iptables 등이 동적 모듈 필요 → 테스트 필수
  - 난이도: 중간 (필요 모듈 화이트리스트 파악 후)

- [ ] **사용자 cron 비활성화** — `services.cron.enable = false`
  - systemd 타이머만 허용 (선언적 관리)
  - 난이도: 낮음

- [ ] **Docker rootless 전환** — `virtualisation.docker.rootless.enable = true`
  - Docker 소켓 = root 권한 탈취 경로 차단
  - 난이도: 높음 (OpenClaw 컨테이너 마이그레이션 필요)

### P3 — 장기 개선

- [ ] **무결성 모니터링** — `/home` 의심 실행파일 탐지 (systemd timer)
- [ ] **CPU 이상 감지** — 크립토재킹 징후 모니터링 (load average 임계치)
- [ ] **채굴풀 도메인 차단** — `networking.extraHosts`로 known pool 차단
- [ ] **Syncthing relay 비활성화 검토** — 직접 연결 가능하면 relay 불필요

---

## shared.nix (전 디바이스 공통) — 검토 필요

### 현재 상태

| 항목 | 설정 | 비고 |
|------|------|------|
| SSH 패스워드 인증 | `true` ⚠️ | Oracle만 mkForce로 끔. 개인 PC는 열려 있음 |
| sudo | `ALL NOPASSWD` | Oracle만 mkForce로 제한. 개인 PC는 편의상 유지 |
| 방화벽 | `enable = true` ✅ | TCP 22, 22000만 허용 |
| mosh 포트 | UDP 60000-61000 ✅ | 개인 PC에서는 필요 |

### 향후 검토

- [ ] **shared.nix SSH 패스워드 인증 기본값을 `false`로 변경** 고려
  - 각 디바이스에서 필요 시 `true`로 override하는 게 더 안전한 기본값
  - 현재는 반대 방향 (기본 `true`, oracle만 `false`)

---

## 회사 클러스터 (hej-nixos-cluster) 🚨

| 항목 | 설정 | 위험도 |
|------|------|--------|
| **방화벽** | `enable = false` (2025-08-04~) | 🚨 즉시 대응 필요 |

- 파일: `modules/common/networking.nix`
- Cloudflare Zero Trust가 외부 경계를 지키지만, 사내망 lateral movement에 무방비
- GPU 클러스터(RTX 5080 × 3)는 크립토재킹 최적 타겟
- **상세 검토 → `~/repos/work/hej-nixos-cluster/SECURITY.md`**

---

## 잘 되어 있는 것 (변경 불필요)

- `PermitRootLogin = "no"` — root SSH 접속 차단 (shared.nix)
- 방화벽 활성화 (shared.nix, oracle.nix)
- Syncthing GUI `127.0.0.1` 바인딩 — 외부 접근 불가
- 불필요 서비스 비활성화 — avahi, printing, libinput (oracle.nix)
- TCP BBR 혼잡 제어 (oracle.nix)
- NixOS 구조적 방어 — `/nix/store/` 불변, 선언적 서비스, `flake.lock` 해시 고정

---

## 적용 이력

| 날짜 | 항목 | 커밋 | 대상 |
|------|------|------|------|
| 2026-03-05 | P0: SSH 패스워드 끄기 + fail2ban | `d9c393c` | oracle |
| 2026-03-05 | P1: sudo 제한 + mosh 포트 제거 | `d9c393c` | oracle |
| 2026-03-05 | fix: nix 관리 명령어 NOPASSWD 추가 | `c11d8f3` | oracle |
