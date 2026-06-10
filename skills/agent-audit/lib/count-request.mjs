#!/usr/bin/env node
// Count prompt-overhead-ish text and schema bytes from captured provider requests.
// This intentionally excludes response-only fields and tiny transport metadata,
// but includes tool/function schemas because they consume first-turn context.

import { readFileSync } from "node:fs";

const [, , kind, file] = process.argv;
if (!kind || !file) {
  console.error("usage: count-request.mjs <claude|openai> <file>");
  process.exit(2);
}

const j = JSON.parse(readFileSync(file, "utf8"));

function textLen(value) {
  if (value == null) return 0;
  if (typeof value === "string") return value.length;
  if (Array.isArray(value)) return value.reduce((a, v) => a + textLen(v), 0);
  if (typeof value === "object") {
    if (typeof value.text === "string") return value.text.length;
    if (typeof value.content === "string") return value.content.length;
    if (Array.isArray(value.content)) return textLen(value.content);
    return 0;
  }
  return 0;
}

function claude() {
  let total = 0;
  for (const b of j.system || []) total += textLen(b);
  for (const t of j.tools || []) total += JSON.stringify(t).length;
  for (const m of j.messages || []) total += textLen(m.content);
  return total;
}

function openai() {
  let total = 0;

  // Responses API: { instructions?, input: [...], tools: [...] }
  total += textLen(j.instructions);
  total += textLen(j.input);

  // Chat Completions API: { messages: [...], tools: [...] }
  if (Array.isArray(j.messages)) {
    for (const m of j.messages) total += textLen(m.content);
  }

  // OpenAI-compatible tools can be either Responses tools or chat function tools.
  if (Array.isArray(j.tools)) {
    for (const t of j.tools) total += JSON.stringify(t).length;
  }

  return total;
}

const dispatch = { claude, openai };
const fn = dispatch[kind];
if (!fn) {
  console.error(`unknown kind: ${kind}`);
  process.exit(2);
}

process.stdout.write(String(fn()));
