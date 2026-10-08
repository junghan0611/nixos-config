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

그룹 토픽과는 별도 기능이다. 봇 소유자가 BotFather의 Threaded Mode를 활성화하고, Bot API `getMe.has_topics_enabled`가 `true`여야 OpenClaw가 DM 토픽별 세션을 사용한다. 일반 DM의 채팅방 설정 메뉴에서 켜는 기능이 아니다. 클라이언트에서도 해당 기능을 지원해야 한다.

2026-10-08 집사봇 `getMe` 실측은 `has_topics_enabled:false`, `allows_users_to_create_topics:false`였다. 기존 가족 DM을 유지하기 위해 이번 작업에서는 변경하지 않았다. 켜려면 기존 flat DM과 새 토픽의 맥락 연결·사용자별 동작을 먼저 검토한다. 폐기된 `dm.threadReplies` 설정을 부활시키지 않는다.

## 적용·검증 영수증

운영자가 그룹 토픽 기능의 실사용 성공을 확인했고 개인 사용을 계속하기로 했다. 추가 구성원의 사용·채널 운영은 착수 조건이 아니다. 구성원 호출 허용은 유지하되 실제 사용 확인을 강제하지 않는다.

- `config patch --dry-run`·`config validate` 통과; 의도한 glg 그룹 정책 외 DM/session·bindings·다른 봇 설정은 diff 동일.
- 설정은 Gateway 프로세스 재시작 없이 적용됐지만 Telegram 채널은 자동 재연결됐다. 이후 6계정 probe 전부 running/ok.
- General 토픽의 `:topic:1` 수신·응답은 Gateway 기록으로 확인했다. 추가 구성원 초대 알림에 답한 것은 그 사람의 직접 호출 성공과 구분한다; `chat.history` 발신자 메타데이터로 판별한다.
- 보호된 원본·patch·복구 영수증: private `~/openclaw/backups/family-group-20261008T155252/`, `family-spouse-20261008T161125/`. 공개 repo에 복사하지 않는다. 복구는 동시 변경을 확인한 뒤 해당 방의 마지막 변경만 되돌린다.
