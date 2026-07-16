---
name: nixos-config
description: "nixos-config 오퍼레이터의 운영 면 — oracle/nuc/laptop/thinkpad 멀티 디바이스 NixOS + oracle에 사는 OpenClaw 봇 런타임을 실제로 손볼 때. AGENTS.md가 '현재 상태', NEXT.md가 '할 일', ROADMAP.md가 '이력'을 담는다면 이 스킬은 그 문서들이 front-load 못 하는 운영 반사신경을 담는다: 자리(디바이스) 인식 먼저, run.sh 엔트리, oracle/openclaw 분리 원칙, rebuild/rollback, OpenClaw 업그레이드(Dockerfile FROM 한 줄 + doctor read-only), caddy 변경 시 7-세트 검수, 봇 스킬 심볼릭 배포, 커밋/스탬프/git-hooks 규율. 트리거: 'nixos-config', 'nixos-rebuild', 'rebuild', 'switch', 'rollback', 'flake update', 'oracle', 'openclaw', '봇 업그레이드', 'caddy', 'geworfen', 'authelia', 'agenda 안돼', '디바이스', 'run.sh', '롤백', 'nixos 정리'."
user_invocable: true
---

# nixos-config — 오퍼레이터의 운영 면

Repo: `~/repos/gh/nixos-config` (심볼릭 → `/home/junghan/nixos-config`, 같은 real dir).
멀티 디바이스 NixOS(`oracle`/`nuc`/`laptop`/`thinkpad`) + **oracle에 사는 OpenClaw 봇 런타임**을
운영하는 자리. `AGENTS.md`(현재 상태)·`NEXT.md`(할 일)·`ROADMAP.md`(이력)이 *무엇/언제*를
담는다면, 이 스킬은 그 문서들이 못 담는 **매번 다시 당하는 운영 반사신경**을 담는다.

> ⚠️ 이건 generic NixOS 문서가 아니다. **이 repo 오퍼레이터의 핸드북**이다.
> 실사용자(가족 포함)가 oracle 봇에 의존한다 — oracle 작업은 service reliability 작업이다.

## 0. 자리 인식 먼저 (correctness starts here)

어느 디바이스인지 모르면 아무것도 하지 마라. SessionStart hook이 `device=`/`time_kst=`를 준다.
안 보이면:
```bash
cat ~/.current-device
TZ='Asia/Seoul' date '+%Y%m%dT%H%M%S'
```
`run.sh` normalization: `oracle-nixos` → `oracle` (첫 `-` 앞 토큰 = flake profile 이름).

**핵심 분리 원칙**: `oracle`이 아니면 OpenClaw를 볼 필요가 없다. oracle/openclaw 작업이 아니면
`ORACLE.md`를 열지 마라 — `AGENTS.md`만으로 충분하다.

## 1. 문서 라우팅 — 뭘 열까

| 작업 맥락 | 펼칠 문서 |
|---|---|
| oracle 디바이스 또는 OpenClaw 관련 | `ORACLE.md` (ownership·model routing·env/secret·업그레이드·함정) |
| thinkpad 로컬 AI (Ollama) | `THINKPAD.md` |
| nuc/laptop 일반 NixOS | `AGENTS.md` + 표준 NixOS 흐름 |
| OpenClaw 함정 카탈로그 | `docs/openclaw-gotchas.md` |
| 지금 무슨 상태인가 | `AGENTS.md` (날짜 박히면 → ROADMAP로 이관 신호) |
| 앞으로 할 일·후속 검증 | `NEXT.md` (끝난 항목 지우고 새 후속 추가) |
| 어떻게 여기까지 왔나(버전·결정 이력) | `ROADMAP.md` |
| 라이브 봇 런타임 SSOT | `~/openclaw/` (config/auth/workspaces — **커밋 금지**) |

## 2. run.sh — 오퍼레이터 엔트리

사람+에이전트 공용 인터페이스. 이미 `run.sh` 경로가 있는 작업이면 중복 만들지 말고 확장하라.
범위: flake update, rebuild/switch/rollback, cleanup, Oracle service helper, OpenClaw
tunnel/restart/status/pairing, skill deploy(`k)`). 상세 oracle helper는 `ORACLE.md` §7.

`br` 쓰지 마라. rigid tracker 대신 **agenda 스탬프**를 쓴다(이 repo 선호).

## 3. 표준 rebuild / rollback (nuc/laptop/thinkpad)

```bash
sudo nixos-rebuild switch --flake .#<profile>   # profile = oracle|nuc|laptop|thinkpad
```
문제 시 rollback: `run.sh` 또는 `sudo nixos-rebuild switch --rollback`. NixOS는 generation이
롤백 표면이다. 디스크 여유 부족하면(oracle 특히) 정리부터 — `run.sh C)` prune.

## 4. oracle / openclaw 작업 (safety-critical)

라이브 truth = `~/openclaw/`. 공개 백업/레퍼런스 = `docker/openclaw/`, `docker/*`. 절대
secret/auth를 공개 repo로 새게 하지 마라. 자세한 건 `ORACLE.md`. 자주 쓰는 반사신경만:

- **OpenClaw 업그레이드 = Dockerfile `FROM` 한 줄 bump**: `~/openclaw/Dockerfile` +
  `docker/openclaw/Dockerfile` 둘 다 `ghcr.io/openclaw/openclaw:X → :Y` + 업글 로그 주석 →
  재빌드 → `up -d --force-recreate`. codex/claude-cli 플러그인은 stock(번들)이라 자동으로 따라옴.
- **업글 후 doctor는 read-only만, `--fix` 금지** — `doctor --fix`가 gemini를 `google/`
  금지경로로 드리프트시킨다(6.9에서 확정). surgical `config set/unset`으로만 정리.
- **6봇 모델 prefix 전수 재확인** (특히 gemini `google-gemini-cli/` 유지), claude-cli 3봇
  (main/bbot/mini) Anthropic auth GREEN, memory 4096d, glg/gpt `fallbacks` 빈 상태.
- **모델은 claude-cli 봇이면 카탈로그 등록만으로 태운다** — `agentRuntime claude-cli`는 구독
  API에서 모델을 동적 해결(예: Sonnet 5 = `anthropic/claude-sonnet-5` + primary, 재빌드 불필요).
  서빙 미보장 모델을 primary로 박지 말 것(auto-fallback catch-all이 정체성 훼손).
- **gemini 403 = agy(Antigravity) 이관 대기** — 안 쫓고 DOWN 유지. api-key(`google/`) 폴백 금지.

## 5. 반사신경 — 다시 당하지 말 것

- **caddy 변경 = 7-세트 검수 필수**: `docker/caddy/Caddyfile` 건드리면(특히 `docker restart
  caddy`) caddy-fronted 전부를 세트로 확인 — comments/analytics/agenda/ha/forge/map/ax. 하나만
  보고 넘기지 마라. (`docs/openclaw-gotchas.md` "caddy 변경 = 7-세트 검수" 참조)
- **ax.junghanacs.com = 첫 static vhost(관리 대상)**: 기존 6개는 `reverse_proxy`지만 ax는
  백엔드 없이 caddy `file_server`가 `/srv/ax`(호스트 `docker-data/ax` ro 마운트)를 직접 서빙.
  web root는 junghan0611 repo `apply/ax make publish`가 채운다(재시작 불요, 즉시 라이브·leak
  gate 유일 관문). **compose 볼륨 추가/제거는 `restart` 아니라 `up -d --force-recreate`**.
  향후 umami/remark는 정본에 스니펫으로(caddy 주입 금지). ax 요청은 이 레인이 대응.
- **agenda 000 ≠ caddy**: `agenda.junghanacs.com`(geworfen)은 호스트 emacs `server` 데몬에
  의존한다. 데몬 hang이면 caddy와 무관하게 agenda 000. `emacsclient -s server --eval '(+ 1 1)'`
  타임아웃이면 데몬이 근인. 복구는 **geworfen 담당자에게 entwurf 핸드오프** — 호스트 데몬을
  nixos-config에서 직접 만지지 마라.
- **Caddyfile 편집 후 reload 아니라 `docker restart caddy`**: single-file bind-mount inode
  함정 — atomic rename이 새 inode를 만들어 `caddy reload`가 "unchanged"로 무시한다. 재시작 후
  `docker exec caddy grep <domain> /etc/caddy/Caddyfile`로 컨테이너가 새 내용을 보는지 확인.
- **봇 스킬은 심볼릭 배포** — workspace 스킬을 sibling repo SSOT(예: butlercli)로 절대 심볼릭.
  봇이 고친 게 SSOT로 흐르고 SSOT 수정이 봇에 즉시 반영(redeploy 불필요). 이중 마운트 덕에
  `/home/junghan/...` 절대경로가 host·container 양쪽 resolve. (`NEXT.md` "스킬 심볼릭 배포")
- **디스크 보수적으로** — oracle storage 빠듯. 업글 사이클마다 dangling image + build cache
  누적 → `run.sh C)` 정기 prune (`docker system df` 명목치 ≠ 실 회수량, builder prune이 본 회수원).
- **restart vs recreate — "무엇을 바꿨느냐"로 가른다** (매번 까먹는 지점):
  - **env/mount 변경 → `up -d --force-recreate`**. `docker compose restart`는 기존 env 재사용, recreate만 새 env·볼륨 픽업.
  - **config 파일(`~/openclaw/config/openclaw.json`) 변경 → `docker compose restart openclaw-gateway`로 충분.** restart도 gateway 프로세스·manager cache·Node compile state를 콜드 리셋한다. config-only에 recreate는 과하다(느리고 불필요하게 더 깊은 콜드). recreate는 env/mount일 때만.
- **restart/recreate 후 memory prewarm** — 콜드 첫 `memory_search`는 세션 전수 스캔(glg 808 files/211MB, ARM)으로 15s 하드타임아웃(`memory-core` tools.ts 하드코딩, config로 못 늘림)에 걸릴 수 있다. gateway healthy 뒤 각 봇에 `openclaw agent --agent <id> --session-key "agent:<id>:prewarm-$(date +%s)" --message '기억 검색' --timeout 60`을 (텔레그램 발송 없이) 한 번 돌려 **봇이 콜드를 대신 맞게** 하면 실제 유저는 웜만 만난다. 1차 방어는 인덱스 정비(dirty:no 유지 — family-turns 스킬 memory 섹션): 정비돼 있으면 콜드도 15s를 버틴다(2026-07-16 실측, 정비 후 콜드 3연속 성공). upstream PR로 timeout 늘리는 건 안 한다 — 운영으로 커버(GLG 결정).

## 6. 커밋 / 릴리즈 규율

- 커밋 전 `commit` 스킬, 릴리즈 전 `tag-release` 스킬. 로그 깨끗하게(“Generated with Claude”·
  Co-Authored-By 금지). 에이전트는 commit workflow에서만 커밋, **push는 GLG**.
- **git-hooks 안전벽** (global `core.hooksPath`): 공개 repo(`junghan0611/*`·`junghanacs/*`)
  added line의 **정체성 용어** + 모든 repo의 **secret**를 차단. nixos-config는 공개 repo다 —
  실제 이메일/비번/토큰을 커밋 다이어그램에 넣지 마라(실파일은 gitignore, 템플릿은 플레이스홀더).
  `AGENT_ALLOW_UNSAFE_COMMIT=1`·`--no-verify`·`core.hooksPath` 변경 **금지**(GLG 명시 예외만).
- 막히면: hook 출력 읽고 → 다이어그램에서 용어/secret 제거(private은 `PRIVATE.md`/`.env.local`
  또는 플레이스홀더) → 재스테이지 → 재시도. false positive 같으면 멈추고 hook 출력 그대로 보고.
- push 후 agenda 스탬프(commit/release 스킬 규약).

## 7. 영속 사실이 사는 곳 (썩는 문서 말고)

| 사실 | 집 |
|---|---|
| 현재 운영 상태 | `AGENTS.md` |
| 다음 할 일·후속 검증 | `NEXT.md` (완료분은 지우고 ROADMAP으로 흘림) |
| 버전·업그레이드·운영 결정 이력 | `ROADMAP.md` |
| oracle/openclaw 핸드북 | `ORACLE.md` |
| 반복되는 운영 함정 | `docs/openclaw-gotchas.md` |
| 라이브 봇 런타임 change history | `~/openclaw/README.md` (커밋 안 되는 SSOT) |

이 스킬 자체(`.claude/skills/nixos-config/SKILL.md`)는 **양쪽 하네스가 읽는다**: Claude Code는
`.claude/skills/`를 네이티브로, pi는 `.pi/settings.json`의 `["../.claude/skills"]`로. 스킬을
고치면 두 하네스에 동시에 반영된다 — 커밋해서 다른 기기로도 펼친다.
