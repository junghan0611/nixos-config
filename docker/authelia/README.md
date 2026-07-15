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

## 확장 (나중에, 지금 불필요)

다른 `*.junghanacs.com`(agenda/ha 등)도 한 로그인으로 묶고 싶어지면 **B안**:
`auth.junghanacs.com` A레코드 + 쿠키 domain을 `junghanacs.com`으로 올리고
각 서브도메인 블록에 `import authelia` 스니펫 추가. 그 전까진 map 하나만.
