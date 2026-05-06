#!/usr/bin/env bats
# brewfile.bats — Brewfile structure and guard validation

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  BREWFILE_TMPL="$REPO_ROOT/home/Brewfile.tmpl"
  BOOTSTRAP_TMPL="$REPO_ROOT/home/.chezmoiscripts/run_onchange_after_bootstrap.sh.tmpl"
  BREWFILE_RENDERED="$BATS_TEST_TMPDIR/Brewfile.rendered"
}

render_brewfile_template() {
  env CI= chezmoi --source "$REPO_ROOT" execute-template \
    --file "$BREWFILE_TMPL"
}

render_brewfile_to_tmp() {
  run render_brewfile_template
  [ "$status" -eq 0 ]
  printf "%s\n" "$output" >"$BREWFILE_RENDERED"
}

render_bootstrap_template_ci() {
  env CI=1 HOMEBREW_CI=1 chezmoi --source "$REPO_ROOT/home" execute-template --init \
    --override-data '{"codespaces":false}' \
    --file "$BOOTSTRAP_TMPL"
}

@test "Brewfile template renders valid Ruby syntax" {
  render_brewfile_to_tmp
  ruby -c "$BREWFILE_RENDERED"
}

@test "Brewfile render uses HOMEBREW_ env prefix for data conditions" {
  render_brewfile_to_tmp
  echo "$output" | grep -q 'ENV\["HOMEBREW_CODESPACES"\]'
  echo "$output" | grep -q 'ENV\["HOMEBREW_PRIVATE"\]'
  ! echo "$output" | grep -q 'ENV\["CODESPACES"\]'
  ! echo "$output" | grep -q 'ENV\["PRIVATE"\]'
}

@test "all active cask entries have 'if OS.mac?' guard" {
  render_brewfile_to_tmp
  local failed=0
  while IFS= read -r line; do
    if ! echo "$line" | grep -Eq 'if .*\bOS\.mac\?'; then
      echo "Missing OS.mac? guard: $line"
      failed=1
    fi
  done < <(grep -E '^cask ' "$BREWFILE_RENDERED")
  [[ $failed -eq 0 ]]
}

@test "tmux brew entry includes macOS guard" {
  render_brewfile_to_tmp
  line=$(grep -E '^brew "tmux"' "$BREWFILE_RENDERED")
  echo "$line" | grep -Fq 'OS.mac?'
}

@test "Brewfile render preserves mixed condition expression formatting" {
  render_brewfile_to_tmp
  echo "$output" | grep -Fq 'brew "cbonsai" if (ENV["HOMEBREW_PRIVATE"]) && !(ENV["HOMEBREW_CODESPACES"])'
  echo "$output" | grep -Fq 'brew "tmux" if (OS.mac?) && !(ENV["HOMEBREW_CODESPACES"] || ENV["HOMEBREW_WSL_DISTRO_NAME"])'
}

@test "bootstrap template CI fallback still embeds neovim brew entry" {
  if [ "${OS:-}" = "Windows_NT" ]; then
    skip "unix bootstrap script is empty on Windows hosts"
  fi
  run render_bootstrap_template_ci
  [ "$status" -eq 0 ]
  echo "$output" | grep -Fq "cat >\"\$BREWFILE_RENDERED\" <<'EOF'"
  echo "$output" | grep -Fq 'Rendered Brewfile is missing neovim entry.'
}

@test "bootstrap template supports pre-rendered Brewfile override" {
  if [ "${OS:-}" = "Windows_NT" ]; then
    skip "unix bootstrap script is empty on Windows hosts"
  fi
  run render_bootstrap_template_ci
  [ "$status" -eq 0 ]
  echo "$output" | grep -Fq 'for candidate in "${DOTFILES_BREWFILE_RENDERED:-}"; do'
  echo "$output" | grep -Fq 'cp "$candidate" "$BREWFILE_RENDERED"'
}
