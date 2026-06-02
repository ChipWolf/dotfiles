#!/usr/bin/env bash
# agent-audit — capture and measure the system prompt of each installed
# coding-agent client. Run from the skill directory or pass --skill-dir.
#
# Usage:
#   ./audit.sh                       # all installed clients, table to stdout
#   ./audit.sh --raw                 # also keep raw captures in $AGENT_AUDIT_OUT_DIR
#   ./audit.sh claude codex          # subset of clients
#
# Env overrides:
#   AGENT_AUDIT_OUT_DIR  output dir (default: $TMPDIR/agent-audit-<ts>)
#   OPENCODE_AUDIT_MODEL model id for the audit run (default: opencode/deepseek-v4-flash-free)
#   PI_INSTALL_DIR       override pi install path (see lib/pi-dump.mjs)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

TS="$(date +%Y%m%d-%H%M%S)"
OUT_DIR="${AGENT_AUDIT_OUT_DIR:-${TMPDIR:-/tmp}/agent-audit-$TS}"
KEEP_RAW=0

ALL_CLIENTS=(claude opencode codex pi cursor)
SELECTED=()

for arg in "$@"; do
	case "$arg" in
	--raw) KEEP_RAW=1 ;;
	--help | -h)
		sed -n '2,12p' "$0"
		exit 0
		;;
	claude | opencode | codex | pi | cursor) SELECTED+=("$arg") ;;
	*)
		echo "agent-audit: unknown argument: $arg" >&2
		exit 2
		;;
	esac
done

if [ ${#SELECTED[@]} -eq 0 ]; then
	SELECTED=("${ALL_CLIENTS[@]}")
fi

mkdir -p "$OUT_DIR"

# Results: lines of "client\tversion\tchars\ttokens\tnote"
RESULTS_FILE="$OUT_DIR/results.tsv"
: >"$RESULTS_FILE"

emit() {
	# emit <client> <version> <chars> <tokens> <note>
	printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" >>"$RESULTS_FILE"
}

count_chars() {
	# Print byte count of stdin, treating it as text.
	wc -c | tr -d ' '
}

estimate_tokens() {
	# chars/4 rounded.
	awk -v c="$1" 'BEGIN { printf "%d\n", (c + 2) / 4 }'
}

have() { command -v "$1" >/dev/null 2>&1; }

mise_x() {
	# Run a mise-managed tool. Falls back to direct invocation if mise isn't here.
	if have mise; then
		mise x -- "$@"
	else
		"$@"
	fi
}

throwaway_cwd() {
	local d
	d="$(mktemp -d "${TMPDIR:-/tmp}/agent-audit-$1.XXXXXX")"
	printf '%s\n' "$d"
}

# ---------- Claude Code ----------
audit_claude() {
	if ! have mise && ! have claude; then
		emit claude "not installed" 0 0 "no claude on PATH"
		return
	fi
	if ! have node; then
		emit claude "?" 0 0 "node required for loopback"
		return
	fi
	local version
	version="$(mise_x claude --version 2>/dev/null | awk '{print $1}')"
	[ -z "$version" ] && version="unknown"

	local cwd capture port_file body_file log_file
	cwd="$(throwaway_cwd claude)"
	capture="$OUT_DIR/claude-request.json"
	port_file="$OUT_DIR/claude.port"
	log_file="$OUT_DIR/claude-loopback.log"

	# Start loopback; the helper prints the bound port on its first stdout line.
	CAPTURE_OUT="$capture" node "$LIB_DIR/claude-loopback.mjs" >"$port_file" 2>"$log_file" &
	local server_pid=$!

	# Wait up to 5 s for the port file to be populated.
	local port=""
	for _ in $(seq 1 50); do
		if [ -s "$port_file" ]; then
			port="$(head -n1 "$port_file")"
			break
		fi
		sleep 0.1
	done
	if [ -z "$port" ]; then
		kill "$server_pid" 2>/dev/null || true
		emit claude "$version" 0 0 "loopback failed to bind"
		return
	fi

	# Invoke claude with the loopback as the API endpoint. -p forces one-shot mode.
	# `|| true` because the dummy response may make claude exit non-zero on some versions.
	(cd "$cwd" && \
		ANTHROPIC_BASE_URL="http://127.0.0.1:$port" \
		ANTHROPIC_AUTH_TOKEN="audit-dummy" \
		ANTHROPIC_API_KEY="audit-dummy" \
		mise_x claude -p "hi" --output-format json >"$OUT_DIR/claude-stdout.json" 2>"$OUT_DIR/claude-stderr.log") || true

	# Loopback should have exited after capturing. Give it a moment.
	wait "$server_pid" 2>/dev/null || true

	if [ ! -s "$capture" ]; then
		emit claude "$version" 0 0 "no request captured"
		return
	fi

	# Extract the system field's text content. The "system" array contains
	# objects like {"type":"text","text":"..."}; sum all .text values.
	local prompt_file="$OUT_DIR/claude-system.txt"
	if ! node -e '
		const j = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
		const sys = j.system;
		if (Array.isArray(sys)) {
		  process.stdout.write(sys.map(b => (typeof b === "string" ? b : (b.text || ""))).join("\n\n"));
		} else if (typeof sys === "string") {
		  process.stdout.write(sys);
		}
	' "$capture" >"$prompt_file"; then
		emit claude "$version" 0 0 "could not parse request body"
		return
	fi

	local chars tokens
	chars=$(count_chars <"$prompt_file")
	tokens=$(estimate_tokens "$chars")
	emit claude "$version" "$chars" "$tokens" "captured via loopback"
}

# ---------- OpenCode ----------
audit_opencode() {
	if ! have opencode; then
		emit opencode "not installed" 0 0 "no opencode on PATH"
		return
	fi
	if ! have node; then
		emit opencode "?" 0 0 "node required for plugin"
		return
	fi
	local version
	version="$(opencode --version 2>/dev/null | head -n1)"
	[ -z "$version" ] && version="unknown"

	local cwd capture model
	cwd="$(throwaway_cwd opencode)"
	capture="$OUT_DIR/opencode-prompt.json"
	model="${OPENCODE_AUDIT_MODEL:-opencode/deepseek-v4-flash-free}"

	# Pass the plugin via the escape-hatch env var. The plugin exits before any
	# tokens are spent; model just needs to resolve to a registered provider.
	local plugin_url config
	plugin_url="file://$LIB_DIR/opencode-plugin.ts"
	config=$(printf '{"$schema":"https://opencode.ai/config.json","plugin":["%s"]}' "$plugin_url")

	(cd "$cwd" && \
		OC_AUDIT_OUT="$capture" \
		OPENCODE_CONFIG_CONTENT="$config" \
		opencode run --model "$model" "hi" >"$OUT_DIR/opencode-stdout.log" 2>"$OUT_DIR/opencode-stderr.log") || true

	if [ ! -s "$capture" ]; then
		emit opencode "$version" 0 0 "plugin did not capture; check stderr"
		return
	fi

	local prompt_file="$OUT_DIR/opencode-system.txt"
	if ! node -e '
		const j = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
		const sys = j.system || [];
		process.stdout.write(sys.join("\n\n"));
	' "$capture" >"$prompt_file"; then
		emit opencode "$version" 0 0 "could not parse plugin output"
		return
	fi

	local chars tokens
	chars=$(count_chars <"$prompt_file")
	tokens=$(estimate_tokens "$chars")
	emit opencode "$version" "$chars" "$tokens" "captured via plugin hook"
}

# ---------- Codex ----------
audit_codex() {
	if ! mise_x codex --version >/dev/null 2>&1 && ! have codex; then
		emit codex "not installed" 0 0 "no codex on PATH"
		return
	fi
	local version
	version="$(mise_x codex --version 2>/dev/null | awk '{print $NF}')"
	[ -z "$version" ] && version="unknown"

	local cwd dump_file prompt_file
	cwd="$(throwaway_cwd codex)"
	dump_file="$OUT_DIR/codex-prompt-input.json"
	prompt_file="$OUT_DIR/codex-system.txt"

	if ! (cd "$cwd" && mise_x codex debug prompt-input "hi" >"$dump_file" 2>"$OUT_DIR/codex-stderr.log"); then
		emit codex "$version" 0 0 "codex debug prompt-input failed"
		return
	fi

	# prompt-input.json is an array of messages. Take everything from messages
	# with role=developer (Codex's locally-built system payload).
	if ! node -e '
		const j = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
		const out = [];
		const walk = (arr) => {
		  for (const m of arr) {
		    if (m && m.role === "developer" && Array.isArray(m.content)) {
		      for (const c of m.content) {
		        if (typeof c === "string") out.push(c);
		        else if (c && c.text) out.push(c.text);
		      }
		    }
		  }
		};
		if (Array.isArray(j)) walk(j);
		else if (j && Array.isArray(j.input)) walk(j.input);
		process.stdout.write(out.join("\n\n"));
	' "$dump_file" >"$prompt_file"; then
		emit codex "$version" 0 0 "could not parse prompt-input"
		return
	fi

	local chars tokens
	chars=$(count_chars <"$prompt_file")
	tokens=$(estimate_tokens "$chars")
	emit codex "$version" "$chars" "$tokens" "captured via debug prompt-input"
}

# ---------- pi ----------
audit_pi() {
	if ! mise_x pi --version >/dev/null 2>&1 && ! have pi; then
		emit pi "not installed" 0 0 "no pi on PATH"
		return
	fi
	if ! have node; then
		emit pi "?" 0 0 "node required for dump"
		return
	fi
	local version
	# pi writes --version to stderr on some builds; merge streams.
	version="$(mise_x pi --version 2>&1 | tail -n1 | awk '{print $NF}')"
	[ -z "$version" ] && version="unknown"

	local cwd prompt_file
	cwd="$(throwaway_cwd pi)"
	prompt_file="$OUT_DIR/pi-system.txt"

	if ! (cd "$cwd" && node "$LIB_DIR/pi-dump.mjs" >"$prompt_file" 2>"$OUT_DIR/pi-stderr.log"); then
		emit pi "$version" 0 0 "pi-dump.mjs failed; see stderr"
		return
	fi

	local chars tokens
	chars=$(count_chars <"$prompt_file")
	tokens=$(estimate_tokens "$chars")
	emit pi "$version" "$chars" "$tokens" "rendered via buildSystemPrompt"
}

# ---------- Cursor ----------
audit_cursor() {
	# Cursor has no headless CLI mode and the app may not be installed.
	if [ -d "/Applications/Cursor.app" ] || have cursor-agent || have cursor; then
		local version="unknown"
		if [ -f "/Applications/Cursor.app/Contents/Info.plist" ]; then
			version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
				"/Applications/Cursor.app/Contents/Info.plist" 2>/dev/null || echo unknown)"
		fi
		emit cursor "$version" 0 0 "no headless capture path; IDE-only"
	else
		emit cursor "not installed" 0 0 "no Cursor.app or CLI"
	fi
}

# ---------- run ----------
for c in "${SELECTED[@]}"; do
	"audit_$c"
done

# ---------- output ----------
printf '\n%-9s %-12s %10s %10s  %s\n' "CLIENT" "VERSION" "CHARS" "~TOKENS" "NOTE"
printf -- '%.0s-' {1..72}
printf '\n'
while IFS=$'\t' read -r client version chars tokens note; do
	printf '%-9s %-12s %10s %10s  %s\n' "$client" "$version" "$chars" "$tokens" "$note"
done <"$RESULTS_FILE"

printf '\nRaw captures: %s\n' "$OUT_DIR"
if [ "$KEEP_RAW" -eq 0 ] && [ -z "${AGENT_AUDIT_OUT_DIR:-}" ]; then
	# Keep results.tsv and per-client .txt; remove transient logs.
	find "$OUT_DIR" -maxdepth 1 -type f \
		\( -name '*.log' -o -name '*.port' -o -name '*-stdout.*' -o -name '*-stderr.*' \) \
		-delete 2>/dev/null || true
fi
