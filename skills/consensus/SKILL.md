---
name: consensus
description: Reach a stable, well-reasoned decision by simulating a real decision meeting — convene a panel of specialist subagents, have each prepare independently, run rounds of cross-talk, then a chair synthesizes consensus and records an ADR. Use when the user must choose between options (e.g. "AWS vs GCP", architecture/tooling/business calls), wants a decision made by many perspectives, asks to "reach consensus", "convene a panel", "decide X", or wants a defensible decision record with rationale and dissent.
---

# Consensus

Mirror a real-world decision meeting in agent-world. Many independent minds beat one prior:
diverse specialists prepare alone, argue in rounds, and a chair declares a *stable* consensus
(positions unchanged across a full round), recorded as an ADR with dissent kept visible.

## When to use

Any non-trivial decision between options where one model's single answer would be noisy or
biased: infra/tooling choices, architecture forks, vendor selection, business calls. Skip it
for trivial or already-decided questions — it is deliberately expensive (panel × rounds).

## Quick start

1. **Frame** the decision (Phase 0): read repo context — `CONTEXT.md`, `docs/adr/`, `AGENTS.md`,
   relevant code — and query any internal-docs MCP. Produce a **Decision Brief**: question,
   candidate options, constraints, success criteria, condensed context pack, and a **panel
   roster**. See [REFERENCE.md](REFERENCE.md) for the brief shape.
2. **Convene** the panel: model **real people in real roles** this decision would pull into a room
   (a security engineer, the on-call maintainer, whoever owns the cost line, a product lead, an
   SRE…), NOT abstract debate-roles like "pragmatist" or "devil's advocate". Give each a realistic
   role, a few example focus areas (to orient, not to script a side), a distinct human disposition
   somewhere on a normal spectrum (no caricatures, no "extreme" anyone), a context subset, and a
   model (see model guidance below). One member is the **facilitator** (runs the room, writes up
   the decision) and still holds real views. The meeting assigns **neutral names** decoupled from
   role, so no one can read a colleague's leanings off their label.
3. **Prep round (Phase 1, isolated):** each member mulls privately and emits a **Stance**
   (preferred option, confidence, grounded reasons, blocking concerns, and any option they want to
   **put on the table**). Members do NOT see each other yet — independent priors are the point. A
   member's role, disposition, and private reasoning stay private; peers only ever see what each
   one *chooses to share*.
4. **Meeting rounds (Phase 2, loop):** the facilitator shares the table (each person's shared
   stance + the live option slate + tensions); each member reacts, may propose/reframe/merge
   options, and updates its stance (cross-talk). Pressure-testing the front-runner is **everyone's
   job**, not one assigned skeptic's. The facilitator re-curates the option slate, writes a round
   summary, and runs a convergence check. Repeat until **converged** or `maxRounds` (default 4).
5. **Synthesis (Phase 3):** chair declares the decision: choice, rationale, rejected options +
   why, **dissent / minority report**, risks + mitigations, confidence, follow-ups.
6. **Record (Phase 4):** write an ADR from [resources/adr-template.md](resources/adr-template.md)
   into `docs/adr/` using the next free sequence number — list the directory first, don't assume
   the next number — then return the summary.

## Convergence = stability, not just agreement

Declare consensus only when **a full round passes with no member changing their preferred option
AND no new substantive objection appearing**. Mere majority is not enough — it flip-flops. Always
report confidence and dissent so a *thin* consensus is visible, not hidden.

**Tie-break — movement toward the winner is progress, not convergence.** A round in which members
shift *onto* the front-runner is the meeting working, but it is not yet stable: it must be
followed by a quiet round (zero option changes, no new objection) to confirm. Never declare
convergence on the same round that options moved.

**Groupthink guard:** force one extra adversarial round before accepting consensus whenever
agreement looks too easy — round-1 unanimity, near-unanimity, or unanimity at low confidence. The
scrutiny is shared: every member is asked to pressure-test the front-runner where their own
perspective sees a weakness, the facilitator holds the room there for one more pass, and the slate
must be stable too (no freshly proposed option still gathering backers).

## Model guidance (soft, not rigid)

Diversify models across the panel so priors don't collapse into one model's biases — and watch the
mix in both directions. **Default members to a mid-tier model** (e.g. sonnet); use a light model
(haiku) for lighter perspectives; reserve the flagship (opus) for at most one *non-facilitator*
deliberation voice where deep reasoning genuinely pays. An **all-flagship panel is wrong three ways
over**: it burns the most expensive model, collapses the diversity of priors that is the whole
point of a panel, AND — observed in practice — is the *least reliable* at the forced structured
output every member must emit.

**Keep the facilitator off the flagship.** The facilitator runs every convergence check and the
synthesis, all under strict schemas. In testing, the `opus` tier resolved to a long-context build
that intermittently emitted **empty tool-call arguments** (it knew the values but failed to attach
them), which would hang those strict calls. `agent()` exposes only coarse tiers, so you cannot pin
a non-long-context opus from the script; the practical guard is to keep the facilitator (and any
strict-schema role) on sonnet. This is guidance, not a tier table — a thorny call may deserve a
top-tier deliberation voice; just don't make *everyone*, or the facilitator, top-tier by default.

## How to run it (portable + fast-path)

- **Default — prose procedure:** drive the phases above using whatever subagent primitive the
  host agent provides (Claude Code `Agent`/`Task`; pi's pi-subagent skill; opencode/cursor/codex
  Task). With no subagent primitive, the orchestrator role-plays each persona in separate framed
  passes. **Enforce independent priors:** write each member's Phase-1 stance in its own pass and
  commit it before reading or writing the next; do not summarize the others first. Anchor each
  pass hard to its charter so stances diverge. Real subagents are strongly preferred — single-agent
  role-play cannot *prove* the priors were independent, so flag it as a validity caveat.
- **Fast-path — Workflow (Claude Code):** when the `Workflow` tool is available, run the bundled
  reference script for deterministic fan-out, looped rounds, and schema-validated stances:
  `Workflow({ scriptPath: "<this skill>/resources/consensus.workflow.js",
  args: { question, options, contextNotes, maxRounds } })`. Invoking it from this skill satisfies
  the Workflow opt-in.

## Guardrails

- **No fabricated context.** Members ground every claim in the context pack, repo, or MCP results
  — never invent facts, schemas, or prior decisions. (See global `AGENTS.md`.)
- **Always surface dissent.** A buried minority report is a failed meeting.
- **Scale to the decision.** Match panel size and round count to how much the decision is worth.

## Resources

- [REFERENCE.md](REFERENCE.md) — full protocol, persona catalog, prompts, schemas, failure modes.
- [resources/consensus.workflow.js](resources/consensus.workflow.js) — Workflow reference script.
- [resources/stance.schema.json](resources/stance.schema.json),
  [resources/decision-brief.schema.json](resources/decision-brief.schema.json),
  [resources/round.schema.json](resources/round.schema.json),
  [resources/decision.schema.json](resources/decision.schema.json) — structured-output schemas.
- [resources/adr-template.md](resources/adr-template.md) — decision-record template.

## Self-improvement loop

After running a consensus, note any protocol improvements (better convergence test, persona
gaps, prompt fixes) by updating this skill at `skills/consensus/` in the chezmoi repo.
