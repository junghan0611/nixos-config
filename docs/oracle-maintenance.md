# Oracle 분기 유지보수·재부팅

실행 절차의 정본은 리포 전용 **[oracle-reboot 스킬](../.claude/skills/oracle-reboot/SKILL.md)**이다. 승인 범위·개별 정리·명령별 권한·만료가 있는 실제 유휴 게이트·재접속 후 복구를 그 절차대로 수행한다. 이 문서에 별도 절차를 복제하지 않는다.

삭제 없는 사전 수집은 `./run.sh` → **d**(Oracle), 또는 리포 루트에서:

```bash
bash scripts/oracle-maintenance-preflight.sh
```

영수증은 `.agent-reports/oracle-maintenance/`에 비공개로 영속 보존한다. 정리/재부팅/버전업은 명시 승인 없이 수행하지 않는다. 새 자동 재부팅기·cron·watcher를 설치하는 스킬이 아니다.
