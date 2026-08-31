#!/usr/bin/env python3
"""turnwatch 보조 — `openclaw cron list --all --json`을 잡별 한 줄로 편다.

2026.8.1 회귀 감시선: cron agentTurn 잡이 payload.model 없이 돌면
agents.defaults.model.primary(openai/*)로 떨어지고, openai 모델의 카탈로그 기본
런타임 codex가 disabled라 하드 실패한다 (2026-09-01 가족 cron 2건 실증).
"""
import json
import sys

data = json.load(sys.stdin)
for job in data.get("jobs", []):
	payload = job.get("payload") or {}
	kind = payload.get("kind") or "-"
	model = payload.get("model")
	state = job.get("state") or {}
	on = "on " if job.get("enabled") else "OFF"
	last = state.get("lastRunStatus") or "-"
	risky = kind == "agentTurn" and not model
	flag = "   <-- model 미지정: codex 낙하 위험" if risky else ""
	name = (job.get("name") or "?")[:40]
	print(f"  [{on}] {name:40s} kind={kind:10.10s} last={last:9.9s} "
	      f"model={model or '(defaults)'}{flag}")
