# NEXT — upgrade/nixos-2605

> 브랜치 전용 핸드오프. main 병합 전 이 파일 삭제(내용은 ROADMAP.md로 승격).
> 목표: **25.11(deprecated) → 26.05** 이관 + **pnpm 단일화** + **오버레이 대청소** + **외부패키지 SSOT화**.

## NOW — oracle 26.05 switch 완료, 리부팅 검증 중 (2026-07-02 밤 23시)

**switch DONE** — 라이브 `26.05.20260630.95ca1e2 (Yarara)`, **gen #59 current, #58(25.11) 롤백 보존**. switch-to-configuration exit 4는 양성(dbus-broker/syncthing-init/vconsole live-reload 레이스 — 지금 전부 `active`, `systemctl --failed` 비어있음). 컨테이너 12개 자동복구 + caddy 6-세트 GREEN(comments 루트 404는 정상, `/ping`=pong·`/web/`=200) + openclaw 6봇(main/bbot/glg/gemini/mini/gpt) 재기동 healthy.

### 리부팅 후 (다음 세션에서) 확인/할 일 — 순서 중요
1. **콜드부팅 검증**: `nixos-version`=26.05 · `systemctl --failed` 비어야 · 컨테이너 12개(openclaw 포함) 자동 Up · caddy 6-세트(agenda/analytics/comments/forge/ha/map) 200/302 · 봇 라이브 turn 1회.
2. **그다음에야 #58 삭제**: 부팅 GREEN 확인 후 `sudo nix-collect-garbage --delete-older-than 3d`(또는 run.sh C))로 25.11 closure 대량 회수. ⚠️ **부팅 검증 전엔 절대 #58 지우지 말 것**(원격 VM의 유일 롤백 표면 — 금지 섹션 참조).
3. **task B — gog 봇 컨테이너 설치**(아래 §0.7): switch가 해결 안 함. Dockerfile **2개** + arm64 tarball. 별도 사이클.

> GC 이력(2026-07-02 밤, #58 보존 안전 GC): docker builder 1.0G + dangling 122M → 9.2G→**12G(88%)**. journal vacuum은 `sudo journalctl`이 NOPASSWD 밖이라 skip. 대량 회수(#58 25.11 closure)는 부팅 검증 후로 유보.

## DONE — 이번 세션 (전부 커밋됨)

| 커밋 | 내용 | push |
|---|---|---|
| fa52acf | 26.05 이관 + 오버레이 전면 삭제 + pnpm 단일화 | ✅ |
| 938b513 | picom v13 / flameshot deprecated 정리 | ✅ |
| 291cf4c | EXTERNAL_PACKAGES SSOT 일원화 + ghostty confirm-close false | ⬜ **push 필요** |
| 7d9af7e | run.sh e)/E) 외부패키지 SSOT 배선 | ⬜ **push 필요** |

- **thinkpad 26.05 switch + 재부팅 완료.** eval/picom 경고 0. pnpm 단일 **11.9.0**.
- 오버레이 전부 삭제(`overlays=[ ]`), input=nixpkgs/disko/home-manager만. nodejs_/python312 → 그냥 이름.
- pnpm 설정: `~/.config/pnpm/rc`(manage-package-manager-versions=false + global-bin-dir), sessionPath 부모 제거.
- **EXTERNAL_PACKAGES.md = pnpm 글로벌 SSOT** (`~/update-claude.sh` 폐기).
  - pnpm 유지: netlify-cli / clawhub / @steipete/summarize / typescript(+lsp) / (pi 최초 1회)
  - curl self-updater(무조건 이 버전): claude / codex / antigravity — URL 3종 문서에 기록
  - gog = 포크 로컬빌드(`~/repos/gh/gogcli`, go.mod=upstream이라 go install 불가)
  - 제거: gemini / ccr / copilot / cline / @mariozechner gccli·gdcli·gmcli / grammy
- **Phase A 재설치 완료**: netlify 26.1.0 / clawhub 0.23.1 / summarize 0.20.1 / ts+tsls / pi 0.80.3 → v11+bin/.
- **디스크 정리 B/C/D 완료** (thinkpad, 2026-07-02): 여유 38G(92%)→**53G(88%)**, /nix 113G→102G.
  - B: pnpm 글로벌 SSOT 밖 4개(codex/gemini/claude-agent-acp/codex-acp) remove + global/5(1.9G)·.tools(79M)·parent orphan shim purge → v11 글로벌이 정확히 SSOT 6개.
  - C: `pnpm store prune` 3.38GB. D: nix GC 9.5GB + journal 134M.
- **외부패키지 리팩터 완료**: 목록을 run.sh에서 분리 → `scripts/external-packages.sh`(SSOT, 주석 통합).
  `EXTERNAL_PACKAGES.md` 삭제, run.sh e)/E)는 스크립트 호출만. **gog는 upstream go install**(fork 0.12→upstream v0.31.1 확인). 쓰레기 제거: gt/bd/bv/br·CLIProxyAPI.

## PENDING 결정 (사용자 답 필요)

1. **Mod+m (Emacs scratchpad) 회귀**: 데몬·`emacsclient -s user`·scratchpad-toggle 스크립트 다 정상 확인됨(버전 불일치 아님, emacs 30.2). **정확한 증상 필요**(무반응? 프레임은 뜨는데 scratchpad로 안 가나? 에러?). 바인딩: `users/junghan/modules/i3.nix:488`.


## 0.7 gog (gogcli) — 봇 필수, oracle Docker 설치 대기 (2026-07-02)

**gog는 봇에게 필수** — 가족봇이 캘린더 접근/역할 수행에 씀(day-query·recall·commit 스킬의 `gog chat` 등 Workspace 호출). 근데 **oracle 봇 컨테이너엔 지금 gog가 없다**. 원인: 과거 스킬 폴더 번들 바이너리가 **amd64**라 oracle(aarch64)에서 실행 불가 → 봇의 gog 호출이 그동안 조용히 실패해온 것. **오라클 가서 Docker 이미지에 넣어야 함.**

### 이 세션에서 검증된 제약 (설치 방식이 이걸로 정해짐)
- **호스트 `~/.local/bin/gog`(upstream v0.31.1)는 컨테이너로 못 옮김** — Nix glibc에 동적 링크(`interpreter /nix/store/...glibc/ld-linux`)라 node 베이스 컨테이너엔 그 경로 없음 → 마운트/복사 시 즉시 깨짐. **이미지가 제 방식으로 넣어야 한다.**
- **upstream이 arm64 프리빌트 릴리스를 냄** (`gh release view -R steipete/gogcli`로 확인): `gogcli_0.31.1_linux_arm64.tar.gz` (내부: `gog` 바이너리 top-level). → **Go 툴체인 불필요, tarball 한 줄.** (`go install`보다 가벼움)
- **런타임 OAuth 시크릿 필요** — `gog`는 `~/.config/gogcli/config.json` + keyring(file backend)에 계정 토큰 필요. 이건 **시크릿 → 이미지에 굽지 말고 마운트** (summarize의 config.json은 비밀 아닌 model id라 구운 것과 대조).

### 다음 한 걸음 (오라클에서)
- [ ] **Dockerfile에 gog 추가** — summarize `npm install -g` 자리 근처(L133 블록). ⚠️ **정정(2026-07-02 실측): 동기 Dockerfile은 3개가 아니라 2개** — `~/openclaw/Dockerfile` + `docker/openclaw/Dockerfile`(현재 byte-identical). `openclaw-config/Dockerfile`은 oracle에 **없음**. gog `RUN`은 **`USER node`(L162) 앞 root 구간**에 넣어야 `/usr/local/bin` 쓰기 가능:
  ```dockerfile
  ARG GOG_VERSION=0.31.1
  ARG TARGETARCH
  RUN curl -fsSL "https://github.com/steipete/gogcli/releases/download/v${GOG_VERSION}/gogcli_${GOG_VERSION}_linux_${TARGETARCH}.tar.gz" \
        | tar -xz -C /usr/local/bin gog && gog --version
  ```
  (버전 핀 = 재현성 + `latest` GitHub API rate-limit 회피. node-gyp hang과 무관 — native 빌드 아님.)
  ⚠️ `${TARGETARCH}`는 BuildKit이 채우는 값 — 레거시 빌더(`DOCKER_BUILDKIT=0`)면 빈값 → URL 깨짐. 단일 aarch64 네이티브 빌드니 **`arm64` 하드코드가 더 안전**(arm64 tarball 실존 확인: `gogcli_0.31.1_linux_arm64.tar.gz`).
- [ ] **OAuth creds 마운트** — 봇 계정(개인 `junghanacs@gmail.com` 또는 전용 봇 계정 — **GLG 결정**)의 `~/.config/gogcli`를 컨테이너 node 유저 홈(`/home/node/.config/gogcli`)으로 마운트(ro 권장), `chown node`. 이미지에 굽지 말 것. `GOG_HOME`/`--home`으로 경로 오버라이드 가능.
- [ ] **재빌드 후 검증** — `docker exec openclaw-gateway gog --version` + 실제 `gog calendar ...` 1회 + 봇 라이브 turn에서 캘린더 응답 확인.
- [ ] **run.sh `k)` SKILL_EXCLUDE엔 gogcli 넣지 말 것** — 봇이 쓰니 배포 유지. (branch 2 "제외" 안은 폐기 — GLG: 봇 필수 확정.) agent-config 쪽 `skills/gogcli/SKILL.md`는 `{baseDir}/gog`→PATH `gog` 호출로 전환(이미 담당자에 핸드오프). 이미지에 gog 들어오면 컨테이너 PATH(`/usr/local/bin/gog`)에서 resolve.

> 배경(호스트측 SSOT): thinkpad/laptop/nuc의 gog는 `nixos-config/scripts/external-packages.sh`(`run.sh E) 3`, upstream `go install`)가 관리. 포크(`junghan0611/gogcli`) 폐기·upstream이 최신(0.12→0.31.1 확인). oracle 컨테이너만 별도 배포 타겟.

---

## 이후

- **zmx 재도입**: 이번 제외(zmx flake zig15 ↔ 26.05 zig16). zig16 빌드 확인 후 재추가. 현재 `zmx` 부재.

## 이미 해결된 26.05 회귀 (참고)

ollama acceleration→package / neofetch→fastfetch / xorg·xfce→top-level / nixfmt-classic→nixfmt /
gnome·gdm 옵션 rename / neovim withRuby·withPython3·gtk4.theme legacy 고정 / picom v13 6개 / flameshot checkForUpdates / ghostty confirm-close-surface.

## 금지

- oracle 먼저 switch 금지(검증된 x86 통과 후 최후). `~/.npmrc`(auth 토큰) home-manager로 덮지 말 것.
- **switch _후_ `run.sh C)` 재실행 금지** — C)=`nix-collect-garbage --delete-older-than 3d`. switch 후엔 gen #58(25.11, 현재 롤백 표면)이 non-current+>3d가 되어 삭제됨 → 롤백 소멸. switch _전_ 1회만 안전(그땐 #58이 current라 nix가 보호).
- **caddy·authelia는 repo 워킹트리를 라이브 마운트** (`docker/caddy/Caddyfile`, `docker/authelia/{users.yml,configuration.yml}`) — git 조작이 이 파일을 바꾸면 라이브 인증/프록시가 영향받음. 이 브랜치는 저 파일 안 건드림(checkout 무영향 실측 확인)이나 switch/merge/편집 시 주의. (스킬의 "docker/*=백업/레퍼런스" 문구는 oracle에선 부정확 → 정정 대상.)
- Phase B `rm -rf`는 되돌릴 수 없음 — global/5·.tools만, store/·bin/·global/v11 건드리지 말 것.
