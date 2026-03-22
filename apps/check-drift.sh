#!/usr/bin/env bash

set -euETo pipefail
shopt -s inherit_errexit 2>/dev/null || :

ROOT="${1:-$(pwd)}"
MODULES="$ROOT/modules/servers"
REPORT="{}"
DRIFT_FOUND=0

log() { echo "==> $*" >&2; }

# ── Extract expected tools from a server module file ─────────────
expected_tools() {
	local file="$1"
	grep -oP 'tools\s*=\s*\[\K[^]]+' "$file" 2>/dev/null |
		tr -d '"' | tr ' ' '\n' | sort | grep -v '^$' || true
}

# ── Query runtime tools via MCP protocol ─────────────────────────
runtime_tools() {
	local bin="$1"
	printf '%s\n%s\n' \
		'{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"drift-check","version":"0.1"}}}' \
		'{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' |
		timeout 15 "$bin" --stdio 2>/dev/null |
		grep -o '"tools":\[.*\]' |
		head -1 |
		python3 -c "
import json, sys
try:
    data = json.loads('{' + sys.stdin.read() + '}')
    for t in sorted(data.get('tools', []), key=lambda x: x['name']):
        print(t['name'])
except:
    pass
" 2>/dev/null || true
}

# ── Add to JSON report ───────────────────────────────────────────
add_report() {
	local name="$1" status="$2" added="$3" removed="$4"
	REPORT=$(echo "$REPORT" | jq \
		--arg name "$name" \
		--arg status "$status" \
		--arg added "$added" \
		--arg removed "$removed" \
		'.[$name] = {status: $status, added: ($added | split(",") | map(select(. != ""))), removed: ($removed | split(",") | map(select(. != "")))}')
}

# ── Check each server ────────────────────────────────────────────
for module in "$MODULES"/*.nix; do
	name=$(basename "$module" .nix)
	log "Checking $name"

	expected=$(expected_tools "$module")
	if [[ -z "$expected" ]]; then
		log "  No tools defined in module, skipping"
		add_report "$name" "no-tools-defined" "" ""
		continue
	fi

	# Build the package first
	if ! nix build "$ROOT#$name" --no-link 2>/dev/null; then
		log "  Build failed, skipping runtime check"
		add_report "$name" "build-failed" "" ""
		continue
	fi

	# Get the built binary path
	local_bin=$(nix build "$ROOT#$name" --print-out-paths 2>/dev/null)/bin/"$name"
	if [[ ! -x "$local_bin" ]]; then
		log "  Binary not found at $local_bin, skipping"
		add_report "$name" "no-binary" "" ""
		continue
	fi

	# Query runtime tools
	actual=$(runtime_tools "$local_bin")

	if [[ -z "$actual" ]]; then
		log "  Runtime query failed (needs auth?)"
		add_report "$name" "runtime-failed" "" ""
		continue
	fi

	# Diff
	added=$(comm -13 <(echo "$expected" | sort) <(echo "$actual" | sort) | paste -sd, -)
	removed=$(comm -23 <(echo "$expected" | sort) <(echo "$actual" | sort) | paste -sd, -)

	if [[ -n "$added" || -n "$removed" ]]; then
		log "  DRIFT DETECTED"
		[[ -n "$added" ]] && log "    Added: $added"
		[[ -n "$removed" ]] && log "    Removed: $removed"
		add_report "$name" "drift" "$added" "$removed"
		DRIFT_FOUND=1
	else
		log "  OK"
		add_report "$name" "ok" "" ""
	fi
done

# ── Output report ────────────────────────────────────────────────
echo "$REPORT" | jq .

if [[ "$DRIFT_FOUND" -eq 1 ]]; then
	log "Tool drift detected — review report above"
	exit 1
fi

log "No drift detected"
exit 0
