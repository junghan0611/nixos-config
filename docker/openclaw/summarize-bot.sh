#!/usr/bin/env bash
# OpenClaw bots extract source text; the current agent turn writes the summary.
# Do not recursively call another agent or select a separate paid model.
set -euo pipefail
markdown_args=()
for arg in "$@"; do
	case "$arg" in
		--version|-V|--help|-h)
			exec node /usr/local/lib/node_modules/@steipete/summarize/dist/cli.js "$arg"
			;;
	esac
	case "${arg,,}" in
		--|--json|--json=*|--model|--model=*|--cli|--cli=*|--config|--config=*|--diarize*|--transcriber*|--identify-speakers*|--speaker-profile*|--remember-speakers*|--video-mode*|--markdown-mode*|--slides*|--fast|--service-tier*|transcriber|slides|serve|daemon|refresh-free|status)
			printf '%s\n' 'OpenClaw summarize is extract-only. Model/CLI/transcription/setup overrides and JSON output are disabled; summarize the extracted source in the current turn.' >&2
			exit 2
			;;
		http://*|https://*) markdown_args=(--markdown-mode readability) ;;
	esac
done
# Reuse the central API-key scrubber rather than copying its policy into this image.
wrapper=/home/junghan/repos/gh/agent-config/skills/summarize/scripts/summarize
if [[ ! -x "$wrapper" ]]; then
	printf '%s\n' 'Subscription-safe summarize wrapper unavailable; refusing extraction.' >&2
	exit 2
fi
printf '%s\n' 'OpenClaw summarize: source extraction only (up to 20000 characters); summarize it in the current turn. If truncated, use a browser or a narrower source instead of repeating this command.' >&2
# The central wrapper invokes bare summarize. Resolve that to the upstream binary,
# not back to this bot-only guard. This PATH change applies only to the child.
exec env PATH="/usr/local/libexec/summarize-upstream:$PATH" \
	"$wrapper" "$@" --extract "${markdown_args[@]}" --firecrawl off --max-extract-characters 20000
