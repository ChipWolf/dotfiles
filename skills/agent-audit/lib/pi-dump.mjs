#!/usr/bin/env node
// Render pi's system prompt for the current cwd without making an API call.
// Imports pi's compiled internals from its mise install directory.
//
// Usage: node lib/pi-dump.mjs > prompt.txt
//
// PI_INSTALL_DIR can override autodetection if multiple versions are installed.

import { readdirSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";
import { pathToFileURL } from "node:url";

function piInstallDir() {
  if (process.env.PI_INSTALL_DIR) return process.env.PI_INSTALL_DIR;
  const base = join(
    homedir(),
    ".local/share/mise/installs/npm-earendil-works-pi-coding-agent",
  );
  const versions = readdirSync(base).filter((n) => !n.startsWith("."));
  if (versions.length === 0) {
    throw new Error(`no pi install under ${base}`);
  }
  // Pick the highest semver-ish entry lexicographically.
  versions.sort();
  return join(
    base,
    versions[versions.length - 1],
    "lib/node_modules/@earendil-works/pi-coding-agent",
  );
}

const root = piInstallDir();
const url = (p) => pathToFileURL(join(root, p)).href;

const { buildSystemPrompt } = await import(url("dist/core/system-prompt.js"));
const { loadProjectContextFiles } = await import(
  url("dist/core/resource-loader.js")
);
const { loadSkills } = await import(url("dist/core/skills.js"));
const { getAgentDir } = await import(url("dist/config.js"));

const cwd = process.cwd();
const agentDir = getAgentDir();

// Default selected tools from `pi --help`.
const selectedTools = ["read", "bash", "edit", "write"];
const toolSnippets = {
  read: "Read file contents",
  bash: "Execute bash commands (ls, grep, find, etc.)",
  edit:
    "Make precise file edits with exact text replacement, including multiple disjoint edits in one call",
  write: "Create or overwrite files",
};

const contextFiles = loadProjectContextFiles({ cwd, agentDir });
const skillsResult = loadSkills({
  cwd,
  agentDir,
  skillPaths: [],
  includeDefaults: true,
});

const prompt = buildSystemPrompt({
  cwd,
  selectedTools,
  toolSnippets,
  contextFiles,
  skills: skillsResult.skills,
});

process.stdout.write(prompt);
