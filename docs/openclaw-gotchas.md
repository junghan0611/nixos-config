# OpenClaw 운영 Gotcha 모음

`AGENTS.md`에서 분리된 현장 디버깅/incident 참고. nixos-config가 OpenClaw 담당자이므로 이 파일이 SSOT.

세 카테고리:

- **활성** — 운영 중 자주 부딪힘. 현재 deployment(5.2)에 그대로 적용.
- **비활성** — 기능 자체가 disabled. 재활성화 시 다시 참고.
- **역사** — resolved/superseded. 정책 근거를 보존하기 위해 남김.

---

## 활성

### gogcli(gog) 봇 배포 — 정적 링크 필수 + bin SSOT (2026-08-11 갱신)

**한 줄**: 봇 `gog` = openclaw/gogcli 공개 **정적** v0.34.0. 옛 `junghan0611` 포크 0.12는 폐기. **실파일 SSOT = `~/openclaw/bin/gog`** (스킬 트리 밖).

**도달 체인 (2026-08-11 심볼릭 전량 배포 이후)**:

```
workspace*/skills/gogcli  →  agent-config/skills/gogcli  →  gog 심볼릭
claude-skills/gogcli      ↗                                 └→ ~/openclaw/bin/gog  (실파일)
```

업그레이드: ① `external-packages.sh`로 `~/.local/bin/gog` ② `cp ~/.local/bin/gog ~/openclaw/bin/gog` ③ 끝.

**옛 함정 (해결됨, 재발 금지)**: 호스트 `~/.claude/skills`가 agent-config/skills **디렉터리 심볼릭**이면 compose의 `claude-skills → ~/.claude/skills` 마운트가 agent-config를 통째로 오버레이했다. 고정 형태 = `~/.claude/skills` **실 디렉터리 + per-skill 심볼릭**. 또한 옛 `run.sh k)` rsync는 gog 실파일을 자기참조 심볼릭으로 덮어 파괴 — k)는 심볼릭 전용, 복사 금지.

**정적 링크 필수**: 봇 컨테이너 = Debian bookworm aarch64, **nix store 없음**. gog는 `statically linked`여야 컨테이너에서 돈다. openclaw/gogcli 릴리즈 `linux_arm64`는 정적. `go install`(호스트 CGO=1)은 **nix glibc에 동적 링크**돼 컨테이너에서 loader(`/nix/store/…ld-linux`) 부재로 실행 실패(`not found`처럼 보인다). → `external-packages.sh`는 릴리즈 tarball 다운로드로 정적본을 앉힌다(`go install` 아님, 2026-07-15).

**인증 = 호스트 `~/.config/gogcli` 단일 SSOT (rw 공유)**: 봇에 마운트(docker-compose). gog 0.34+는 keyring lock **write**를 요구하므로 마운트 **rw** 필수(2026-07-15 ro→rw). 옛 0.12는 lock 미사용이라 ro로도 됐다. 호스트 `gog login` 1회 = 봇도 반영(개인+회사 both), refresh token 갱신도 호스트 파일에 써진다. `GOG_ACCOUNT`=개인 gmail(default) env — 계정 둘이라 미지정 시 0.34는 `--account` 요구. 회사는 `--account <work-email>` 명시(실제 값은 agent-config SKILL.md).

**"옛 버전은 됐는데 새 버전이 안 된다"의 정체** (0.12→0.34 회귀 둘): (a) keyring lock write → ro 마운트에서 실패(→rw), (b) 계정 여럿 → account 미지정 실패(→GOG_ACCOUNT). 둘 다 옛 버전엔 없던 요구라, 업그레이드가 조용히 봇 캘린더를 깬다.

### 모델 승격이 특정 대화에만 안 먹는다 — `/reset`·`/new`는 user 핀을 못 푼다 (2026-07-14)

**증상**: `agents.list[].model.primary`를 올렸는데 **어떤 DM만** 옛 모델로 답한다. 세션을 `/new`·`/reset` 해도 그대로다. (2026-07-14: glg를 `gpt-5.6-terra`로 승격했는데 GLG 본인 DM만 계속 `gpt-5.5`.)

**근인**: 그 세션에 **사용자가 명시한 모델 핀**이 저장돼 있다. `config/agents/<id>/sessions/sessions.json`:

```json
"modelOverride": "gpt-5.5",
"providerOverride": "openai",
"modelOverrideSource": "user"     ← 과거 /model <id> 실행의 흔적
```

**`/reset`·`/new`는 전사(transcript)만 비우고 이 핀은 유지한다** — 사용자의 명시적 선택을 존중하는 설계다. 그래서 config 기본값을 아무리 바꿔도 그 대화만 안 따라온다.

**처방**: 해당 대화에서 **`/model default`**. config primary로 복귀한다(코드의 상태 문구도 `pinned session; config primary <X> · clear /model default`). `/model gpt-5.6-terra`처럼 새 모델을 직접 지정해도 당장은 되지만 **또 user 핀이 박혀 다음 승격 때 같은 일이 반복된다** — `default`가 정답.

**진단 (어느 세션이 핀을 물고 있나)**:

```bash
python3 - <<'PY'
import json, pathlib
for a in ('main','glg','gpt','bbot','mini','gemini'):
    p = pathlib.Path(f'~/openclaw/config/agents/{a}/sessions/sessions.json').expanduser()
    if not p.exists(): continue
    for k, v in json.loads(p.read_text()).items():
        if isinstance(v, dict) and v.get('modelOverrideSource') == 'user':
            print(f"{a:7} {k:50} {v.get('modelOverride')}")
PY
```

> 승격 작업의 마지막 단계로 이걸 돌려라. **config만 보고 "승격 완료"라 하면 안 된다** — 실사용 대화가 안 따라올 수 있다. 핀 없는 세션(cron·타인 DM)은 다음 턴에 자동으로 새 기본값을 탄다.

### 봇의 "지금"이 UTC — 컨테이너 TZ 미설정 (2026-07-14, 7.1에서 발견)

**증상**: `/status`가 `Current time: … (UTC)`로 뜬다. 봇에게 "몇 시야?" 물으면 UTC로 답한다.

**근인**: 컨테이너에 `TZ`가 없어 `/etc/localtime → Etc/UTC`. OpenClaw `resolveUserTimezone()`은

```js
// agents.defaults.userTimezone 이 비어있으면 → 프로세스 TZ 로 폴백
return Intl.DateTimeFormat().resolvedOptions().timeZone?.trim() || "UTC";
```

즉 **config를 안 박으면 봇의 시간 감각이 컨테이너 TZ를 그대로 물려받는다.**

**왜 표시 문제가 아니라 버그인가**: ① 봇이 새로 만드는 cron이 UTC 기준으로 적힌다(실제로 `morning-family-schedule`이 `0 23 * * * @ UTC`로 박혀 있었다 — 08:00 KST에 *맞아떨어지긴* 하나 의도가 아니라 사고다). ② **봇이 실행하는 스킬/스크립트의 `date`도 UTC** — 자정 근처에 저널·메모리 파일 날짜가 하루 어긋난다.

**처방 (둘 다)**:

1. `docker-compose.yml` 두 서비스(gateway, cli) `environment`에 `TZ=Asia/Seoul`. **env는 restart가 아니라 `up -d --force-recreate`로만 반영된다.**
2. config에도 명시 (컨테이너 TZ에 기대지 않는 SSOT):
   ```bash
   openclaw config set agents.defaults.userTimezone "Asia/Seoul"
   openclaw config set agents.defaults.envelopeTimezone "user"
   ```

⚠️ **config만으론 안 고쳐진다** — 2026-07-14 실측에서 `userTimezone`을 박아도 봇은 계속 UTC로 답했고, 컨테이너 `TZ`를 박고 recreate한 뒤에야 KST가 됐다. 근인은 컨테이너 쪽이다.

**TZ 변경이 안전한 이유(검증됨)**: 기존 cron이 전부 타임존을 **명시**하고 있으면(`@ Asia/Seoul` / `@ UTC` / `at …Z`) 하나도 안 밀린다. 우리 케이스에서 변경 전후 `cron list`의 next 시각 전부 동일했다. **바꾸기 전에 `cron list`로 타임존 미명시 작업이 있는지 반드시 확인할 것** — 있으면 그건 밀린다.

### 이미지 재빌드 node-gyp hang — @google/gemini-cli(keytar+node-pty) (2026-07-01, 6.11)

증상: 6.10→6.11 재빌드 시 `RUN npm install -g` 스텝에서 **node-gyp가 9분+ hang**. CPU 0.2%(컴파일 아님, cc1plus/g++ child 0) + SYN-SENT 0(네트워크 아님) — 그냥 멈춤. 6일 전 빌드엔 없던 새 비용.

근인: **`@google/gemini-cli` 0.49.0**이 transitive로 `@github/keytar`+`node-pty`(native addon)를 끌어와 aarch64 buildkit sandbox에서 node-gyp가 hang. `@anthropic-ai/claude-code`는 native 0(무관), ACP 2개(pi-coding-agent/codex-acp)도 무관.

진단 반사신경: RUN 스텝이 오래면 → `ps -eo pid,etime,args`로 컨테이너/executor 프로세스 확인 → `node-gyp` 보이고 CPU~0 + cc1plus 없으면 **hang** → temp dir에서 `npm install --ignore-scripts <pkg>` 후 `find node_modules -name binding.gyp`로 native 유발 패키지 특정.

조치: Dockerfile `npm install -g` 줄에서 **3개 제거** — `@earendil-works/pi-coding-agent`+`@zed-industries/codex-acp`(ACP 폐기로 unused, config 미참조) + `@google/gemini-cli`(gemini 403 DOWN·agy 대기라 "안 쫓음" + hang 범인). 남긴 건 `@anthropic-ai/claude-code`만(claude-cli runtime, native 0). 결과 빌드 몇 초. gemini 부활(agy) 시 복원 — 그땐 `libsecret-dev` 등 build deps 필요할 수 있음. 양쪽 Dockerfile(`~/openclaw/` + `docker/openclaw/`) 동기 유지.

### correction release(`-N`)는 버전 문자열을 안 올린다 — Control UI "업데이트 사용 가능"은 상시 오탐 (2026-08-06)

Control UI 상단에 **`업데이트 사용 가능: v2026.7.1-2 (실행 중 v2026.7.1)`** 이 뜬다. 이건 뒤처진 게 아니라 **영구 오탐**이다: correction release는 upstream 태그만 `-2`이고 이미지 안 `/app/package.json`의 `version`은 그대로 `2026.7.1`이다. UI는 릴리즈 태그와 자기 version 문자열을 비교하므로, `-2`를 이미 돌리고 있어도 계속 "업데이트 있음"으로 보인다.

**이 알림을 근거로 업그레이드를 판단하지 마라.** 판단은 digest로만 한다:

```bash
# 원격 태그 digest (pull 없음)
for t in 2026.7.1 2026.7.1-2; do
  printf '%-12s ' "$t"; docker buildx imagetools inspect ghcr.io/openclaw/openclaw:$t | sed -n 's/^Digest:[[:space:]]*//p' | head -1
done
# 라이브 이미지의 base 확인 — 로컬 diff_ids 앞부분이 어느 태그와 일치하는가
#   원격: docker buildx imagetools inspect <ref> --format '{{json .Image}}' → linux/arm64.rootfs.diff_ids
#   로컬: docker inspect openclaw-custom:latest --format '{{json .RootFS.Layers}}'
```

**2026-08-06 실제 오진 사례**: Dockerfile FROM 커밋 시각(08-04 16:36)이 이미지 빌드 시각(08-04 15:00)보다 늦은 것을 보고 "FROM만 바뀌고 rebuild가 빠졌다 = 라이브는 7.1"이라고 진단했다. **틀렸다.** 커밋이 사후에 이뤄졌을 뿐 빌드는 이미 `-2` base를 썼다. `build --pull` 재실행이 전 레이어 CACHED로 끝나고 이미지 ID가 안 바뀐 것이 첫 신호였고, diff_ids 대조로 확정됐다(로컬 base 26개 = `-2`, 7.1과는 index 5부터 갈림). **타임스탬프 두 개로 인과를 세우지 마라 — 레이어를 봐라.** NEXT.md의 7.1 항목에 digest 3개(`7.1`/`-1`/`-2`)가 이미 적혀 있었다는 점도 함께 배울 것: 문서를 먼저 읽었으면 오진 자체가 없었다.

### caddy 변경 = 8-세트 검수 필수 + agenda 000 ≠ caddy (geworfen은 emacs 데몬 의존) (2026-07-01, ax 추가 2026-07-15, claw 추가 2026-08-06)

**규칙 (GLG 지시)**: `docker/caddy/Caddyfile`을 건드리면(특히 `docker restart caddy`) **caddy-fronted 전체를 세트로 검수**한다. 하나만 보고 넘기지 말 것. 현재 세트:

```bash
for d in comments.junghanacs.com analytics.junghanacs.com agenda.junghanacs.com \
         ha.junghanacs.com forge.junghanacs.com map.junghanacs.com ax.junghanacs.com \
         claw.junghanacs.com; do
  printf '%-28s → %s\n' "$d" "$(curl -sS -o /dev/null -w '%{http_code}' --max-time 8 https://$d/)"
done
```
정상 기대치: analytics/ha/forge/ax=200, comments=404(remark42 루트 정상), map·claw=302(authelia 게이트), agenda=200.

**ax.junghanacs.com은 이 호스트의 첫 static vhost다** (2026-07-15 추가, 관리 대상). 기존 6개는 전부 `reverse_proxy`(백엔드 컨테이너)지만 ax는 백엔드가 없다 — caddy가 `file_server`로 `/srv/ax`(= 호스트 `/home/junghan/docker-data/ax` ro 마운트, caddy compose 볼륨)를 직접 서빙한다. geworfen 패턴(컨테이너)을 쓰지 않은 이유: geworfen은 실행 바이너리라 컨테이너가 필요했고 ax는 정적 파일뿐이다.

- **web root 채우는 주체 = junghan0611 repo의 `apply/ax` `make publish`** (leak gate 통과분만 들어옴). `make publish`는 파일만 갈아끼우므로 **caddy 재시작 없이 즉시 라이브**. 이 디렉터리에 publish 경로 밖으로 파일을 떨구면 그대로 공개된다 — leak gate가 유일한 관문이다.
- `.md`는 `header @md Content-Type "text/plain; charset=utf-8"`로 브라우저 표시 강제(기본 `text/markdown`은 다운로드됨). `browse` 없음(리스팅 off), authelia 없음(공개면).
- **볼륨을 새로 붙이거나 뺄 땐 `docker restart caddy`로 안 먹는다** — compose 볼륨 변경은 `up -d --force-recreate` 필요(이게 ax 추가 때 6개 blip의 원인). Caddyfile 텍스트만 고치는 평시 변경은 여전히 `docker restart caddy`.
- **향후**: umami + remark42를 ax에 붙일 예정. 단 스니펫은 **정본(apply/ax 소스)에 넣어 publish**로 흘린다 — **caddy에서 주입 금지**(정본과 라이브가 갈라짐). ax 관련 요청은 이 오퍼레이터 레인이 대응한다.

**claw.junghanacs.com은 유일하게 "인증 뒤에 원격 셸이 있는" vhost다** (2026-08-06 추가). OpenClaw Control UI를 공개면에 올린 자리 — 자물쇠 3겹(Authelia forward_auth → gateway token → HTTPS device pairing)을 **전부 유지**해야 한다. 세 가지가 이 vhost의 함정이다:

- **바깥 자물쇠는 컨테이너 평면에서 우회된다.** `openclaw-gateway`가 `proxy` 도커 네트워크에 붙어 있어(172.18.0.10) 같은 네트의 다른 컨테이너(umami/remark42/forge/ha/butler-viewer/geworfen/authelia)는 Authelia를 건너뛰고 18789에 직결한다. 실측: caddy 컨테이너에서 `http://openclaw-gateway:18789/` → **200(Control UI HTML 무인증 서빙)**, `/control-ui-config.json` → 401. 즉 **진짜 경계는 token + device pairing이지 forward_auth가 아니다.** → `gateway.auth.mode`를 **`trusted-proxy`로 바꾸지 마라**. 바꾸는 순간 저 우회 경로가 곧 인증 우회가 된다. `dangerouslyDisableDeviceAuth`도 마찬가지.
- **Authelia ACL은 first-match이고 no-match는 `default_policy`로 떨어진다.** `default_policy: one_factor`이므로 claw에 operator 규칙만 추가하면 `family` 계정이 그 규칙에 불일치한 뒤 default로 떨어져 **결국 통과한다.** 그래서 claw 규칙은 반드시 3단이다: (a) 포털 bypass → (b) `subject: [['group:operator']]` one_factor → (c) **deny catch-all**. 적용 전 검증은 `authelia access-control check-policy --url ... --username ... --groups ...`로 operator=one_factor / family=deny를 확인하고, `authelia config validate`(4.39 canonical; legacy `validate-config`도 아직 동작)로 파싱을 본다. **mount 경로는 `/config/configuration.yml`·`/config/users.yml` 그대로여야 한다** — `authentication_backend.file.path`가 `/config/users.yml`이라 다른 경로에 stage하면 users DB를 못 찾는다.
- **forward_auth는 WS upgrade 시점에 1회만 평가된다.** 그래서 (a) 세션이 만료돼도 이미 열린 WebSocket은 안 끊기고, (b) **만료 후 재연결은 조용히 실패한다** — 브라우저는 로그인 HTML 응답으로 101 업그레이드를 완성할 수 없다. 증상은 UI의 "연결할 수 없음"뿐이고 로그인창이 안 뜬다. 처방: **F5(top-level navigation)** 로 로그인 화면을 받아라. Authelia 세션은 inactivity 2h / expiration 8h / remember_me 1month.

보안 헤더는 **게이트웨이가 자기 응답에 이미 싣는다**(CSP / X-Frame-Options: DENY / nosniff / Referrer-Policy / Permissions-Policy — 실측). Caddy에서 중복 주입하지 마라. Caddy가 얹는 건 **HSTS 하나뿐**(TLS 종단은 한 곳). `includeSubDomains`·preload는 금지 — junghanacs.com 하위에 http-only가 하나라도 생기면 통째로 잠기고 되돌리기 어렵다.

**함정 — agenda 000은 caddy 탓처럼 보이지만 아니다**: `agenda.junghanacs.com`(geworfen:3333)은 **호스트 emacs `server` 데몬**(`agent-emacs.service`, socket `/run/user/1000/emacs/server`, ro 마운트)에 의존한다. 그 데몬이 hang하면 geworfen HTTP 핸들러가 블록 → agenda **HTTP 000**(caddy는 502 아니라 dial 타임아웃). caddy를 방금 재시작했어도 **인과 아님** — 진단으로 갈라라:
- `emacsclient -s server --eval '(+ 1 1)'` (호스트) → 타임아웃(exit 124)이면 **데몬 hang**이 근인, caddy 무관.
- 소켓 inode 호스트 vs `docker exec geworfen ls -lai /run/user/1000/emacs/` **일치**면 마운트 stale 아님(compose 주석의 "emacs 재시작 후 stale" 회복 경로 해당 없음) → 데몬 자체 문제.
- autoheal이 geworfen을 4분마다 재시작 루프(`docker logs autoheal`)면 **컨테이너가 아니라 데몬이 원인** — geworfen restart로는 안 풀린다.

**복구**(geworfen 담당자 소관 — nixos-config에서 직접 데몬 만지지 말고 entwurf로 핸드오프): `systemctl --user restart agent-emacs.service` + 고아 `--daemon=server` 프로세스(parent=init) 청소 + `docker restart geworfen`. 2026-07-01 사건 = map authelia 배포 caddy restart(11:35)와 무관, 데몬 hang이 11:11부터 선재.

### Telegram isolated polling ingress — 유령 connected / inbound 무응답 (2026-06-29)

증상: 채널 status는 `running, connected, transport:just now, mode:polling`인데, 해당 봇 토큰에 직접 `getUpdates(offset=-1)`를 호출해도 `409 Conflict`가 안 뜬다. 즉 OpenClaw status는 connected로 보이나 실제 long-poll request가 없어서 inbound를 소비하지 못하는 **유령 connected** 상태다. `sendMessage`는 정상이라 bot token / outbound 권한 문제로 오판하기 쉽다.

2026-06-29 bbot 사건 관찰:

- bbot `models status --probe --agent bbot` = `claude-cli usable`, OAuth refresh 정상(`expires in 8h`).
- `openclaw agent --agent bbot --session-key agent:bbot:telegram:bbot:direct:123861330 ...` = 기존 Telegram direct session도 3.5s 내 `ok`. 즉 claude-cli runtime/session 자체가 root cause가 아니었다.
- Bot API 직접 `sendMessage`도 성공(`message_id=1388`). outbound 정상.
- 문제는 isolated ingress worker가 실제 long-poll을 유지하지 못한 것. bbot만 standard polling으로 돌리자 `/start`/`/new` 후 inbound가 다시 살아났다.

임시 복구(컨테이너 런타임 핫패치 — **recreate/image rebuild 시 사라짐**):

```bash
cd ~/openclaw
# /app/dist/probe-*.js 의 monitorTelegramProvider isolatedIngress 설정부에서 bbot만 false
# enabled: account.accountId === "bbot" ? false : opts.isolatedIngress?.enabled ?? true,
docker compose restart openclaw-gateway
```

검증 순서:

1. `getWebhookInfo`에서 webhook 비어 있고 pending 수 확인.
2. 직접 `sendMessage`로 outbound 정상 확인.
3. `models status --probe --agent <id>`와 `openclaw agent --session-key agent:<id>:telegram:<account>:direct:<chatId>`로 runtime/session 정상 확인.
4. status가 connected인데 직접 `getUpdates(offset=-1)`가 409를 못 받으면 유령 connected. 단 이 진단 호출 자체가 실제 poller와 충돌을 만들 수 있으니 짧게 1회만.
5. standard polling 전환/핫패치 후 사용자가 실제 DM(`/start`, `/new`, `테스트`)을 보내 inbound→claude turn→sendMessage 로그가 이어지는지 확인.

후속: 이 핫패치를 Dockerfile/entrypoint patch 또는 upstream config toggle로 영구화할지 결정해야 한다. 지금 상태는 컨테이너 내부 수정이라 `up -d --force-recreate`나 이미지 재빌드로 되돌아간다.

### claude-cli provider — `claude` binary not on PATH → EPIPE on every turn (2026-05-26)

OpenClaw 5.20 (`dist/cli-backend-CO2SZJAY.js`)이 `claude-cli` provider를 자동 등록하면서 spawn args를 `command: "claude"`로 박는다. PATH에서 `claude`를 찾는데, image는 `@anthropic-ai/claude-agent-sdk` (+ `@anthropic-ai/claude-agent-sdk-linux-arm64/claude` 번들 binary)만 install 하고 `node_modules/.bin/claude` symlink는 만들지 않음 (SDK package.json에 `bin` field 없음). 결과:

```
spawn("claude", ...) → ENOENT
child exits in ~4ms
parent stdin write → EPIPE
log: "claude live session close: reason=abort" + "model fallback decision: reason=timeout detail=write EPIPE"
telegram UX: "⚠️ Agent failed before reply: write EPIPE. Please try again, or use /new to start a fresh session."
```

함정 자리:
- `openclaw infer model run --model claude-cli/...` 은 **잘 작동**. 다른 dispatch path (one-shot capability) 사용.
- `openclaw agent --agent <id>` + 텔레그램 inbound 둘 다 같은 live session path → 둘 다 EPIPE.
- `/status` 도 정상 표시 (model lookup만 하고 spawn 안 함).

Fix (정공법, env 변경 — force-recreate 필요):

```yaml
# docker-compose.yml — gateway service AND child env (두 자리)
- PATH=/app/node_modules/@anthropic-ai/claude-agent-sdk-linux-arm64:/home/junghan/.pi/agent/claude-plugin/skills/bibcli:.../bin
```

SDK 디렉토리에는 `claude` + LICENSE/README/package.json만 있어서 다른 binary와 충돌 0. `node_modules`가 image 안이라 영구.

대안 (안 채택): host `npm i -g @anthropic-ai/claude-code` 후 mount — 호스트 의존 늘어남. Dockerfile에 `npm i -g` 추가도 가능 — image 재빌드 비용.

### bonjour plugin — disable on Oracle Cloud + Docker (since 2026-04-24)

OpenClaw 2026.4.24 split bonjour LAN discovery into a default-on plugin (`@homebridge/ciao`). On Oracle Cloud + Docker with IPv6 disabled (our setup), the mDNS probe fails and emits `Unhandled promise rejection: CIAO PROBING CANCELLED` every ~30s, taking gateway down with it (restart loop). LAN discovery has no value to us — we reach gateway via SSH tunnel, not Bonjour.

Fix: set `plugins.entries.bonjour: { enabled: false }` in `openclaw.json`. Plugin count drops from 9 back to 8 (matching 4.23 behavior). No functional loss.

### Adding non-default models (since 2026-04-27)

OpenClaw 2026.4.24 narrowed default `openclaw models list` to *configured* rows only, and 4.24's `/models add` slash command is deprecated. To make a new model usable from `/model <id>` slash command:

1. Sync the provider API key from `~/.env.local` to `~/openclaw/.env` (preserves the SSOT pairing rule).
2. Add `provider/model-id: {}` under `agents.defaults.models` in `openclaw.json`.
3. `docker compose restart openclaw-gateway`.
4. Verify with `node openclaw.mjs models` (note: no subcommand) — look for the model in the `Configured models` line.

`models list --all` exists but is slow (>60s timeout in our container) — don't rely on it for verification.

### rw mount expansion — git is the rollback surface (2026-04-25)

Since the 4.23 upgrade, `~/repos/gh:rw` and `~/org/{meta,bib,notes}:rw` are open. There is no filesystem enforcement against unintended writes — rollback relies on `git status` / `git diff` / `git restore`.

- Monitor the first hour after any rw-expanding mount change.
- An unintended write into `~/org/diary.org` (or anything else under `~/org:ro`) means the mount config regressed.
- `~/repos/work` remains ro deliberately — never widen this without consulting the company code-safety policy.
- `nixos-config` is a symlink inside `~/repos/gh/` (→ `~/nixos-config`). Container cannot follow it. Agent edits to nixos-config must route through the host, not the bot runtime.

### Codex catalog — models.json drift on upgrade is expected (2026-04-25)

> **⚠️ 2026-08-07 이후 이 절은 이력 문서다.** codex 런타임 의존성을 전부 제거했다(`plugins.entries.codex.enabled=false`, `gpt-5.4`/`gpt-5.4-mini` 카탈로그 삭제). 서빙 경로에 codex가 없으므로 이 drift는 더 이상 운영 이슈가 아니다 — `agents/*/agent/models.json`에 Codex provider 블록이 남아있어도 참조하는 모델이 0이다. codex를 되살리는 경우에만 다시 유효해진다. 배경은 [ORACLE.md](../ORACLE.md) §"런타임 지형".


OpenClaw 2026.4.23 synthesizes the `openai-codex/gpt-5.5` OAuth row automatically. After the upgrade, `git diff config/agents/*/agent/models.json` shows `gpt-5.4 → gpt-5.5` in the Codex provider block. This is catalog-layer drift; the **serving model** is still `openai-codex/gpt-5.4` because `agents.list[].model` pins it explicitly. Verify with:

```bash
python3 - <<'PY'
import json, pathlib
c = json.loads(pathlib.Path('/home/junghan/openclaw/config/openclaw.json').read_text())
for a in c['agents']['list']:
    print(a['id'], a.get('model'))
PY
```

### Dreaming — decoupled from heartbeat (since 2026.4.23)

Upstream #70737 moves dreaming into an isolated lightweight agent turn. It now runs even when `heartbeat` is off for the default agent and is no longer skipped by `heartbeat.activeHours`. `openclaw doctor --fix` migrates stale main-session dreaming jobs in persisted cron configs to the new shape. Our deployment had no stale entries at 4.22 → 4.23 upgrade.

### ACP common failures

- `Authentication required` — confirm `~/.claude` is mounted; a simple `restart` after mount changes is not enough, recreate is.
- Only a few skills visible — broken absolute symlinks inside `~/.claude` pointing at `/home/junghan/repos/gh/...`. Add `~/repos/gh` as a compatibility mount; overlay `claude-skills` to `/home/node/.claude/skills`.
- `session-env ... ENOENT` — `~/.claude` must be **rw**.
- `ACP max concurrent sessions reached` — raise `acp.maxConcurrentSessions` or close stale sessions. Current setting: 3.
- `docker compose restart` alone insufficient after mount or env change — use `up -d --force-recreate`.

### Key pairing — same name, different value (2026-05-08)

`~/.env.local` (호스트 SSOT)와 `~/openclaw/.env` (Docker env_file)에 같은 변수명 `OPENROUTER_API_KEY`가 *서로 다른 값*으로 들어 있을 수 있다. 호스트 키는 정상이지만 컨테이너 키가 OpenRouter privacy/data policy로 막혀 있으면 모든 임베딩이 `404 No endpoints available matching your guardrail restrictions`로 실패.

운영 검증 절차:
- 키 sync는 변수명만 비교하지 말고 *값*까지 비교 (suffix 4자리만 보여 시크릿 노출 없이 일치 여부 확인).
- OpenClaw가 `${VAR}` 자동 보간하므로 한 곳(`~/openclaw/.env`)만 sync되면 충분. recreate 필요 (restart는 env 새로 안 읽음).
- 컨테이너 내부에서 직접 `curl /embeddings` 한 번 200 응답 확인 후 reindex 시작. 키 정상 + 정책 통과 확인 없이 reindex 들어가면 6 agent 모두 동시 실패.

---

## 비활성 — 재활성화 시 참고

### active-memory — model choice matters (currently disabled since 2026-05-03)

5.2 안정성 검증 동안 `plugins.entries.active-memory.enabled: false`로 둠. 재활성 시 baseline은 `~/openclaw/config/openclaw.json` 기존 config (Groq paid tier `gpt-oss-120b` primary, `google/gemini-3-flash` fallback, `timeoutMs: 15000`, `agents: ["glg", "gpt"]`).

운영 발견 (재활성 전 알아둘 것):

- `openai-codex/gpt-5.4-mini` hits a 31.5s Codex CLI subprocess cold-start. Plugin `timeoutMs` is not honored across the subprocess boundary. **Do not use Codex models in blocking hot-path plugins.** → **2026-08-07 이 규칙을 따라 실제로 치웠다**: active-memory lane이 `gpt-5.4-mini`(codex) → `openai/gpt-5.6-luna`(openclaw 내장 런타임, 서브프로세스 없음). 오래 남아있던 recall 23~35s 지연의 유력 원인이 이 콜드스타트였으므로, 교체 후 latency 재측정이 [NEXT.md](../NEXT.md)에 걸려 있다.
- `timeoutMs=8000` is too tight for groq — saw 9.7s boundary timeouts. Use 15000 (upstream default).
- Upstream `3f90d9266` (v2026.4.21) graceful degrade keeps replies alive on timeout; active-memory is an assist layer, not a critical path.
- **Groq free tier TPM=8K로 `gpt-oss-120b` 실사용 불가** (2026-04-23 관측). active-memory 프롬프트는 queryChars 1K라도 전체 input이 ~35K tok이라 매 호출 `413 Request too large`. 해결책: Groq Console에서 **paid tier 전환** ($10 선불, pay-per-use). 전환 후 호출당 ~7원, 응답 ~11s.
- **`modelFallback`은 `rate_limit` 케이스에서 자동 승계되지 않음** — 관측상 `decision=surface_error reason=rate_limit profile=-`로 끝나고 fallback 모델로 재시도하지 않음. 에러 메시지 본문이 그대로 summary로 노출되어 `summaryChars=50` 같은 작은 값으로 찍힘. `timeout`이나 일반 장애에서만 fallback이 탄다.
- **Gemini 3 Flash Lite는 Flash보다 느릴 수 있다** (2026-04-23 관측: Flash 13.4s vs Flash Lite 17.9s→timeout). 이름과 달리 active-memory의 input-heavy 워크로드(input:output ≈ 500:1)에서는 Lite의 TTFT가 더 길었음. Groq LPU의 decode 강점도 이 워크로드에서는 prefill이 지배적이라 제한적.

### ACPX — disabled since 2026-05-03

`plugins.entries.acpx.enabled=false` + `acp.enabled=false`. 5.2가 ACPX를 `@openclaw/acpx` beta로 externalize했고 우리는 미설치. 재활성 시점이 오면 `npm i @openclaw/acpx` + 아래 4개 항목 재참조.

#### ACPX — model override does not persist

As of 2026.4.15 + acpx 0.5.3, the ACP session model cannot be written into config. Schema strict fields on `AcpBindingSchema.acp` (`mode, label, cwd, backend`) and `AgentRuntimeAcpSchema` (`agent, backend, mode, cwd`) have no `model`. Only path: the in-chat slash command.

```
/acp spawn claude --bind here --cwd /home/node/.openclaw/workspace
/acp model anthropic/claude-opus-4-6
```

No host bypass exists. `openclaw acp` is only a bridge to external ACP clients; `message send` is one-way; editing `thread-bindings` files cannot substitute for spawn.

TTL recycles every 2h idle (`acp.runtime.ttlMinutes: 120`) and the model override evaporates. Active threads need manual re-set a few times per day until upstream acpx version bump.

2026-04-19 observation: `/acp model anthropic/claude-opus-4-7` CLI says "session ids resolved" but the actual served model is `claude-opus-4-6` — Anthropic flat-rate OAuth silently downgrades. Use `anthropic/claude-opus-4-6` explicitly; 4.7 needs separate billing.

2026-04-24 re-check on v2026.4.22: catalog now normalizes `anthropic/claude-opus-4-7` to 1M context (display-only fix), but routing is still OAuth-tier gated. **Policy: Claude access is company flat-rate OAuth only** — no direct Anthropic API billing. 4.7 live routing is therefore out of our fixable scope; stay on 4.6 until tier changes.

Inspect truth from the host — never from inside an already-bound thread (text there may be forwarded to the Claude session as a user turn):

```bash
cd ~/openclaw && docker exec openclaw-gateway sh -lc 'node openclaw.mjs sessions --all-agents'
cd ~/openclaw && docker exec openclaw-gateway sh -lc 'sed -n "1,200p" /home/node/.openclaw/telegram/thread-bindings-default.json'
cd ~/openclaw && docker exec openclaw-gateway sh -lc 'sed -n "1,200p" /home/node/.openclaw/telegram/thread-bindings-bbot.json'
```

#### ACPX — sessions do not auto-load workspace identity

A fresh `/acp spawn claude --bind here` Claude session does not read `workspace/IDENTITY.md / SOUL.md / USER.md / AGENTS.md / MEMORY.md`. Direct-runtime agents did (GlueClaw path historically), ACPX Claude sessions do not — claude-agent-sdk does not scan the workspace.

Fix on first turn after spawn:

```
workspace의 IDENTITY.md, SOUL.md, USER.md, AGENTS.md, MEMORY.md를 순서대로 읽고 시작하세요
```

Longer term: put a `CLAUDE.md` in workspace, or inject "read workspace/IDENTITY.md first" into `agents.list[].systemPromptOverride`, or use an ACPX bootstrap script when upstream enables it.

#### ACPX — sessions do not know their own runtime

Asking an ACPX Claude session "what runtime are you on" returns whatever `workspace/MEMORY.md` claims — pure doc-driven inference, not ground truth. In 2026-04-19 testing the binding was explicitly `agent:claude:acp:...` on Anthropic Opus 4.6, but the bot reported "not acpx, I am on direct runtime" because MEMORY.md described GlueClaw as default.

Do not trust bot self-introspection. Verify from the host with `/acp status` outside the thread, or `docker exec ... sessions --all-agents`. Long-term: remove "default runtime" prose from workspace docs, or inject a systemPromptOverride like "you cannot know your own runtime; tell the user to check `/acp status`".

#### ACPX — direct vs ACP-bound session confusion in host inspection

`openclaw sessions --all-agents` interleaves two kinds of rows:

- `agent:<id>:telegram:*` — **direct session** for the Telegram DM. Its `Model` column shows the agent's at-rest/fallback model (or a stale state from before the thread was ever `/acp spawn`-ed).
- `agent:claude:acp:*` — **ACP-bound session** actually serving the live bound conversation. This row's `Model` reflects the active `/acp model` override.

The live serving model is the ACP row, not the direct row. 2026-04-24 misread: interpreted a stale `claude-sonnet-4.6` on a `bbot direct` row as the live bbot state, and reported bbot as "fallback-mode" in a commit message. bbot was in fact on `claude-opus-4-6` via ACPX the whole time.

Verification path (least effort first):

1. Ask the bot itself in-thread.
2. Read `/home/node/.openclaw/telegram/thread-bindings-<account>.json` → `targetSessionKey`. If it starts with `agent:claude:acp:`, the live path is ACPX and the serving model lives in that ACP session, not in any `direct` row.

---

## 역사 — resolved / superseded (정책 근거 보존)

### 4.24 warn-ignored incidents — "Warn = Error" 원칙의 근거 (2026-04)

AGENTS.md §5 "Warn = Error" 원칙이 태어난 두 사건. 둘 다 여러 사이클 동안 무해한 startup noise로 치부됐다가 4.24에서 폭발했다.

- **task registry malformed**: `Failed to restore task registry` (`code:"ERR_SQLITE_ERROR" errcode:779 errstr:"database disk image is malformed"`) — 4.21부터 매 gateway start마다 떴고 11일간 "tolerable startup noise"로 방치. 4.24가 restart-continuation을 같은 task registry로 라우팅하면서, malformed `runs.sqlite`가 background warning → 100% CPU silent retry loop로 돌변해 inbound message 처리가 얼어붙음. Fix: gateway 정지 → `~/openclaw/config/tasks/runs.sqlite`를 백업 폴더로 이동 → start (새 DB 자동 생성, in-flight task state만 손실, user data 없음).
- **bonjour probe loop**: `bonjour: watchdog detected non-announced service` — 4.23부터 반복된 warn을 "ARM cloud LAN noise"로 무시. 4.24가 bonjour를 default-on plugin으로 승격하자 같은 probe 실패가 `Unhandled promise rejection: CIAO PROBING CANCELLED` → ~30s restart loop가 됨. Fix: `plugins.entries.bonjour: { enabled: false }` (현재 활성 gotcha로 박제 — 위 "활성" 참조).

교훈: 두 warn을 사이클 내내 무시한 대가는 user-visible 봇 downtime이었다. warn 조사 비용은 분 단위, 방치 비용은 시간 단위.

### 4.24 → 4.26 / 4.29 lazy-staging incident — resolved on 5.2 (2026-05-03)

**RESOLVED on 5.2.** 4.23 → 4.29 attempt on 2026-05-03 reproduced the same lazy-staging hot-path incident — first inbound message triggered `[plugins] alibaba/runway/tts-local-cli staging bundled runtime deps` mid-hot-path with `eventLoopDelayMaxMs=17213.4` and `[telegram] sendChatAction failed`. Same incident class as 4.26. 4.29 brought the diagnostic timeline + slow-host-startup fixes but no structural fix for "scope of plugin runtime preloads". Jumped directly to **5.2** which carries the structural fix:

- `Plugins/runtime: scope broad runtime preloads to the effective plugin ids derived from config, startup planning, configured channels, slots, and auto-enable rules instead of importing every discoverable plugin`
- `Tools/plugins: cache plugin tool descriptors captured from api.registerTool(...) so repeated prompt-time planning can skip plugin runtime loading while execution still loads the live plugin tool` (#76079)

5.2 verified: ready 7.3s first boot / 5.3s warm boot, CPU 0.23% idle, MEM 246 MiB, **zero `staging bundled runtime deps` lines on hot path**. Family-bot smoke test passed. Single 24s liveness spike on first cold-message only (Codex OAuth + 49k context hydration), idle thereafter. Full operational record in `~/openclaw/README.md` Change history (entry dated 2026-05-03 / version 5.2).

**Operational lessons retained** (these still apply for any future jump where structural fix is unproven):

- *No more two-version jumps on family-traffic gateway* unless the target version has a verified structural fix and we have a no-traffic window.
- *Stage on a non-family agent first* when uncertain.
- *Family responsiveness is the SLO.* If the operator notices latency, that is a P0 — investigate before the next upgrade ships, not after.
- *Trust the structural-fix release tag* but bench-test on a no-traffic window first. "Latest is best" was wrong for 4.24/4.25/4.26/4.29 (no fix), correct for 5.2 (fix shipped).

### 4.24 → 4.26 latency regression — wait-and-watch (2026-04-28, superseded by 5.2)

A two-version jump from 4.24 to 4.26 produced a service-quality incident on the family-traffic gateway. Operator and family reported "responses that used to come instantly now take all day." Multiple `[diagnostic] stuck session` entries with gateway PID showing **102% CPU** on a single node thread. Resolved by emergency rollback to 4.23, which was the latest known-good for both response latency *and* `gpt-image-2` Codex-OAuth image generation. Fully superseded by 5.2 structural fix above; the policy "no two-version jumps on family traffic" born in this incident remains in effect.

### GlueClaw — runtime auto-injected providers from repo presence (resolved by deletion)

OpenClaw plugin discovery walks mounted volumes. Any `openclaw.plugin.json` in a mounted path is a candidate provider. `~/repos/gh/glueclaw/openclaw.plugin.json` was re-injecting `glueclaw` / `sc` providers into every agent's `models.json` on container start, even though `641d497` had removed them at config level. Deleting the local repo broke the injection path. The GitHub fork (`junghan0611/glueclaw`) is preserved as history.

Lesson: if a provider is not wanted, the source directory must leave the mount, not just the config.
