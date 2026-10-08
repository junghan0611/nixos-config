# Telegram 그룹·토픽 운영

OpenClaw 2026.9.8 기준. 라이브 설정·토큰·사용자/방 ID는 private runtime에만 둔다.

## 그룹과 개인 대화

- 가족 그룹은 기존 사용자별 DM과 별도 대화다. Forum 그룹은 토픽별로 `:topic:<threadId>` 세션을 사용하고 같은 토픽에 답한다.
- 새 토픽은 그룹 정책을 상속한다. 모든 토픽을 개별 등록할 필요는 없다.
- 봇이 일반 메시지를 맥락으로 받되 호출 때만 답하려면, 해당 그룹에서 봇을 관리자로 두고 `requireMention:true`를 설정한다. 일반 메시지 수신을 위해 BotFather privacy를 전역 해제할 필요는 없다.
- 기본 호출에는 실제 봇 username 멘션뿐 아니라 봇 메시지에 대한 답글도 포함된다. 입장 소개·허용된 제어 명령은 별도 예외다.
- 대화 세션 분리는 같은 에이전트의 workspace·장기 기억을 강제로 격리하지 않는다. 개인 DM의 비공개 내용을 그룹으로 자발적으로 전달하지 않는 방 지침을 함께 둔다.

문서 근거: 운영 이미지 `/app/docs/channels/telegram/{messaging,access-control,setup,threads-and-sessions}.md`.

## 권한은 두 층

1. **Telegram**: 사람은 일반 그룹 멤버면 된다. 봇에는 필요한 관리자 권한만 준다. 토픽 생성·수정을 맡기려면 토픽 관리 권한이 필요하며, 삭제·차단·초대 권한은 불필요하다.
2. **OpenClaw**: DM pairing 승인은 그룹 발신 허용으로 이어지지 않는다. 그룹의 `allowFrom`에 호출 가능한 사용자 ID를 명시한다. `groupAllowFrom`은 사용자 목록이고, 그룹 ID는 `groups`의 키다.

여러 봇을 운영하면 `channels.telegram.accounts.<accountId>.groups` 아래에 해당 방만 설정한다. 계정의 groups 맵은 루트 맵과 deep merge되지 않고 대체하므로 기존 방이 있다면 함께 보존한다.

```json5
{
  "<GROUP_CHAT_ID>": {
    requireMention: true,
    allowFrom: ["<OPERATOR_USER_ID>", "<OTHER_MEMBER_USER_ID>"],
    systemPrompt: "개인 DM의 비공개 내용을 이 방으로 자발적으로 전달하지 않는다.",
  },
}
```

## 토픽 관리와 모델

- 9.8 기본 Telegram message 도구는 `topic-create`·`topic-edit`를 제공한다. 기본 action gate는 활성이고, 모델이 아니라 Telegram 권한·도구 정책을 함께 확인해야 한다.
- 토픽 닫기·삭제·기존 메시지 이동은 확인한 기본 도구에 노출되어 있지 않다. 모델 교체만으로 이 기능이 생기지는 않는다.
- Claude CLI도 OpenClaw MCP 도구에 연결된다. 확인한 그룹 세션은 Sonnet 5·`claude-cli`·`thinkingDefault:medium`이었다. GPT와의 품질 비교는 별도 실측이며, 가족 토픽 운영 때문에 모델을 바꾸지는 않았다.

코드 근거: `/app/extensions/telegram/src/channel-actions.ts:193-198`, `action-runtime.ts:872-935`, `/app/extensions/anthropic/cli-backend.ts:175-179`.

## 봇 DM도 토픽을 지원한다

그룹 토픽과는 별도 기능이다. 봇 소유자가 [BotFather Mini App](https://t.me/BotFather?startapp) → Bot Settings → Threads Settings → Threaded Mode를 활성화하고, Bot API `getMe.has_topics_enabled`가 `true`여야 OpenClaw가 DM 토픽별 세션을 사용한다. 일반 DM의 채팅방 설정이나 BotFather `/mybots` 텍스트 메뉴에서 켜는 기능이 아니다. 클라이언트에서도 해당 기능을 지원해야 한다. 메뉴 경로 근거: [hermes-agent #116803](https://github.com/NousResearch/hermes-agent/pull/116803); 기능 근거: [Telegram bots](https://core.telegram.org/bots#natively-integrate-ai-agents-and-chatbots).

현재 6봇 전부 DM 토픽·사용자 토픽 생성이 활성화되어 있다. 2026-10-08 운영자가 미니앱에서 설정한 뒤 각 Bot API `getMe`와 OpenClaw probe에서 `has_topics_enabled:true`·`allows_users_to_create_topics:true`를 확인했다. 연결 시작 시 받은 botInfo를 갱신하기 위해 Telegram 플러그인만 새로고침했다(`plugins reload telegram`: `ok:true`, `restartRequired:false`, generation 3; 사전 관측의 active work 0, 이후 6계정 running/probe ok·healthy). 기존 runtime config·DM/session·모델은 그대로다.

실제 DM 토픽 첫 대화의 세션·답변 위치는 별도 실사용 검수다. 기존 flat DM 맥락이 새 토픽에 자동 이어진다고 보장하지 않는다. 폐기된 `dm.threadReplies` 설정을 부활시키지 않는다. 개인 계정 CLI 인증·`/mybots` 텍스트 메뉴는 이 토글에 필요 없으며, 잘못 시작했던 인증 대기 터미널은 정리했다. 상세 전/후·reload 영수증은 private `~/openclaw/backups/dm-topics-20261008T170739/`.

## 적용·검증 영수증

운영자가 그룹 토픽 기능의 실사용 성공을 확인했고 개인 사용을 계속하기로 했다. 추가 구성원의 사용·채널 운영은 착수 조건이 아니다. 구성원 호출 허용은 유지하되 실제 사용 확인을 강제하지 않는다.

- `config patch --dry-run`·`config validate` 통과; 의도한 glg 그룹 정책 외 DM/session·bindings·다른 봇 설정은 diff 동일.
- 설정은 Gateway 프로세스 재시작 없이 적용됐지만 Telegram 채널은 자동 재연결됐다. 이후 6계정 probe 전부 running/ok.
- General 토픽의 `:topic:1` 수신·응답은 Gateway 기록으로 확인했다. 추가 구성원 초대 알림에 답한 것은 그 사람의 직접 호출 성공과 구분한다; `chat.history` 발신자 메타데이터로 판별한다.
- 보호된 원본·patch·복구 영수증: private `~/openclaw/backups/family-group-20261008T155252/`, `family-spouse-20261008T161125/`. 공개 repo에 복사하지 않는다. 복구는 동시 변경을 확인한 뒤 해당 방의 마지막 변경만 되돌린다.
