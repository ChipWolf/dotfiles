#!/usr/bin/env node
// Build a pi first-turn OpenAI-style request locally: system prompt + first user
// message + active tool definitions. This avoids a real provider call while
// counting the same major buckets pi would send on turn one.

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
  if (versions.length === 0) throw new Error(`no pi install under ${base}`);
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
const { loadProjectContextFiles } = await import(url("dist/core/resource-loader.js"));
const { loadSkills } = await import(url("dist/core/skills.js"));
const { getAgentDir } = await import(url("dist/config.js"));
const { createCodingToolDefinitions } = await import(url("dist/core/tools/index.js"));

const cwd = process.cwd();
const agentDir = getAgentDir();
const selectedTools = ["read", "bash", "edit", "write"];
const toolSnippets = {
  read: "Read file contents",
  bash: "Execute bash commands (ls, grep, find, etc.)",
  edit:
    "Make precise file edits with exact text replacement, including multiple disjoint edits in one call",
  write: "Create or overwrite files",
};

const contextFiles = loadProjectContextFiles({ cwd, agentDir });
const skillsResult = loadSkills({ cwd, agentDir, skillPaths: [], includeDefaults: true });
const system = buildSystemPrompt({
  cwd,
  selectedTools,
  toolSnippets,
  contextFiles,
  skills: skillsResult.skills,
});

const tools = createCodingToolDefinitions(cwd).map((tool) => ({
  type: "function",
  name: tool.name,
  description: tool.description,
  parameters: tool.parameters,
}));

process.stdout.write(
  JSON.stringify(
    {
      model: "audit-model",
      input: [
        { role: "developer", content: [{ type: "input_text", text: system }] },
        { role: "user", content: [{ type: "input_text", text: "hi" }] },
      ],
      tools,
      stream: true,
      store: false,
    },
    null,
    2,
  ),
);
