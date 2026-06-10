#!/usr/bin/env bash
# agent-audit — capture and measure each installed coding-agent client's
# fresh-chat prompt overhead. Run from the skill directory or pass --skill-dir.
#
# Usage:
#   ./audit.sh                       # all installed clients, table to stdout
#   ./audit.sh --raw                 # also keep raw captures in $AGENT_AUDIT_OUT_DIR
#   ./audit.sh --breakdown           # also print per-category composition tables
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

BREAKDOWN=0

ALL_CLIENTS=(claude opencode codex pi hermes cursor)
SELECTED=()

for arg in "$@"; do
	case "$arg" in
	--raw) KEEP_RAW=1 ;;
	--breakdown | -b) BREAKDOWN=1 ;;
	--help | -h)
		sed -n '2,13p' "$0"
		exit 0
		;;
	claude | opencode | codex | pi | hermes | cursor) SELECTED+=("$arg") ;;
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

# Results: lines of "client\tversion\tsystem_chars\tsystem_tokens\tfirst_turn_chars\tfirst_turn_tokens\tnote"
RESULTS_FILE="$OUT_DIR/results.tsv"
: >"$RESULTS_FILE"

emit() {
	# emit <client> <version> <system_chars> <system_tokens> <first_turn_chars> <first_turn_tokens> <note>
	printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" "$6" "$7" >>"$RESULTS_FILE"
}

count_chars() {
	# Print JavaScript string length of stdin, matching lib/categorize.mjs.
	node -e '
		let s = "";
		process.stdin.setEncoding("utf8");
		process.stdin.on("data", (chunk) => { s += chunk; });
		process.stdin.on("end", () => process.stdout.write(String(s.length)));
	'
}

estimate_tokens() {
	# chars/4 rounded.
	awk -v c="$1" 'BEGIN { printf "%d\n", (c + 2) / 4 }'
}

claude_system_chars() {
	node -e '
		const j = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
		let total = 0;
		for (const b of j.system || []) total += (typeof b === "string" ? b : (b.text || "")).length;
		process.stdout.write(String(total));
	' "$1"
}

claude_first_turn_chars() {
	node "$LIB_DIR/count-request.mjs" claude "$1"
}

openai_first_turn_chars() {
	node "$LIB_DIR/count-request.mjs" openai "$1"
}

start_openai_loopback() {
	# start_openai_loopback <capture> <port_file> <log_file>
	SKIP_TITLE_REQUEST="${SKIP_TITLE_REQUEST:-}" CAPTURE_OUT="$1" node "$LIB_DIR/openai-loopback.mjs" >"$2" 2>"$3" &
	printf '%s\n' "$!"
}

wait_for_port() {
	# wait_for_port <port_file> <pid>
	local port_file="$1" pid="$2" port=""
	for _ in $(seq 1 50); do
		if [ -s "$port_file" ]; then
			port="$(head -n1 "$port_file")"
			break
		fi
		sleep 0.1
	done
	if [ -z "$port" ]; then
		kill "$pid" 2>/dev/null || true
		return 1
	fi
	printf '%s\n' "$port"
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

# Tracked via a file because throwaway_cwd is called inside command
# substitution (a subshell), so bash array mutations would not survive.
THROWAWAY_LIST="$OUT_DIR/.throwaway-cwds"
: >"$THROWAWAY_LIST"

throwaway_cwd() {
	local d
	d="$(mktemp -d "${TMPDIR:-/tmp}/agent-audit-$1.XXXXXX")"
	printf '%s\n' "$d" >>"$THROWAWAY_LIST"
	printf '%s\n' "$d"
}

cleanup() {
	# Per-client throwaway cwds are pure scratch — remove unconditionally.
	if [ -s "$THROWAWAY_LIST" ]; then
		while IFS= read -r d; do
			[ -n "$d" ] && rm -rf "$d" 2>/dev/null || true
		done <"$THROWAWAY_LIST"
	fi
	# When not --raw and OUT_DIR wasn't user-provided, remove the whole OUT_DIR.
	if [ "$KEEP_RAW" -eq 0 ] && [ -z "${AGENT_AUDIT_OUT_DIR:-}" ]; then
		rm -rf "$OUT_DIR" 2>/dev/null || true
	fi
}
trap cleanup EXIT

# ---------- Claude Code ----------
audit_claude() {
	if ! have mise && ! have claude; then
		emit claude "not installed" 0 0 0 0 "no claude on PATH"
		return
	fi
	if ! have node; then
		emit claude "?" 0 0 0 0 "node required for loopback"
		return
	fi
	local version
	version="$(mise_x claude --version 2>/dev/null | awk '{print $1}')"
	[ -z "$version" ] && version="unknown"

	local cwd capture port_file log_file
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
		emit claude "$version" 0 0 0 0 "loopback failed to bind"
		return
	fi

	# Invoke claude with the loopback as the API endpoint. -p forces one-shot mode.
	# `|| true` because the dummy response may make claude exit non-zero on some versions.
	(cd "$cwd" &&
		ANTHROPIC_BASE_URL="http://127.0.0.1:$port" \
			ANTHROPIC_AUTH_TOKEN="audit-dummy" \
			ANTHROPIC_API_KEY="audit-dummy" \
			mise_x claude -p "hi" --output-format json >"$OUT_DIR/claude-stdout.json" 2>"$OUT_DIR/claude-stderr.log") || true

	# Loopback should have exited after capturing. Give it a moment.
	wait "$server_pid" 2>/dev/null || true

	if [ ! -s "$capture" ]; then
		emit claude "$version" 0 0 0 0 "no request captured"
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
		emit claude "$version" 0 0 0 0 "could not parse request body"
		return
	fi

	local system_chars system_tokens first_turn_chars first_turn_tokens
	system_chars=$(claude_system_chars "$capture")
	system_tokens=$(estimate_tokens "$system_chars")
	first_turn_chars=$(claude_first_turn_chars "$capture")
	first_turn_tokens=$(estimate_tokens "$first_turn_chars")
	emit claude "$version" "$system_chars" "$system_tokens" "$first_turn_chars" "$first_turn_tokens" "captured via loopback"
}

# ---------- OpenCode ----------
audit_opencode() {
	if ! have opencode; then
		emit opencode "not installed" 0 0 0 0 "no opencode on PATH"
		return
	fi
	if ! have node; then
		emit opencode "?" 0 0 0 0 "node required for plugin"
		return
	fi
	local version
	version="$(opencode --version 2>/dev/null | head -n1)"
	[ -z "$version" ] && version="unknown"

	local cwd system_capture request_capture model port_file log_file server_pid port
	cwd="$(throwaway_cwd opencode)"
	system_capture="$OUT_DIR/opencode-prompt.json"
	request_capture="$OUT_DIR/opencode-request.json"
	model="${OPENCODE_AUDIT_MODEL:-audit/audit-model}"
	port_file="$OUT_DIR/opencode.port"
	log_file="$OUT_DIR/opencode-loopback.log"

	SKIP_TITLE_REQUEST=1 server_pid="$(start_openai_loopback "$request_capture" "$port_file" "$log_file")"
	if ! port="$(wait_for_port "$port_file" "$server_pid")"; then
		emit opencode "$version" 0 0 0 0 "loopback failed to bind"
		return
	fi

	# Capture BOTH views from the same run:
	# - plugin: system/developer text assembled by OpenCode before provider call
	# - loopback: actual OpenAI-compatible first request, including tool schemas
	local plugin_url config
	plugin_url="file://$LIB_DIR/opencode-plugin.ts"
	config=$(printf '{"$schema":"https://opencode.ai/config.json","model":"%s","plugin":["%s"],"provider":{"audit":{"npm":"@ai-sdk/openai-compatible","name":"Audit Loopback","options":{"baseURL":"http://127.0.0.1:%s/v1","apiKey":"audit-dummy"},"models":{"audit-model":{"name":"Audit Model"}}}}}' "$model" "$plugin_url" "$port")

	(
		cd "$cwd" &&
			OC_AUDIT_OUT="$system_capture" \
				OC_AUDIT_NO_EXIT=1 \
				OPENCODE_CONFIG_CONTENT="$config" \
				opencode run --model "$model" "hi" >"$OUT_DIR/opencode-stdout.log" 2>"$OUT_DIR/opencode-stderr.log"
	) || true &
	local opencode_pid=$!
	for _ in $(seq 1 200); do
		[ -s "$system_capture" ] && [ -s "$request_capture" ] && break
		if ! kill -0 "$opencode_pid" 2>/dev/null && [ ! -s "$request_capture" ]; then
			break
		fi
		sleep 0.1
	done
	kill "$opencode_pid" 2>/dev/null || true
	wait "$opencode_pid" 2>/dev/null || true
	wait "$server_pid" 2>/dev/null || true

	if [ ! -s "$system_capture" ]; then
		emit opencode "$version" 0 0 0 0 "plugin did not capture; check stderr"
		return
	fi
	if [ ! -s "$request_capture" ]; then
		emit opencode "$version" 0 0 0 0 "provider request not captured; check loopback/stderr"
		return
	fi

	local prompt_file="$OUT_DIR/opencode-system.txt"
	if ! node -e '
		const j = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
		const sys = j.system || [];
		process.stdout.write(sys.join("\n\n"));
	' "$system_capture" >"$prompt_file"; then
		emit opencode "$version" 0 0 0 0 "could not parse plugin output"
		return
	fi

	local system_chars system_tokens first_turn_chars first_turn_tokens
	system_chars=$(count_chars <"$prompt_file")
	system_tokens=$(estimate_tokens "$system_chars")
	first_turn_chars=$(openai_first_turn_chars "$request_capture")
	first_turn_tokens=$(estimate_tokens "$first_turn_chars")
	emit opencode "$version" "$system_chars" "$system_tokens" "$first_turn_chars" "$first_turn_tokens" "captured via plugin + provider loopback"
}

# ---------- Codex ----------
audit_codex() {
	if ! mise_x codex --version >/dev/null 2>&1 && ! have codex; then
		emit codex "not installed" 0 0 0 0 "no codex on PATH"
		return
	fi
	local version
	version="$(mise_x codex --version 2>/dev/null | awk '{print $NF}')"
	[ -z "$version" ] && version="unknown"

	local cwd dump_file prompt_file request_capture port_file log_file server_pid port codex_home
	cwd="$(throwaway_cwd codex)"
	codex_home="$OUT_DIR/codex-home"
	mkdir -p "$codex_home"
	dump_file="$OUT_DIR/codex-prompt-input.json"
	prompt_file="$OUT_DIR/codex-system.txt"
	request_capture="$OUT_DIR/codex-request.json"
	port_file="$OUT_DIR/codex.port"
	log_file="$OUT_DIR/codex-loopback.log"

	if ! (cd "$cwd" && mise_x codex debug prompt-input "hi" >"$dump_file" 2>"$OUT_DIR/codex-debug-stderr.log"); then
		emit codex "$version" 0 0 0 0 "codex debug prompt-input failed"
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
		emit codex "$version" 0 0 0 0 "could not parse prompt-input"
		return
	fi

	server_pid="$(start_openai_loopback "$request_capture" "$port_file" "$log_file")"
	if ! port="$(wait_for_port "$port_file" "$server_pid")"; then
		emit codex "$version" 0 0 0 0 "loopback failed to bind"
		return
	fi
	cat >"$codex_home/config.toml" <<EOF
model = "audit-model"
model_provider = "audit"
approval_policy = "never"
sandbox_mode = "read-only"

[model_providers.audit]
name = "Audit Loopback"
base_url = "http://127.0.0.1:$port/v1"
env_key = "AGENT_AUDIT_DUMMY_KEY"
wire_api = "responses"
request_max_retries = 0
stream_max_retries = 0
EOF

	(cd "$cwd" &&
		CODEX_HOME="$codex_home" \
			AGENT_AUDIT_DUMMY_KEY="audit-dummy" \
			mise_x codex exec --skip-git-repo-check --ephemeral --model audit-model "hi" >"$OUT_DIR/codex-stdout.log" 2>"$OUT_DIR/codex-stderr.log") || true
	wait "$server_pid" 2>/dev/null || true

	if [ ! -s "$request_capture" ]; then
		emit codex "$version" 0 0 0 0 "provider request not captured; check loopback/stderr"
		return
	fi

	local system_chars system_tokens first_turn_chars first_turn_tokens
	system_chars=$(count_chars <"$prompt_file")
	system_tokens=$(estimate_tokens "$system_chars")
	first_turn_chars=$(openai_first_turn_chars "$request_capture")
	first_turn_tokens=$(estimate_tokens "$first_turn_chars")
	emit codex "$version" "$system_chars" "$system_tokens" "$first_turn_chars" "$first_turn_tokens" "captured via debug + provider loopback"
}

# ---------- pi ----------
audit_pi() {
	if ! mise_x pi --version >/dev/null 2>&1 && ! have pi; then
		emit pi "not installed" 0 0 0 0 "no pi on PATH"
		return
	fi
	if ! have node; then
		emit pi "?" 0 0 0 0 "node required for dump"
		return
	fi
	local version
	# pi writes --version to stderr on some builds; merge streams.
	version="$(mise_x pi --version 2>&1 | tail -n1 | awk '{print $NF}')"
	[ -z "$version" ] && version="unknown"

	local cwd prompt_file request_capture
	cwd="$(throwaway_cwd pi)"
	prompt_file="$OUT_DIR/pi-system.txt"
	request_capture="$OUT_DIR/pi-request.json"

	if ! (cd "$cwd" && node "$LIB_DIR/pi-dump.mjs" >"$prompt_file" 2>"$OUT_DIR/pi-stderr.log"); then
		emit pi "$version" 0 0 0 0 "pi-dump.mjs failed; see stderr"
		return
	fi
	if ! (cd "$cwd" && node "$LIB_DIR/pi-request-dump.mjs" >"$request_capture" 2>>"$OUT_DIR/pi-stderr.log"); then
		emit pi "$version" 0 0 0 0 "pi-request-dump.mjs failed; see stderr"
		return
	fi

	local system_chars system_tokens first_turn_chars first_turn_tokens
	system_chars=$(count_chars <"$prompt_file")
	system_tokens=$(estimate_tokens "$system_chars")
	first_turn_chars=$(openai_first_turn_chars "$request_capture")
	first_turn_tokens=$(estimate_tokens "$first_turn_chars")
	emit pi "$version" "$system_chars" "$system_tokens" "$first_turn_chars" "$first_turn_tokens" "rendered system + tool request locally"
}

# ---------- Hermes ----------
audit_hermes() {
	local cmd=""
	if have hermes; then
		cmd="hermes"
	elif have hermes-agent; then
		cmd="hermes-agent"
	else
		emit hermes "not installed" 0 0 0 0 "no hermes on PATH"
		return
	fi
	if ! have node; then
		emit hermes "?" 0 0 0 0 "node required for loopback"
		return
	fi

	local version
	version="$(python3 -c "import importlib.metadata; print(importlib.metadata.version('hermes-agent'))" 2>/dev/null ||
		ls -d /opt/homebrew/Cellar/hermes-agent/*/ 2>/dev/null | head -1 | xargs basename ||
		echo "unknown")"
	[ -z "$version" ] && version="unknown"

	local hermes_home cwd capture port_file log_file server_pid port
	hermes_home="$OUT_DIR/hermes-home"
	mkdir -p "$hermes_home"
	cwd="$(throwaway_cwd hermes)"
	capture="$OUT_DIR/hermes-request.json"
	port_file="$OUT_DIR/hermes.port"
	log_file="$OUT_DIR/hermes-loopback.log"

	server_pid="$(start_openai_loopback "$capture" "$port_file" "$log_file")"
	if ! port="$(wait_for_port "$port_file" "$server_pid")"; then
		emit hermes "$version" 0 0 0 0 "loopback failed to bind"
		return
	fi

	# Minimal config: redirect to loopback, disable retries, cap at 1 turn
	cat >"$hermes_home/config.yaml" <<EOF
model:
  provider: custom
  default: audit-model
  base_url: http://127.0.0.1:$port/v1
  api_key: audit-dummy
agent:
  max_turns: 1
  api_max_retries: 0
EOF

	(cd "$cwd" &&
		HERMES_HOME="$hermes_home" \
			"$cmd" chat -q "hi" >"$OUT_DIR/hermes-stdout.log" 2>"$OUT_DIR/hermes-stderr.log") || true
	wait "$server_pid" 2>/dev/null || true

	if [ ! -s "$capture" ]; then
		emit hermes "$version" 0 0 0 0 "provider request not captured; check hermes-stderr.log"
		return
	fi

	# Extract the system message text for SYS_* columns
	local prompt_file="$OUT_DIR/hermes-system.txt"
	node -e '
		const j = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
		const sys = (j.messages || []).find(m => m.role === "system");
		const text = typeof sys?.content === "string" ? sys.content
			: (sys?.content || []).map(c => c.text || "").join("");
		process.stdout.write(text);
	' "$capture" >"$prompt_file" 2>/dev/null || true

	local system_chars system_tokens first_turn_chars first_turn_tokens
	system_chars=$(count_chars <"$prompt_file")
	system_tokens=$(estimate_tokens "$system_chars")
	first_turn_chars=$(openai_first_turn_chars "$capture")
	first_turn_tokens=$(estimate_tokens "$first_turn_chars")
	emit hermes "$version" "$system_chars" "$system_tokens" "$first_turn_chars" "$first_turn_tokens" "captured via loopback"
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
		emit cursor "$version" 0 0 0 0 "no headless capture path; IDE-only"
	else
		emit cursor "not installed" 0 0 0 0 "no Cursor.app or CLI"
	fi
}

# ---------- run ----------
for c in "${SELECTED[@]}"; do
	"audit_$c"
done

# ---------- output ----------
printf '\n%-9s %-12s %10s %10s %10s %10s  %s\n' "CLIENT" "VERSION" "SYS_CHARS" "SYS_TOK" "FIRST_CH" "FIRST_TOK" "NOTE"
printf -- '%.0s-' {1..96}
printf '\n'
while IFS=$'\t' read -r client version system_chars system_tokens first_turn_chars first_turn_tokens note; do
	printf '%-9s %-12s %10s %10s %10s %10s  %s\n' "$client" "$version" "$system_chars" "$system_tokens" "$first_turn_chars" "$first_turn_tokens" "$note"
done <"$RESULTS_FILE"

# ---------- per-category breakdown ----------
if [ "$BREAKDOWN" -eq 1 ]; then
	if ! have node; then
		printf '\n(breakdown skipped: node not on PATH)\n'
	else
		# Collect only clients that captured data, then render unified table + top-5.
		CAPTURED_CLIENTS=()
		while IFS=$'\t' read -r client _version _system_chars _system_tokens first_turn_chars _first_turn_tokens _note; do
			[ "$first_turn_chars" = "0" ] && continue
			CAPTURED_CLIENTS+=("$client")
		done <"$RESULTS_FILE"
		if [ ${#CAPTURED_CLIENTS[@]} -gt 0 ]; then
			node "$LIB_DIR/breakdown-unified.mjs" "$OUT_DIR" "${CAPTURED_CLIENTS[@]}" || true
		fi
	fi
fi

if [ "$KEEP_RAW" -eq 1 ] || [ -n "${AGENT_AUDIT_OUT_DIR:-}" ]; then
	printf '\nRaw captures: %s\n' "$OUT_DIR"
fi
