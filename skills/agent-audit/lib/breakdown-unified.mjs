#!/usr/bin/env node
// Render a unified breakdown table (one column per agent) and surface the
// top-5 cross-agent discrepancies. Replaces the per-client categorize.mjs
// calls when --breakdown is passed to audit.sh.
//
// Usage: node lib/breakdown-unified.mjs <outDir> [client ...]
// Clients default to: claude opencode codex pi
//
// Reads the same raw capture files that categorize.mjs uses — no re-capture.

import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

const [, , outDir, ...argClients] = process.argv;
if (!outDir) {
	console.error("usage: breakdown-unified.mjs <outDir> [client ...]");
	process.exit(2);
}

const CLIENTS =
	argClients.length > 0 ? argClients : ["claude", "opencode", "codex", "pi"];

const estTokens = (c) => Math.floor((c + 2) / 4);
const readJSON = (f) => JSON.parse(readFileSync(join(outDir, f), "utf8"));
const readText = (f) => readFileSync(join(outDir, f), "utf8");
const fileExists = (f) => existsSync(join(outDir, f));

// ── shared helpers (mirrors categorize.mjs) ──────────────────────────────────

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

function openaiRequestToolChars(file) {
	if (!fileExists(file)) return 0;
	const req = readJSON(file);
	return Array.isArray(req.tools)
		? req.tools.reduce((a, t) => a + JSON.stringify(t).length, 0)
		: 0;
}

function openaiContentChars(content) {
	if (typeof content === "string") return content.length;
	if (!Array.isArray(content)) return 0;
	return content.reduce((a, c) => a + (c?.text || c?.content || "").length, 0);
}

function openaiRequestUserChars(file) {
	if (!fileExists(file)) return 0;
	const req = readJSON(file);
	let total = 0;
	for (const m of req.input || req.messages || []) {
		if (m.role === "user") total += openaiContentChars(m.content);
	}
	return total;
}

function openaiRequestTextAndToolChars(file) {
	if (!fileExists(file)) return 0;
	const req = readJSON(file);
	let total = (req.instructions || "").length;
	for (const m of req.input || req.messages || [])
		total += openaiContentChars(m.content);
	total += openaiRequestToolChars(file);
	return total;
}

// ── per-client categorize functions (mirrors categorize.mjs) ─────────────────

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
		add(
			(t.name || "").startsWith("mcp__")
				? "MCP tool definitions"
				: "built-in tools",
			n,
		);
	}
	for (const m of j.messages || []) {
		const content = Array.isArray(m.content)
			? m.content
			: [{ text: m.content }];
		for (const c of content) {
			const text = c.text || (typeof c === "string" ? c : "");
			const n = text.length;
			if (
				text.includes("# claudeMd") ||
				text.includes("Codebase and user instructions are shown below")
			) {
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
	return [...buckets]
		.filter(([, n]) => n > 0)
		.map(([cat, chars]) => ({ cat, chars }));
}

function categorizeOpencode() {
	const j = readJSON("opencode-prompt.json");
	const text = (j.system || []).join("\n\n");
	const rows = spanBreakdown(text, [
		["environment (<env>)", "<env>", "</env>"],
		["memory (AGENTS.md)", "Instructions from:", "Skills provide specialized"],
		[
			"skills (<available_skills>)",
			"Skills provide specialized",
			"</available_skills>",
		],
		["context-window protection", "<context_window_protection>", null],
	]);
	// Split mcpproxy_* tools (OpenAI format: name is at t.function.name) from built-in tools.
	if (fileExists("opencode-request.json")) {
		const req = readJSON("opencode-request.json");
		if (Array.isArray(req.tools)) {
			const getName = (t) => t.function?.name || t.name || "";
			const mcpChars = req.tools
				.filter((t) => getName(t).startsWith("mcpproxy"))
				.reduce((a, t) => a + JSON.stringify(t).length, 0);
			const otherChars = req.tools
				.filter((t) => !getName(t).startsWith("mcpproxy"))
				.reduce((a, t) => a + JSON.stringify(t).length, 0);
			if (mcpChars > 0)
				rows.push({ cat: "MCP tools (mcpproxy)", chars: mcpChars });
			if (otherChars > 0)
				rows.push({ cat: "provider tool schemas", chars: otherChars });
		}
	}
	const userChars = openaiRequestUserChars("opencode-request.json");
	if (userChars > 0) rows.push({ cat: "audit user msg", chars: userChars });
	const expected = openaiRequestTextAndToolChars("opencode-request.json");
	const actual = rows.reduce((a, r) => a + r.chars, 0);
	const drift = actual - expected;
	if (expected > 0 && drift !== 0) {
		const base = rows.find((r) => r.cat === "base prompt");
		if (base) base.chars -= drift;
	}
	return rows;
}

function categorizeCodex() {
	let text = "";
	const rows = [];
	if (fileExists("codex-request.json")) {
		const req = readJSON("codex-request.json");
		if (req.instructions)
			rows.push({
				cat: "base instructions (wire)",
				chars: req.instructions.length,
			});
		const dev = (req.input || []).filter((m) => m.role === "developer");
		for (const m of dev) {
			if (Array.isArray(m.content)) {
				for (const c of m.content) text += c.text || "";
			} else if (typeof m.content === "string") {
				text += m.content;
			}
		}
	} else {
		const j = readJSON("codex-prompt-input.json");
		const arr = Array.isArray(j) ? j : j.input || [];
		const out = [];
		for (const m of arr) {
			if (m && m.role === "developer" && Array.isArray(m.content)) {
				for (const c of m.content)
					out.push(c.text || (typeof c === "string" ? c : ""));
			}
		}
		text = out.join("\n\n");
	}
	rows.push(
		...spanBreakdown(text, [
			[
				"permissions instructions",
				"<permissions instructions>",
				"</permissions instructions>",
			],
			[
				"skills (<skills_instructions>)",
				"<skills_instructions>",
				"</skills_instructions>",
			],
		]),
	);
	const toolChars = openaiRequestToolChars("codex-request.json");
	if (toolChars > 0)
		rows.push({ cat: "provider tool schemas", chars: toolChars });
	const userChars = openaiRequestUserChars("codex-request.json");
	if (userChars > 0)
		rows.push({ cat: "audit user/environment msg", chars: userChars });
	return rows;
}

function categorizeHermes() {
	const j = readJSON("hermes-request.json");
	const sys = (j.messages || []).find((m) => m.role === "system");
	const sysText =
		typeof sys?.content === "string"
			? sys.content
			: (sys?.content || []).map((c) => c.text || "").join("");

	// spanBreakdown: base prompt = preamble before <available_skills>;
	// project context injected after </available_skills> when cwd has an AGENTS.md.
	const rows = spanBreakdown(sysText, [
		[
			"skills (<available_skills>)",
			"<available_skills>",
			"</available_skills>",
		],
		["memory (project context)", "# Project Context", null],
	]);

	// Tools are OpenAI-style { type, function: { name, description, parameters } }
	const toolChars = Array.isArray(j.tools)
		? j.tools.reduce((a, t) => a + JSON.stringify(t).length, 0)
		: 0;
	if (toolChars > 0)
		rows.push({ cat: "provider tool schemas", chars: toolChars });

	// User messages (audit prompt)
	const userChars = (j.messages || [])
		.filter((m) => m.role === "user")
		.reduce((a, m) => {
			const t =
				typeof m.content === "string"
					? m.content
					: (m.content || []).map((c) => c.text || "").join("");
			return a + t.length;
		}, 0);
	if (userChars > 0) rows.push({ cat: "audit user msg", chars: userChars });

	return rows;
}

function categorizePi() {
	const text = readText("pi-system.txt");
	const rows = spanBreakdown(text, [
		["memory (project context)", "<project_context>", "</project_context>"],
		["environment", "Current date:", null],
	]);
	const toolChars = openaiRequestToolChars("pi-request.json");
	if (toolChars > 0)
		rows.push({ cat: "provider tool schemas", chars: toolChars });
	const userChars = openaiRequestUserChars("pi-request.json");
	if (userChars > 0) rows.push({ cat: "audit user msg", chars: userChars });
	return rows;
}

// ── canonical category mapping ───────────────────────────────────────────────

// Maps per-client raw category labels → canonical display name.
const TO_CANONICAL = {
	"base prompt (system)": "Base prompt",
	"base prompt": "Base prompt",
	"base instructions (wire)": "Base prompt",
	"built-in tools": "Tool schemas",
	"provider tool schemas": "Tool schemas",
	"MCP tool definitions": "MCP tool definitions",
	"memory (CLAUDE.md chain)": "Memory",
	"memory (AGENTS.md)": "Memory",
	"memory (project context)": "Memory",
	"MCP tools (mcpproxy)": "MCP tool definitions",
	"skills catalogue": "Skills catalogue",
	"skills (<available_skills>)": "Skills catalogue",
	"skills (<skills_instructions>)": "Skills catalogue",

	"environment (<env>)": "Environment",
	environment: "Environment",
	"context-window protection": "Context-window protection",
	"permissions instructions": "Permissions",
	"MCP server instructions": "MCP server instructions",
	"reminders & user msg": "Misc",
	"audit user msg": "Misc",
	"audit user/environment msg": "Misc",
};

// Preferred display order.
const CATEGORY_ORDER = [
	"Base prompt",
	"Tool schemas",
	"MCP tool definitions",
	"Memory",
	"Skills catalogue",
	"Environment",
	"Context-window protection",
	"Permissions",
	"MCP server instructions",
	"Misc",
];

const DISPATCH = {
	claude: categorizeClaude,
	opencode: categorizeOpencode,
	codex: categorizeCodex,
	pi: categorizePi,
	hermes: categorizeHermes,
};

// ── gather data ──────────────────────────────────────────────────────────────

const clientData = new Map(); // client → Map<canonicalCat, chars>
const clientTotals = new Map(); // client → total chars
const activeClients = [];

for (const client of CLIENTS) {
	const fn = DISPATCH[client];
	if (!fn) continue;
	let rows;
	try {
		rows = fn().filter((r) => r.chars > 0);
	} catch {
		continue;
	}
	if (rows.length === 0) continue;
	activeClients.push(client);
	const cats = new Map();
	let total = 0;
	for (const r of rows) {
		const canon = TO_CANONICAL[r.cat] ?? r.cat;
		cats.set(canon, (cats.get(canon) ?? 0) + r.chars);
		total += r.chars;
	}
	clientData.set(client, cats);
	clientTotals.set(client, total);
}

if (activeClients.length === 0) {
	console.error("breakdown-unified: no clients with captured data");
	process.exit(1);
}

// ── determine which categories are present ───────────────────────────────────

const allCats = new Set();
for (const cats of clientData.values()) {
	for (const k of cats.keys()) allCats.add(k);
}

const orderedCats = [
	...CATEGORY_ORDER.filter((c) => allCats.has(c)),
	...[...allCats].filter((c) => !CATEGORY_ORDER.includes(c)).sort(),
];

// ── format helpers ───────────────────────────────────────────────────────────

const fmtNum = (n) => n.toLocaleString("en-US");
const fmtPct = (n, total) =>
	total > 0 ? ((n / total) * 100).toFixed(1) + "%" : "—";

function fmtCell(chars, total) {
	if (chars === 0) return "—";
	return `${fmtNum(chars)} (${fmtPct(chars, total)})`;
}

// ── layout ───────────────────────────────────────────────────────────────────

const CAT_W = 30;
const DATA_W = 19; // "137,795 (62.6%)" = 16 chars; 19 gives comfortable padding

const totalWidth = CAT_W + activeClients.length * (DATA_W + 1);
const rule = "  " + "─".repeat(totalWidth);

// ── print unified table ──────────────────────────────────────────────────────

console.log("\n  Unified breakdown — first-turn request composition (chars)\n");
console.log(rule);
console.log(
	"  " +
		"CATEGORY".padEnd(CAT_W) +
		activeClients.map((c) => c.toUpperCase().padStart(DATA_W)).join(" "),
);
console.log(rule);

for (const cat of orderedCats) {
	const cells = activeClients.map((client) => {
		const chars = clientData.get(client)?.get(cat) ?? 0;
		const total = clientTotals.get(client) ?? 0;
		return fmtCell(chars, total).padStart(DATA_W);
	});
	console.log("  " + cat.padEnd(CAT_W) + cells.join(" "));
}

console.log(rule);

const totalCells = activeClients.map((c) =>
	fmtNum(clientTotals.get(c) ?? 0).padStart(DATA_W),
);
console.log("  " + "TOTAL".padEnd(CAT_W) + totalCells.join(" "));

const tokCells = activeClients.map((c) =>
	estTokens(clientTotals.get(c) ?? 0)
		.toLocaleString("en-US")
		.padStart(DATA_W),
);
console.log("  " + "(~tokens)".padEnd(CAT_W) + tokCells.join(" "));

console.log(rule);

// ── top 5 discrepancies ──────────────────────────────────────────────────────

function discrepancyNote(vals, clients) {
	const present = clients.filter((_, i) => vals[i] > 0);
	const absent = clients.filter((_, i) => vals[i] === 0);
	const maxVal = Math.max(...vals);
	const maxClient = clients[vals.indexOf(maxVal)];

	if (absent.length === clients.length) return "not present for any client";

	if (absent.length > 0) {
		const presentNums = vals.filter((v) => v > 0);
		const minPresent = Math.min(...presentNums);
		const rangeStr =
			presentNums.length > 1
				? ` (range: ${fmtNum(minPresent)}–${fmtNum(maxVal)})`
				: ` (${fmtNum(maxVal)})`;
		return `only ${present.join(", ")}${rangeStr}; ${absent.join(", ")} have none`;
	}

	// All clients have it — show ratio of max to min
	const minVal = Math.min(...vals);
	const minClient = clients[vals.indexOf(minVal)];
	const ratio = (maxVal / minVal).toFixed(1);
	return `${maxClient} is ${ratio}× ${minClient} (${fmtNum(minVal)}–${fmtNum(maxVal)})`;
}

const discrepancies = [];

// Include overall totals as a candidate
{
	const vals = activeClients.map((c) => clientTotals.get(c) ?? 0);
	const spread = Math.max(...vals) - Math.min(...vals);
	discrepancies.push({ cat: "TOTAL first-turn size", vals, spread });
}

for (const cat of orderedCats) {
	const vals = activeClients.map((c) => clientData.get(c)?.get(cat) ?? 0);
	const max = Math.max(...vals);
	if (max === 0) continue;
	discrepancies.push({ cat, vals, spread: max - Math.min(...vals) });
}

discrepancies.sort((a, b) => b.spread - a.spread);
const top5 = discrepancies.slice(0, 5);

console.log("\n  Top 5 cross-agent discrepancies\n");

for (let i = 0; i < top5.length; i++) {
	const { cat, vals, spread } = top5[i];
	const valStr = activeClients
		.map((c, j) => `${c}: ${vals[j] > 0 ? fmtNum(vals[j]) : "—"}`)
		.join("  |  ");
	const note = discrepancyNote(vals, activeClients);
	console.log(`  ${i + 1}. ${cat}  (spread: ${fmtNum(spread)} chars)`);
	console.log(`     ${valStr}`);
	console.log(`     → ${note}`);
	if (i < top5.length - 1) console.log();
}

console.log("\n" + rule);
