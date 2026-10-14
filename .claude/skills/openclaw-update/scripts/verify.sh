#!/usr/bin/env bash
# Post-swap verification without model calls. Usage: verify.sh [<receipts-dir with openclaw.json.pre-swap>]
set -uo pipefail
G="docker exec openclaw-gateway openclaw"
PRE="${1:-}"

echo "== version / container"
$G --version
docker inspect openclaw-gateway --format 'restarts={{.RestartCount}} health={{.State.Health.Status}} started={{.State.StartedAt}}'

echo "== RPC health"
$G gateway call health --json --timeout 30000 2>/dev/null | python3 -c '
import json,sys
d=json.load(sys.stdin)
print("  ok=",d.get("ok"))
for k,v in d.get("channels",{}).items():
	a=v.get("accounts",{})
	c=sum(1 for s in a.values() if s.get("connected")); e=sum(1 for s in a.values() if s.get("lastError"))
	print("  %s: connected %d/%d, lastError %d" % (k, c, len(a), e))
p=d.get("plugins",{}); print("  plugin errors:",p.get("errors"),"unavailable:",p.get("unavailable"))
print("  eventLoop degraded:",d.get("eventLoop",{}).get("degraded"),"| deliveryQueues:",d.get("deliveryQueues"),"(failed=1 June tombstone is baseline)")'

echo "== plugins that matter"
$G plugins list --json 2>/dev/null | python3 -c '
import json,sys
d=json.load(sys.stdin); ps=d.get("plugins",d) if isinstance(d,dict) else d
for p in ps:
	if p.get("id") in ("zai","codex","openai","anthropic","telegram","xai","memory-core"):
		print("  ",p.get("id"),p.get("status"),p.get("origin"))'

echo "== hotfix markers in /app/dist"
docker exec openclaw-gateway sh -c 'grep -l "operator-hotfix:" /app/dist/*.mjs 2>/dev/null | while read f; do echo "  $(basename $f) $(grep -o "operator-hotfix: [^\"]*" $f | head -1) sha=$(sha256sum $f | cut -c1-16)"; done'

if [ -n "$PRE" ] && [ -f "$PRE/openclaw.json.pre-swap" ]; then
	echo "== openclaw.json diff vs pre-swap"
	python3 - "$PRE/openclaw.json.pre-swap" "$HOME/openclaw/config/openclaw.json" <<'EOF'
import json,sys
def flat(o,p=""):
	if isinstance(o,dict):
		for k,v in o.items(): yield from flat(v,f"{p}.{k}" if p else k)
	else: yield (p,json.dumps(o,sort_keys=True))
a=dict(flat(json.load(open(sys.argv[1])))); b=dict(flat(json.load(open(sys.argv[2]))))
ch=[k for k in sorted(set(a)|set(b)) if a.get(k)!=b.get(k)]
print(f"  changed paths: {len(ch)}")
for k in ch: print("   ",k)
print("  codex.enabled:", json.load(open(sys.argv[2]))["plugins"]["entries"]["codex"].get("enabled"))
EOF
fi

echo "== cron"
$G gateway call cron.list --json --timeout 30000 2>/dev/null | python3 -c '
import json,sys,datetime as dt
kst=dt.timezone(dt.timedelta(hours=9))
for j in json.load(sys.stdin)["jobs"]:
	s=j["state"]; print("  ",j["enabled"],j["name"],"next",dt.datetime.fromtimestamp(s["nextRunAtMs"]/1000,kst).strftime("%m-%d %H:%M"),"errs",s.get("consecutiveErrors"))'

echo "== memory index (files/eligible)"
for a in main glg gpt mini gemini bbot; do
	$G memory status --agent $a --json 2>/dev/null | python3 -c '
import json,sys
d=json.load(sys.stdin); d=d[0] if isinstance(d,list) else d; st=d.get("status",d)
print("  ",sys.argv[1]," ".join("%s=%s/%s"%(s["source"],s["files"],s["eligible"]) for s in st.get("sourceCounts",[])),"dirty=",st.get("dirty"))' $a
done

echo "== new .bak since container start"
since=$(docker inspect openclaw-gateway --format '{{.State.StartedAt}}')
find "$HOME/openclaw/config" -name '*.bak' -newermt "$since" -printf '%s\n' 2>/dev/null | awk '{s+=$1} END{printf "  %d files, %.2f GiB\n",NR,s/1073741824}'

echo "== serving 8+3 (expect 200 except claw/map 302, comments 404 + ping pong)"
for h in agenda analytics ax claw comments forge ha map; do
	printf '  %-10s %s\n' "$h" "$(curl -sS -m 12 -o /dev/null -w '%{http_code}' https://$h.junghanacs.com/)"
done
printf '  %-10s %s\n' aionsclubs "$(curl -sS -m 12 -o /dev/null -w '%{http_code}' https://aionsclubs.org/)"
printf '  %-10s %s\n' tailnet "$(curl -sS -m 10 -o /dev/null -w '%{http_code}' https://oracle.tailb0e905.ts.net/)"
printf '  %-10s %s\n' ping "$(curl -sS -m 10 https://comments.junghanacs.com/api/v1/ping)"
