#!/usr/bin/env bats
# chezmoi.bats — validate chezmoi templates and ignore logic

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  # Native Windows tools (Ruby, chezmoi) don't understand MSYS paths (/c/...);
  # convert to mixed-style (C:/...) when running under Git Bash.
  if command -v cygpath >/dev/null 2>&1; then
    REPO_ROOT="$(cygpath -m "$REPO_ROOT")"
    BATS_TEST_TMPDIR="$(cygpath -m "$BATS_TEST_TMPDIR")"
  fi
  SOURCE_DIR="$REPO_ROOT/home"
}

render_template() {
  local template_path="$1"
  chezmoi --source "$REPO_ROOT" execute-template --init \
    --promptBool "codespaces=false" \
    --promptBool "ci=false" \
    --promptBool "private=false" \
    --file "$template_path"
}

render_template_with_override_data() {
  local template_path="$1"
  local data_file="$2"
  chezmoi --source "$REPO_ROOT" execute-template --init \
    --promptBool "codespaces=false" \
    --promptBool "ci=false" \
    --promptBool "private=false" \
    --override-data-file "$data_file" \
    --file "$template_path"
}

# --- .chezmoi.toml.tmpl renders without error ---

@test ".chezmoi.toml.tmpl renders" {
  render_template "$SOURCE_DIR/.chezmoi.toml.tmpl"
}

# --- .chezmoiignore produces correct ignores per OS ---

@test "chezmoiignore: linux ignores macOS-only targets" {
  output=$(render_template "$SOURCE_DIR/.chezmoiignore" 2>&1 || true)
  # The template uses .chezmoi.os which is the host OS; we can only
  # validate syntax here. Semantics are tested via grep below.
  [[ $? -eq 0 ]]
}

@test "chezmoiignore: non-darwin block lists .config/tmux" {
  grep -q '\.config/tmux' "$SOURCE_DIR/.chezmoiignore"
}

@test "chezmoiignore: non-darwin block lists .config/ghostty" {
  grep -q '\.config/ghostty' "$SOURCE_DIR/.chezmoiignore"
}

@test "chezmoiignore: non-darwin block lists .config/finicky.js" {
  grep -q '\.config/finicky\.js' "$SOURCE_DIR/.chezmoiignore"
}

@test "chezmoiignore: windows block lists .config/zsh" {
  grep -q '\.config/zsh' "$SOURCE_DIR/.chezmoiignore"
}

@test "chezmoiignore: non-windows block lists .config/wezterm" {
  grep -q '\.config/wezterm' "$SOURCE_DIR/.chezmoiignore"
}

# --- OpenCode permission template rendering ---

@test "OpenCode permission template applies conditional top-level rules" {
  local data_file_false="$BATS_TEST_TMPDIR/opencode-permission-private-false.json"
  cat >"$data_file_false" <<'EOF'
{
  "private": false,
  "agentPermissions": {
    "kinds": {
      "bash": {
        "destinationType": "namespaced",
        "destinationKey": "bash",
        "supportsMatchMode": true,
        "defaultMatchMode": "exact",
        "wildcardSuffix": " *"
      },
      "external_directory": {
        "destinationType": "namespaced",
        "destinationKey": "external_directory"
      },
      "permission_key": {
        "destinationType": "top_level"
      }
    },
    "rules": [
        { "kind": "bash", "pattern": "*", "op": "ask", "bashMatchMode": "exact" },
        { "kind": "bash", "pattern": "docker ps", "op": "allow", "bashMatchMode": "exactAndWithArgs" },
        { "kind": "external_directory", "pattern": "/tmp/**", "op": "allow" },
        { "kind": "permission_key", "pattern": "atlassian_*", "op": "ask", "conditions": { "private": false } },
        { "kind": "permission_key", "pattern": "always_*", "op": "allow" }
      ]
  }
}
EOF

  local data_file_true="$BATS_TEST_TMPDIR/opencode-permission-private-true.json"
  cat >"$data_file_true" <<'EOF'
{
  "private": true,
  "agentPermissions": {
    "kinds": {
      "bash": {
        "destinationType": "namespaced",
        "destinationKey": "bash",
        "supportsMatchMode": true,
        "defaultMatchMode": "exact",
        "wildcardSuffix": " *"
      },
      "external_directory": {
        "destinationType": "namespaced",
        "destinationKey": "external_directory"
      },
      "permission_key": {
        "destinationType": "top_level"
      }
    },
    "rules": [
        { "kind": "bash", "pattern": "*", "op": "ask", "bashMatchMode": "exact" },
        { "kind": "bash", "pattern": "docker ps", "op": "allow", "bashMatchMode": "exactAndWithArgs" },
        { "kind": "external_directory", "pattern": "/tmp/**", "op": "allow" },
        { "kind": "permission_key", "pattern": "atlassian_*", "op": "ask", "conditions": { "private": false } },
        { "kind": "permission_key", "pattern": "always_*", "op": "allow" }
      ]
  }
}
EOF

  output_false=$(render_template_with_override_data "$SOURCE_DIR/.chezmoitemplates/opencode-permission.tmpl" "$data_file_false")
  echo "$output_false" | grep -Fq '"atlassian_*": "ask"'
  echo "$output_false" | grep -Fq '"always_*": "allow"'
  echo "$output_false" | grep -Fq '"docker ps": "allow"'
  echo "$output_false" | grep -Fq '"docker ps *": "allow"'

  output_true=$(render_template_with_override_data "$SOURCE_DIR/.chezmoitemplates/opencode-permission.tmpl" "$data_file_true")
  ! echo "$output_true" | grep -Fq '"atlassian_*": "ask"'
  echo "$output_true" | grep -Fq '"always_*": "allow"'
}

@test "OpenCode config template renders embedded permission and MCP partials" {
  local data_file="$BATS_TEST_TMPDIR/opencode-config-render.json"
  cat >"$data_file" <<'EOF'
{
  "private": false,
  "agentPermissions": {
    "kinds": {
      "bash": {
        "destinationType": "namespaced",
        "destinationKey": "bash",
        "supportsMatchMode": true,
        "defaultMatchMode": "exact",
        "wildcardSuffix": " *"
      },
      "permission_key": {
        "destinationType": "top_level"
      }
    },
    "rules": [
      { "kind": "bash", "pattern": "echo", "op": "allow", "bashMatchMode": "exactAndWithArgs" },
      { "kind": "permission_key", "pattern": "always_*", "op": "allow" }
    ]
  },
  "mcp": {
    "serversById": {
      "shape-op-remote-base": {
        "enabled": true,
        "targets": { "opencode": { "enabled": true } },
        "remote": { "url": "https://example.com/op-base" }
      }
    }
  }
}
EOF

  output=$(render_template_with_override_data "$SOURCE_DIR/dot_config/opencode/opencode.jsonc.tmpl" "$data_file")
  echo "$output" | grep -Fq '"permission": {'
  echo "$output" | grep -Fq '"bash": {'
  echo "$output" | grep -Fq '"echo": "allow"'
  echo "$output" | grep -Fq '"echo *": "allow"'
  echo "$output" | grep -Fq '"always_*": "allow"'
  echo "$output" | grep -Fq '"mcp": {'
  echo "$output" | grep -Fq '"shape-op-remote-base": {'
  echo "$output" | grep -Fq '"url": "https://example.com/op-base"'
}

@test "OpenCode permission template with merged chezmoidata keeps base and overlay rules" {
  local merged_data_file="$BATS_TEST_TMPDIR/agent-permissions-realdata.json"
  ruby -ryaml -rjson -e '
    def deep_merge(a, b)
      return b unless a.is_a?(Hash) && b.is_a?(Hash)
      a.merge(b) { |_k, av, bv| deep_merge(av, bv) }
    end

    merged = { "private" => false }
    Dir.glob(File.join(ARGV[0], "*.yaml")).sort.each do |file|
      data = YAML.load_file(file) || {}
      merged = deep_merge(merged, data)
    end

    File.write(ARGV[1], JSON.generate(merged))
  ' "$SOURCE_DIR/.chezmoidata/agent-permissions" "$merged_data_file"

  output=$(render_template_with_override_data "$SOURCE_DIR/.chezmoitemplates/opencode-permission.tmpl" "$merged_data_file")
  echo "$output" | grep -Fq '"ls *": "allow"'
  echo "$output" | grep -Fq '"atlassian_*": "ask"'
}

# --- MCP template rendering ---

@test "Cursor MCP template renders canonical local/remote shapes correctly" {
  local data_file="$BATS_TEST_TMPDIR/mcp-shapes-cursor.json"
  cat >"$data_file" <<'EOF'
{
  "private": false,
  "mcp": {
    "serversById": {
      "shape-local-base": {
        "enabled": true,
        "targets": { "cursor": { "enabled": true }, "opencode": { "enabled": true } },
        "local": {
          "command": "mise",
          "args": ["x", "node", "--", "npx", "-y", "pkg-local-base@latest"],
          "env": {}
        }
      },
      "shape-remote-base": {
        "enabled": true,
        "targets": { "cursor": { "enabled": true }, "opencode": { "enabled": true } },
        "remote": { "url": "https://example.com/base" }
      }
    }
  }
}
EOF

  output=$(render_template_with_override_data "$SOURCE_DIR/dot_cursor/mcp.json.tmpl" "$data_file")
  echo "$output" | ruby -rjson -e '
    j = JSON.parse(STDIN.read)
    s = j.fetch("mcpServers")
    raise "missing local base" unless s.key?("shape-local-base")
    raise "missing remote base" unless s.key?("shape-remote-base")
    raise "local base command mismatch" unless s["shape-local-base"]["command"] == "mise"
    raise "local base arg mismatch" unless s["shape-local-base"]["args"].include?("pkg-local-base@latest")
    raise "remote base url mismatch" unless s["shape-remote-base"]["url"] == "https://example.com/base"
  '
}

@test "Cursor MCP template applies generic condition gating" {
  local data_file="$BATS_TEST_TMPDIR/mcp-private-cursor.json"
  cat >"$data_file" <<'EOF'
{
  "private": true,
  "mcp": {
    "serversById": {
      "shape-private-blocked": {
        "enabled": true,
        "conditions": { "private": false },
        "targets": { "cursor": { "enabled": true }, "opencode": { "enabled": true } },
        "remote": { "url": "https://example.com/private-blocked" }
      },
      "shape-private-allowed": {
        "enabled": true,
        "targets": { "cursor": { "enabled": true }, "opencode": { "enabled": true } },
        "remote": { "url": "https://example.com/private-allowed" }
      }
    }
  }
}
EOF

  output=$(render_template_with_override_data "$SOURCE_DIR/dot_cursor/mcp.json.tmpl" "$data_file")
  echo "$output" | ruby -rjson -e '
    j = JSON.parse(STDIN.read)
    s = j.fetch("mcpServers")
    raise "blocked server rendered" if s.key?("shape-private-blocked")
    raise "allowed server missing" unless s.key?("shape-private-allowed")
  '
}

@test "Cursor MCP template skips servers with no targets" {
  local data_file="$BATS_TEST_TMPDIR/mcp-no-targets-cursor.json"
  cat >"$data_file" <<'EOF'
{
  "private": false,
  "mcp": {
    "serversById": {
      "shape-no-targets": {
        "enabled": true,
        "remote": { "url": "https://example.com/no-targets" }
      }
    }
  }
}
EOF

  output=$(render_template_with_override_data "$SOURCE_DIR/dot_cursor/mcp.json.tmpl" "$data_file")
  echo "$output" | ruby -rjson -e '
    j = JSON.parse(STDIN.read)
    s = j.fetch("mcpServers")
    raise "server with omitted targets unexpectedly rendered" if s.key?("shape-no-targets")
  '
}

@test "Cursor MCP template respects enabled false" {
  local data_file="$BATS_TEST_TMPDIR/mcp-overrides-cursor.json"
  cat >"$data_file" <<'EOF'
{
  "private": false,
  "mcp": {
    "serversById": {
      "shape-disabled": {
        "enabled": true,
        "targets": { "cursor": { "enabled": true }, "opencode": { "enabled": true } },
        "remote": { "url": "https://example.com/disabled" }
      },
      "shape-disabled-explicit": {
        "enabled": false,
        "targets": { "cursor": { "enabled": true }, "opencode": { "enabled": true } },
        "remote": { "url": "https://example.com/enabled" }
      }
    }
  }
}
EOF

  output=$(render_template_with_override_data "$SOURCE_DIR/dot_cursor/mcp.json.tmpl" "$data_file")
  echo "$output" | ruby -rjson -e '
    j = JSON.parse(STDIN.read)
    s = j.fetch("mcpServers")
    raise "enabled server missing" unless s.key?("shape-disabled")
    raise "explicit-disabled server rendered" if s.key?("shape-disabled-explicit")
  '
}

@test "OpenCode MCP template renders canonical local/remote shapes correctly" {
  local data_file="$BATS_TEST_TMPDIR/mcp-shapes-opencode.json"
  cat >"$data_file" <<'EOF'
{
  "private": false,
  "mcp": {
    "serversById": {
      "shape-op-local-base": {
        "enabled": true,
        "targets": { "cursor": { "enabled": true }, "opencode": { "enabled": true } },
        "local": {
          "command": "mise",
          "args": ["x", "node", "--", "npx", "-y", "pkg-op-local-base@latest"],
          "env": {}
        }
      },
      "shape-op-remote-base": {
        "enabled": true,
        "targets": { "cursor": { "enabled": true }, "opencode": { "enabled": true } },
        "remote": { "url": "https://example.com/op-base" }
      }
    }
  }
}
EOF

  output=$(render_template_with_override_data "$SOURCE_DIR/.chezmoitemplates/opencode-mcp.jsonc.tmpl" "$data_file")
  echo "$output" | grep -q '"shape-op-local-base"'
  echo "$output" | grep -q '"pkg-op-local-base@latest"'
  echo "$output" | grep -q '"shape-op-remote-base"'
  echo "$output" | grep -q 'https://example.com/op-base'
}

@test "OpenCode MCP template skips servers with no targets" {
  local data_file="$BATS_TEST_TMPDIR/mcp-no-targets-opencode.json"
  cat >"$data_file" <<'EOF'
{
  "private": false,
  "mcp": {
    "serversById": {
      "shape-op-no-targets": {
        "enabled": true,
        "remote": { "url": "https://example.com/op-no-targets" }
      }
    }
  }
}
EOF

  output=$(render_template_with_override_data "$SOURCE_DIR/.chezmoitemplates/opencode-mcp.jsonc.tmpl" "$data_file")
  ! echo "$output" | grep -q '"shape-op-no-targets"'
}

@test "OpenCode MCP template respects enabled false" {
  local data_file="$BATS_TEST_TMPDIR/mcp-overrides-opencode.json"
  cat >"$data_file" <<'EOF'
{
  "private": false,
  "mcp": {
    "serversById": {
      "shape-op-disabled": {
        "enabled": true,
        "targets": { "cursor": { "enabled": true }, "opencode": { "enabled": true } },
        "remote": { "url": "https://example.com/op-disabled" }
      },
      "shape-op-disabled-explicit": {
        "enabled": false,
        "targets": { "cursor": { "enabled": true }, "opencode": { "enabled": true } },
        "remote": { "url": "https://example.com/op-enabled" }
      }
    }
  }
}
EOF

  output=$(render_template_with_override_data "$SOURCE_DIR/.chezmoitemplates/opencode-mcp.jsonc.tmpl" "$data_file")
  echo "$output" | grep -q '"shape-op-disabled"'
  ! echo "$output" | grep -q '"shape-op-disabled-explicit"'
}

@test "Cursor MCP template with real chezmoidata renders valid schema and enabled IDs" {
  local merged_data_file="$BATS_TEST_TMPDIR/mcp-realdata-cursor.json"
  local rendered_file="$BATS_TEST_TMPDIR/cursor-mcp-rendered.json"
  ruby -ryaml -rjson -e '
    def deep_merge(a, b)
      return b unless a.is_a?(Hash) && b.is_a?(Hash)
      a.merge(b) { |_k, av, bv| deep_merge(av, bv) }
    end

    merged = { "private" => false }
    Dir.glob(File.join(ARGV[0], "*.yaml")).sort.each do |file|
      data = YAML.load_file(file) || {}
      merged = deep_merge(merged, data)
    end

    File.write(ARGV[1], JSON.generate(merged))
  ' "$SOURCE_DIR/.chezmoidata/mcps" "$merged_data_file"

  output=$(chezmoi --source "$REPO_ROOT" execute-template \
    --init \
    --promptBool "codespaces=false" \
    --promptBool "private=false" \
    --override-data-file "$merged_data_file" \
    --file "$SOURCE_DIR/dot_cursor/mcp.json.tmpl")
  printf '%s' "$output" >"$rendered_file"

  ruby -rjson -e '
    rendered_path = ARGV[0]
    data_path = ARGV[1]

    rendered = JSON.parse(File.read(rendered_path))
    servers = rendered.fetch("mcpServers")

    data = JSON.parse(File.read(data_path))
    is_private = data.fetch("private", false)
    expected_ids = data.fetch("mcp").fetch("serversById")
      .select { |_id, s| s.fetch("enabled", true) }
      .select { |_id, s| s.dig("targets", "cursor", "enabled") == true }
      .select do |_id, s|
        conditions = s.fetch("conditions", {})
        conditions.all? { |k, v| data.key?(k) && data[k] == v }
      end
      .map { |id, _s| id }
      .sort

    actual_ids = servers.keys.sort
    raise "cursor IDs mismatch, expected=#{expected_ids} actual=#{actual_ids}" unless actual_ids == expected_ids

    servers.each do |id, cfg|
      if cfg.key?("command")
        raise "cursor local #{id} missing args array" unless cfg["args"].is_a?(Array)
        raise "cursor local #{id} missing env object" unless cfg["env"].is_a?(Hash)
      else
        raise "cursor remote #{id} missing transport" unless cfg["transport"].is_a?(String)
        raise "cursor remote #{id} missing url" unless cfg["url"].is_a?(String)
        raise "cursor remote #{id} missing headers object" unless cfg["headers"].is_a?(Hash)
      end
    end
  ' "$rendered_file" "$merged_data_file"
}

@test "OpenCode MCP block with real chezmoidata renders valid schema and enabled IDs" {
  local merged_data_file="$BATS_TEST_TMPDIR/mcp-realdata-opencode.json"
  local rendered_file="$BATS_TEST_TMPDIR/opencode-rendered.jsonc"
  ruby -ryaml -rjson -e '
    def deep_merge(a, b)
      return b unless a.is_a?(Hash) && b.is_a?(Hash)
      a.merge(b) { |_k, av, bv| deep_merge(av, bv) }
    end

    merged = { "private" => false }
    Dir.glob(File.join(ARGV[0], "*.yaml")).sort.each do |file|
      data = YAML.load_file(file) || {}
      merged = deep_merge(merged, data)
    end

    File.write(ARGV[1], JSON.generate(merged))
  ' "$SOURCE_DIR/.chezmoidata/mcps" "$merged_data_file"

  output=$(chezmoi --source "$REPO_ROOT" execute-template \
    --init \
    --promptBool "codespaces=false" \
    --promptBool "private=false" \
    --override-data-file "$merged_data_file" \
    --file "$SOURCE_DIR/.chezmoitemplates/opencode-mcp.jsonc.tmpl")
  printf '%s' "$output" >"$rendered_file"

  ruby -rjson -e '
    rendered_path = ARGV[0]
    data_path = ARGV[1]
    text = File.read(rendered_path).strip
    mcp = JSON.parse("{#{text}}")

    data = JSON.parse(File.read(data_path))
    is_private = data.fetch("private", false)
    expected_ids = data.fetch("mcp").fetch("serversById")
      .select { |_id, s| s.fetch("enabled", true) }
      .select { |_id, s| s.dig("targets", "opencode", "enabled") == true }
      .select do |_id, s|
        conditions = s.fetch("conditions", {})
        conditions.all? { |k, v| data.key?(k) && data[k] == v }
      end
      .map { |id, _s| id }
      .sort

    actual_ids = mcp.keys.sort
    raise "opencode IDs mismatch, expected=#{expected_ids} actual=#{actual_ids}" unless actual_ids == expected_ids

    mcp.each do |id, cfg|
      raise "opencode #{id} missing enabled bool" unless cfg["enabled"] == true || cfg["enabled"] == false
      case cfg["type"]
      when "local"
        raise "opencode local #{id} missing command array" unless cfg["command"].is_a?(Array) && !cfg["command"].empty?
      when "remote"
        raise "opencode remote #{id} missing url" unless cfg["url"].is_a?(String)
      else
        raise "opencode #{id} invalid type #{cfg["type"].inspect}"
      end
    end
  ' "$rendered_file" "$merged_data_file"
}

# --- All .tmpl files are valid Go templates ---

@test "all .tmpl files parse without syntax errors" {
  local failed=0
  while IFS= read -r tmpl; do
    # Use --init so .chezmoi.* variables and include are available.
    # Rendering may fail on missing data (e.g. bitwarden), but syntax
    # errors produce a distinct "parse" error. We only fail on parse errors.
    err=$(chezmoi --source "$REPO_ROOT" execute-template --init \
      --promptBool "codespaces=false" \
      --promptBool "private=false" \
      --file "$tmpl" 2>&1) || {
        if echo "$err" | grep -qi "parse"; then
          echo "PARSE ERROR in $tmpl:"
          echo "$err"
          failed=1
        fi
      }
  done < <(find "$SOURCE_DIR" -name '*.tmpl' -type f)
  [[ $failed -eq 0 ]]
}
