#!/usr/bin/env bash

set -euETo pipefail
shopt -s inherit_errexit 2>/dev/null || :

ROOT="${1:-$(pwd)}"
MODULES="$ROOT/modules/servers"
PASS=0
FAIL=0
SKIP=0

log() { echo "==> $*" >&2; }

# ── MCP initialize request payload ──────────────────────────────
INIT_REQUEST='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"health-check","version":"0.1"}}}'

# ── Verify response is valid MCP JSON-RPC ────────────────────────
validate_response() {
	local response="$1" name="$2"
	if echo "$response" | python3 -c "
import json, sys
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    try:
        msg = json.loads(line)
        if 'result' in msg and 'capabilities' in msg.get('result', {}):
            sys.exit(0)
    except json.JSONDecodeError:
        continue
sys.exit(1)
" 2>/dev/null; then
		return 0
	fi
	return 1
}

# ── Check stdio server ──────────────────────────────────────────
check_stdio() {
	local name="$1" bin="$2"
	local response
	response=$(printf '%s\n' "$INIT_REQUEST" | timeout 15 "$bin" --stdio 2>/dev/null) || true

	if [[ -z "$response" ]]; then
		log "  FAIL: no response from --stdio"
		return 1
	fi

	if validate_response "$response" "$name"; then
		return 0
	fi

	log "  FAIL: response is not valid MCP initialize result"
	return 1
}

# ── Extract meta.modes from server module ────────────────────────
has_stdio() {
	local file="$1"
	grep -q 'stdio\s*=' "$file" 2>/dev/null
}

# ── Check if server requires credentials ─────────────────────────
needs_credentials() {
	local file="$1"
	grep -q 'credentialVars' "$file" 2>/dev/null
}

is_required_credential() {
	local file="$1"
	grep -q 'required\s*=\s*true' "$file" 2>/dev/null
}

# ── Check each server ────────────────────────────────────────────
for module in "$MODULES"/*.nix; do
	name=$(basename "$module" .nix)

	# Skip servers that require credentials (can't start without auth)
	if needs_credentials "$module" && is_required_credential "$module"; then
		log "$name: SKIP (requires credentials)"
		SKIP=$((SKIP + 1))
		continue
	fi

	# Skip if no stdio mode (HTTP-only servers like aws-mcp can't be probed this way)
	if ! has_stdio "$module"; then
		log "$name: SKIP (no stdio mode)"
		SKIP=$((SKIP + 1))
		continue
	fi

	# Build the package
	if ! nix build "$ROOT#$name" --no-link 2>/dev/null; then
		log "$name: FAIL (build failed)"
		FAIL=$((FAIL + 1))
		continue
	fi

	# Get the built binary path
	outpath=$(nix build "$ROOT#$name" --print-out-paths 2>/dev/null)
	bin="$outpath/bin/$name"
	if [[ ! -x "$bin" ]]; then
		log "$name: FAIL (binary not found at $bin)"
		FAIL=$((FAIL + 1))
		continue
	fi

	# Run stdio health check
	if check_stdio "$name" "$bin"; then
		log "$name: OK"
		PASS=$((PASS + 1))
	else
		FAIL=$((FAIL + 1))
	fi
done

# ── Summary ──────────────────────────────────────────────────────
echo ""
log "Results: $PASS passed, $FAIL failed, $SKIP skipped"

if [[ "$FAIL" -gt 0 ]]; then
	exit 1
fi

exit 0
