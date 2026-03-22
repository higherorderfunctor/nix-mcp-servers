#!/usr/bin/env bash
set -euETo pipefail
shopt -s inherit_errexit 2>/dev/null || :

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

[[ -z "$FILE_PATH" || ! -f "$FILE_PATH" ]] && exit 0

# Skip files outside the project directory
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-}"
if [[ -n "$PROJECT_DIR" && "$FILE_PATH" != "$PROJECT_DIR"/* ]]; then
	exit 0
fi

ERRORS=()

run_check() {
	local label=$1
	shift
	local output
	if ! output=$("$@" 2>&1); then
		ERRORS+=("$label:
$output")
	fi
}

EXT="${FILE_PATH##*.}"
case "$EXT" in
nix | sh | bash | md | json | toml) run_check dprint dprint fmt "$FILE_PATH" ;;
esac

case "$EXT" in
nix)
	run_check deadnix deadnix --no-lambda-pattern-names --fail "$FILE_PATH"
	run_check statix statix check "$FILE_PATH"
	;;
sh | bash)
	run_check shellcheck shellcheck "$FILE_PATH"
	run_check shellharden shellharden --check "$FILE_PATH"
	;;
esac

if [[ ${#ERRORS[@]} -gt 0 ]]; then
	{
		echo "Lint/format issues in $FILE_PATH:"
		printf '%s\n' "${ERRORS[@]}"
	} >&2
	exit 2
fi
