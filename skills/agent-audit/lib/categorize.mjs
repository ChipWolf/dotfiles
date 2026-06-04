#!/usr/bin/env node
// Break a captured prompt down into named categories (base, tools, MCP,
// memory/AGENTS.md, skills, …) and print a per-category table — the same kind
// of "where do the bytes go" view Cursor and Claude Desktop show in their UIs.
//
// Usage: node lib/categorize.mjs <client> <outDir>
//
// Reads the raw capture that audit.sh already wrote into <outDir>:
//   claude    claude-request.json     (full first-turn request body)
//   opencode  opencode-prompt.json    (assembled system pieces)
//   codex     codex-prompt-input.json (locally-built developer message)
//   pi        pi-system.txt           (rendered system prompt)
//
// Note on scope: for claude the breakdown covers the WHOLE first-turn request
// (system + tools + memory + skills), not just the system payload that the
// summary table measures. Tool definitions and the skills catalogue live off
// the system prompt, so this is the only place their weight is surfaced.

import { readFileSync } from "node:fs";
import { join } from "node:path";

const [, , client, outDir] = process.argv;
if (!client || !outDir) {
  console.error("usage: categorize.mjs <client> <outDir>");
  process.exit(2);
}

const estTokens = (c) => Math.floor((c + 2) / 4);
const readJSON = (f) => JSON.parse(readFileSync(join(outDir, f), "utf8"));
const readText = (f) => readFileSync(join(outDir, f), "utf8");

// Slice a text into named spans by anchor substrings, attributing everything
// not covered by a named span to a "base prompt" remainder. Anchors are
// [label, startNeedle, endNeedle]; endNeedle is included in the span. A needle
// that isn't found drops that span silently.
function spanBreakdown(text, anchors, baseLabel = "base prompt") {
  const spans = [];
  for (const [label, startNeedle, endNeedle] of anchors) {
    const start = text.indexOf(startNeedle);
    if (start === -1) continue;
    let end;
    if (endNeedle === null) {
      end = text.length;
    } else {
      const e = text.indexOf(endNeedle, start);
      if (e === -1) continue;
      end = e + endNeedle.length;
    }
    spans.push({ label, start, end });
  }
  spans.sort((a, b) => a.start - b.start);
  const rows = [];
  let covered = 0;
  for (const s of spans) {
    rows.push({ cat: s.label, chars: s.end - s.start });
    covered += s.end - s.start;
  }
  rows.unshift({ cat: baseLabel, chars: text.length - covered });
  return rows;
}

function categorizeClaude() {
  const j = readJSON("claude-request.json");
  const buckets = new Map([
    ["base prompt (system)", 0],
    ["built-in tools", 0],
    ["MCP tool definitions", 0],
    ["memory (CLAUDE.md chain)", 0],
    ["skills catalogue", 0],
    ["MCP server instructions", 0],
    ["reminders & user msg", 0],
  ]);
  const add = (k, n) => buckets.set(k, buckets.get(k) + n);

  for (const b of j.system || []) {
    add("base prompt (system)", (b.text || "").length);
  }
  for (const t of j.tools || []) {
    const n = JSON.stringify(t).length;
    add((t.name || "").startsWith("mcp__") ? "MCP tool definitions" : "built-in tools", n);
  }
  for (const m of j.messages || []) {
    const content = Array.isArray(m.content) ? m.content : [{ text: m.content }];
    for (const c of content) {
      const text = c.text || (typeof c === "string" ? c : "");
      const n = text.length;
      if (text.includes("# claudeMd") || text.includes("Codebase and user instructions are shown below")) {
        add("memory (CLAUDE.md chain)", n);
      } else if (text.startsWith("The following skills are available")) {
        add("skills catalogue", n);
      } else if (text.includes("# MCP Server Instructions")) {
        add("MCP server instructions", n);
      } else {
        add("reminders & user msg", n);
      }
    }
  }
  return [...buckets].filter(([, n]) => n > 0).map(([cat, chars]) => ({ cat, chars }));
}

function categorizeOpencode() {
  const j = readJSON("opencode-prompt.json");
  const text = (j.system || []).join("\n\n");
  return spanBreakdown(text, [
    ["environment (<env>)", "<env>", "</env>"],
    ["memory (AGENTS.md)", "Instructions from:", "Skills provide specialized"],
    ["skills (<available_skills>)", "Skills provide specialized", "</available_skills>"],
    ["context-window protection", "<context_window_protection>", null],
  ]);
}

function categorizeCodex() {
  const j = readJSON("codex-prompt-input.json");
  const arr = Array.isArray(j) ? j : j.input || [];
  const out = [];
  for (const m of arr) {
    if (m && m.role === "developer" && Array.isArray(m.content)) {
      for (const c of m.content) out.push(c.text || (typeof c === "string" ? c : ""));
    }
  }
  const text = out.join("\n\n");
  return spanBreakdown(text, [
    ["permissions instructions", "<permissions instructions>", "</permissions instructions>"],
    ["skills (<skills_instructions>)", "<skills_instructions>", "</skills_instructions>"],
  ]);
}

function categorizePi() {
  const text = readText("pi-system.txt");
  return spanBreakdown(text, [
    ["tools list", "Available tools:", "Guidelines:"],
    ["guidelines & pi docs", "Guidelines:", "Current date:"],
    ["environment", "Current date:", null],
  ]);
}

const dispatch = {
  claude: categorizeClaude,
  opencode: categorizeOpencode,
  codex: categorizeCodex,
  pi: categorizePi,
};

const fn = dispatch[client];
if (!fn) {
  // cursor and any unknown client have no breakdown source.
  process.exit(1);
}

let rows;
try {
  rows = fn();
} catch (e) {
  console.error(`categorize ${client}: ${e.message}`);
  process.exit(1);
}

const total = rows.reduce((a, r) => a + r.chars, 0);
if (total === 0) process.exit(1);

const heading =
  client === "claude"
    ? "claude — first-turn request composition"
    : `${client} — system prompt composition`;
const labelW = Math.max(24, ...rows.map((r) => r.cat.length));
const rule = "  " + "─".repeat(labelW + 26);

console.log(`\n  ${heading}`);
console.log(rule);
console.log(`  ${"CATEGORY".padEnd(labelW)} ${"CHARS".padStart(9)} ${"~TOKENS".padStart(9)} ${"%".padStart(6)}`);
console.log(rule);
for (const r of rows) {
  const pct = ((r.chars / total) * 100).toFixed(1) + "%";
  console.log(`  ${r.cat.padEnd(labelW)} ${String(r.chars).padStart(9)} ${String(estTokens(r.chars)).padStart(9)} ${pct.padStart(6)}`);
}
console.log(rule);
console.log(`  ${"TOTAL".padEnd(labelW)} ${String(total).padStart(9)} ${String(estTokens(total)).padStart(9)} ${"100%".padStart(6)}`);
