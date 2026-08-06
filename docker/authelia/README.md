# authelia — map.junghanacs.com forward-auth 가드

`map.junghanacs.com`(butler-viewer, 가족 부동산 데이터) **앞단에만** 인증창을 세운다.
butler-viewer 내부 수정 0, 다른 서브도메인 규칙 0, zero-trust 아님 — 그냥 문 앞 자물쇠.

## 흐름

```
아내 → map.junghanacs.com/v/...  (미인증)
     → Caddy forward_auth → authelia 401/302
     → 로그인 페이지 (map.junghanacs.com/authelia/)
     → 로그인 → 쿠키(domain=map.junghanacs.com) → 원래 URL 복귀
     → butler-viewer 뷰어 표시  (쿠키 유효기간 동안 재로그인 없음)
```

봇 push(`POST butler-viewer:8765/api/surfaces/:id`)는 **내부 proxy 네트워크 직결**,
Caddy를 안 거치므로 이 가드에 **영향 0**.

## 배포 런북 (아내 공지된 window에서만)

> ⚠️ 4단계 `docker restart caddy` 시 **모든 `*.junghanacs.com`이 1~2초 blip**
> (comments/analytics/agenda/ha/forge/map/ax + geworfen). 가든 홈페이지는 Netlify라 무관.

**1. 시크릿 채우기**
```bash
cd ~/repos/gh/nixos-config/docker/authelia
cp configuration.yml.template configuration.yml
# configuration.yml 의 GENERATE 3곳(jwt_secret / session.secret / storage.encryption_key)을
# 각각 아래 값으로 교체:
head -c32 /dev/urandom | base64   # 3번 실행
```

**2. 유저 해시**
```bash
cp users.yml.template users.yml
docker run --rm authelia/authelia:latest \
  authelia crypto hash generate argon2 --password '아내_비번'   # → wife.password
docker run --rm authelia/authelia:latest \
  authelia crypto hash generate argon2 --password 'GLG_비번'    # → glg.password
mkdir -p ~/docker-data/authelia
```

**3. authelia 기동** (새 컨테이너, 기존 서비스 무중단)
```bash
docker compose up -d
docker logs authelia --tail 20        # "Authelia is listening" 확인
```

**4. Caddyfile map 블록 교체 + caddy 재시작**

`~/repos/gh/nixos-config/docker/caddy/Caddyfile` 의 map 블록을 아래로 교체:

```caddyfile
# butlercli estate viewer — authelia forward-auth 가드 (가족 데이터)
map.junghanacs.com {
    # authelia 포털 (bypass — 로그인창은 미인증 상태에서 열려야 함)
    handle /authelia/* {
        reverse_proxy authelia:9091
    }
    # 나머지 전부: 인증 게이트 통과해야 butler-viewer 도달
    handle {
        forward_auth authelia:9091 {
            uri /authelia/api/authz/forward-auth
            copy_headers Remote-User Remote-Groups Remote-Email Remote-Name
        }
        reverse_proxy butler-viewer:8765
    }
}
```

그리고 (Caddyfile 상단 inode 함정 때문에 reload 아니라 **restart**):
```bash
docker restart caddy
docker exec caddy grep -A2 'map.junghanacs.com' /etc/caddy/Caddyfile   # 컨테이너가 새 내용 보는지 확인
```

**5. 검증**
- 브라우저 시크릿창 → `https://map.junghanacs.com/` → authelia 로그인 페이지 뜨는지
- 로그인 → 뷰어 도달하는지
- 봇 push 여전히 동작(내부 경로라 무영향이지만 라이브 turn 1회 확인)

## 롤백

Caddyfile map 블록을 원복(`reverse_proxy butler-viewer:8765` 한 줄)하고 `docker restart caddy`.
authelia 컨테이너는 `docker compose down` 으로 내려도 다른 서비스 무관.

## 확장 — 실제로 한 번 했다: claw.junghanacs.com (2026-08-06)

두 번째 가드 도메인을 붙이는 표준 절차. **A안 반복**(쿠키 도메인마다 별도 엔트리, 새 DNS 불필요)이며
map과는 **별도 로그인**이 된다(SSO 아님 — 그건 아래 B안).

1. `session.cookies` 에 엔트리 추가 — `domain` / `authelia_url: https://<d>/authelia` / `default_redirection_url`.
2. `access_control.rules` 에 **3단**으로 추가. 순서가 곧 정책이다:
   `(a) resources ^/authelia(...)$ → bypass` → `(b) subject [['group:<g>']] → one_factor` → `(c) → deny`.
   **(c) catch-all 을 빠뜨리면 안 된다** — `default_policy: one_factor` 이므로, (b)에 불일치한 다른 계정이
   default 로 떨어져 **결국 통과한다**. map 블록에 (c)가 없는 이유는 map이 `family` 전원 허용이기 때문.
3. `users.yml` 에 그 도메인 전용 그룹의 계정 추가 (그룹을 섞지 말 것).
4. **적용 전 검증** — 라이브에 넣기 전에 stage 파일로 판정한다. mount 경로는 `/config/...` 그대로여야 한다
   (`authentication_backend.file.path` 가 `/config/users.yml` 이라 다른 경로면 users DB 를 못 찾는다):

   ```bash
   STAGE=~/openclaw/backups/<name>          # repo 안에 두지 마라 — .gitignore 는 정확한 파일명 2개뿐이라
                                            # configuration.yml.bak-* / users.yml.bak-* 는 추적된다(해시 유출)
   MOUNTS="-v $STAGE/configuration.yml:/config/configuration.yml:ro
           -v $STAGE/users.yml:/config/users.yml:ro
           -v /home/junghan/docker-data/authelia:/data:ro"
   docker run --rm $MOUNTS authelia/authelia:4.39.20 \
     authelia config validate --config /config/configuration.yml
   # 4.39 canonical 은 `config validate` (legacy `validate-config` 도 아직 동작)

   # ACL 판정 — 통과해야 할 것과 막혀야 할 것을 둘 다 본다
   docker run --rm $MOUNTS authelia/authelia:4.39.20 authelia access-control check-policy \
     --config /config/configuration.yml --url https://claw.junghanacs.com/ --username glg --groups operator
   #   → one_factor
   docker run --rm $MOUNTS authelia/authelia:4.39.20 authelia access-control check-policy \
     --config /config/configuration.yml --url https://claw.junghanacs.com/ --username family --groups family
   #   → deny        ← 이게 안 나오면 catch-all 이 빠진 것
   ```

5. 라이브로 이동 후 **mode 600** 고정(`configuration.yml` 에는 session/storage/JWT secret 이 들어있다).
   컨테이너는 root 로 돌므로 600 이어도 읽는다. 그 다음 `docker restart authelia`.
6. **map 회귀 확인** — `curl -o /dev/null -w '%{http_code}' https://map.junghanacs.com/` 가 302,
   포털 `/authelia/` 가 200. 그리고 Caddyfile 을 건드렸으면 8-세트 검수
   (`docs/openclaw-gotchas.md` "caddy 변경 = 8-세트 검수").

## 확장 — B안 (SSO, 아직 안 함)

여러 `*.junghanacs.com`을 **한 로그인**으로 묶고 싶어지면: `auth.junghanacs.com` A레코드 + 쿠키
domain 을 `junghanacs.com` 으로 올리고 각 서브도메인에 forward_auth 블록 추가.
대가: 기존 쿠키가 전부 무효화되어 **가족 전원 재로그인**이 필요하고, map 의 `authelia_url` 도 바꿔야 한다.
도메인 두세 개까지는 A안 반복이 싸다.
