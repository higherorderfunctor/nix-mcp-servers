#!/usr/bin/env bash

set -euETo pipefail
shopt -s inherit_errexit 2>/dev/null || :

ROOT="${1:-$(pwd)}"
OVERLAYS="$ROOT/overlays"
LOCKS="$OVERLAYS/locks"
GENERATED="$OVERLAYS/.nvfetcher/generated.json"
HASHES="$OVERLAYS/hashes.json"

log() { echo "==> $*" >&2; }

# ── helpers ────────────────────────────────────────────────────────
inject_hash() {
	local key=$1 field=$2 value=$3
	local tmp
	tmp=$(mktemp)
	jq --arg key "$key" --arg field "$field" --arg val "$value" \
		'.[$key][$field] = $val' "$HASHES" >"$tmp" && mv "$tmp" "$HASHES"
}

# ── 1. nix flake update ─────────────────────────────────────────
log "Updating flake inputs"
nix flake update --flake "$ROOT"

# ── 2. nvfetcher ─────────────────────────────────────────────────
log "Running nvfetcher"
nvfetcher -c "$ROOT/nvfetcher.toml" -o "$OVERLAYS/.nvfetcher"

log "Formatting generated files"
alejandra -q "$OVERLAYS/.nvfetcher/generated.nix"

# ── 3. Regenerate npm lock files ─────────────────────────────────
regen_lock_tarball() {
	local name=$1 nv_key=$2
	local url
	url=$(jq -r ".\"$nv_key\".src.url" "$GENERATED")
	local tmp
	tmp=$(mktemp -d)

	log "Regenerating lock for $name"
	curl -sL "$url" | tar xz -C "$tmp"
	(cd "$tmp/package" && npm install --package-lock-only --ignore-scripts --silent 2>/dev/null)
	cp "$tmp/package/package-lock.json" "$LOCKS/${name}-package-lock.json"
	rm -rf "$tmp"
}

regen_lock_git() {
	local name=$1 nv_key=$2
	local url rev
	url=$(jq -r ".\"$nv_key\".src.url" "$GENERATED")
	rev=$(jq -r ".\"$nv_key\".src.rev" "$GENERATED")
	local tmp
	tmp=$(mktemp -d)

	log "Regenerating lock for $name (${rev:0:12})"
	git clone --depth 1 "$url" "$tmp/repo" 2>/dev/null
	(cd "$tmp/repo" && npm install --package-lock-only --ignore-scripts --silent 2>/dev/null)
	cp "$tmp/repo/package-lock.json" "$LOCKS/${name}-package-lock.json"
	rm -rf "$tmp"
}

# ── 4. Inject npmDepsHash into hashes.json ─────────────────────
update_npm_hash() {
	local name=$1 nv_key=$2
	local lock="$LOCKS/${name}-package-lock.json"

	log "Prefetching npmDepsHash for $name"
	local hash
	hash=$(prefetch-npm-deps "$lock" 2>/dev/null)
	inject_hash "$nv_key" "npmDepsHash" "$hash"
}

# ── 5. Inject Go vendorHash into hashes.json ───────────────────
update_vendor_hash() {
	local nv_key=$1

	log "Prefetching vendorHash for $nv_key"
	# Temporarily set a bogus hash so nix build fails with the real one
	inject_hash "$nv_key" "vendorHash" "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
	git -C "$ROOT" add "$HASHES"

	local hash
	hash=$(
		nix build "$ROOT#github-mcp" 2>&1 |
			grep -oP 'got:\s+\Ksha256-[A-Za-z0-9+/=]+' |
			head -1
	) || true

	if [[ -n "$hash" ]]; then
		inject_hash "$nv_key" "vendorHash" "$hash"
	else
		log "WARNING: vendorHash for $nv_key may already be correct"
		git -C "$ROOT" checkout -- "$HASHES"
	fi
}

update_vendor_hash github-mcp-server

# ── 6. Verify ────────────────────────────────────────────────────
log "Staging changes"
git -C "$ROOT" add -A

log "Verifying all packages evaluate"
nix flake show "$ROOT" 2>&1 | grep "package '" >&2 || true

log "Done — review changes with: git diff --cached"
