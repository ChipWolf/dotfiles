# Consensus — reference

Full protocol behind [SKILL.md](SKILL.md). Read this when running a real decision, extending the
persona catalog, or adapting the Workflow script.

## Domain language

| Term | Meaning |
|---|---|
| **Decision brief** | The framed question + options + constraints + success criteria + context pack + panel roster. Output of Phase 0. Schema: [resources/decision-brief.schema.json](resources/decision-brief.schema.json). |
| **Panel** | The members convened for this decision. |
| **Core member** | Always present: Chair, Pragmatist, Devil's Advocate, Scribe. |
| **Specialist** | A domain voice added for *this* decision (cost, SRE, security, product, future-planning, blue-sky, non-technical, legal/compliance, DX…). |
| **Persona charter** | A member's mandate: what they optimize for and what bias they deliberately bring. |
| **Context pack** | The condensed shared context every member receives (repo facts, prior ADRs, MCP findings). |
| **Inner monologue / prep note** | A member's private pre-round thinking. Not shared verbatim; it distills into a stance. |
| **Stance** | A member's current position: preferred option, confidence (0–1), grounded reasons, blocking concerns. Schema: [resources/stance.schema.json](resources/stance.schema.json). |
| **Round** | One meeting pass: members react to the shared transcript and update stances. |
| **Cross-talk** | Members reading and responding to each other's prior-round stances. |
| **Convergence** | Chair's judgement that stances are *stable*: no preferred option changed and no new substantive objection appeared across one full round. Schema: [resources/round.schema.json](resources/round.schema.json). |
| **Decision record** | The ADR written at the end. Template: [resources/adr-template.md](resources/adr-template.md). Schema: [resources/decision.schema.json](resources/decision.schema.json). |

## Why this produces a *stable* answer

A single agent asked once gives a noisy, prior-dependent answer. Three levers convert that into a
stable consensus:

1. **Independent priors.** Phase 1 members never see each other. Diversity of independent draws is
   the statistical signal — the wisdom-of-crowds effect, not one model's first guess.
2. **Stability as the stop condition.** Convergence requires positions *unchanged across a full
   round*, not a momentary majority. A meeting that would flip next round has not converged.
3. **Dissent stays visible.** Confidence and minority report are first-class outputs, so a thin or
   coerced consensus is legible rather than laundered into false certainty.

## Phase-by-phase

### Phase 0 — Frame (Chair)
Gather context before convening anyone. Read `CONTEXT.md`, `docs/adr/`, `AGENTS.md`, and the code
or configs the decision touches. If an internal-docs / repo / ticketing MCP is connected, query
it for prior decisions and constraints. Then emit the **decision brief**:
- Crisp question and 2–5 concrete candidate options (each with a one-line summary).
- Hard constraints and success criteria.
- A **context pack**: the condensed, citable facts all members share.
- A **panel roster** sized to the decision (3–7 members typical): core + the specialists this
  question actually needs. For each: name, role, persona charter, and a model.

Do not invent options or constraints. If the brief is underspecified, ask the user before
convening — a panel built on a wrong frame produces confident nonsense.

### Phase 1 — Prep (parallel, isolated)
Spawn every member at once, each blind to the others. Each writes an inner monologue (mull,
argue with self, surface what they'd bring) then emits a **stance**. Keep them isolated — if they
see each other here, you lose the independent priors that make the result robust.

### Phase 2 — Meeting rounds (loop)
Each round:
1. Chair compiles a **transcript**: every member's current stance plus the live tensions and open
   questions.
2. Every member reads the transcript and responds — concede, push back, refine — then emits an
   updated stance. (Reacting to the prior round's transcript is the cross-talk channel; for
   stricter turn-taking, run members sequentially within the round and append each reply to the
   transcript before the next member.)
3. The **Devil's Advocate** explicitly stress-tests the current front-runner: strongest argument
   against, failure modes, what would have to be true for it to be wrong.
4. Chair writes a round summary and a **convergence check** (see schema).
5. Carry a short private reflection forward between rounds ("thinking between meetings").

Stop when converged or at `maxRounds` (default 4). On hitting the cap without convergence, the
chair still synthesizes but records the decision as **provisional** with the unresolved tensions.

**Convergence tie-break.** Convergence = a round with *zero* preferred-option changes and no new
substantive objection. A round in which members move *onto* the front-runner is progress, not
convergence — require a following quiet round to confirm stability. Do not let "everyone agrees
now" on a moving round end the meeting; the next round must show the agreement holds.

**Groupthink guard:** agreement that comes too easily is suspect — round-1 unanimity, near-
unanimity, or unanimity at low confidence all earn one more adversarial round (Devil's Advocate
leads) before acceptance. The Devil's Advocate stress-tests the front-runner every round anyway.

### Phase 3 — Synthesis (Chair)
Chair declares: decision, rationale, each rejected option and why, **dissent / minority report**,
risks with mitigations, overall confidence, and follow-ups. Dissent is mandatory if any member
ended below moderate confidence or kept an unaddressed objection.

### Phase 4 — Record
Write an ADR from [resources/adr-template.md](resources/adr-template.md) into `docs/adr/` using
the next sequence number, following the repo's existing ADR style. Return the summary to the user.
If the repo has no `docs/adr/`, return the summary and offer to create the directory rather than
writing silently.

## Persona catalog (starting set — extend per decision)

| Role | Optimizes for | Deliberate bias |
|---|---|---|
| **Chair** (core) | Reaching a stable, defensible decision | Neutral facilitator; forces convergence test, owns synthesis |
| **Pragmatist** (core) | Shipping, reversibility, time-to-value | "What's the boring choice that works Monday?" |
| **Devil's Advocate** (core) | Finding the strongest counter-case | Refute the front-runner; default to skepticism |
| **Scribe** (core) | Faithful record, traceability | Captures tensions and dissent verbatim (often the orchestrator/script itself) |
| **Cost hawk** | TCO, opex, lock-in, egress | Long-run bill over launch convenience |
| **Reliability / SRE** | Operability, failure modes, on-call load | Steady-state pain over greenfield appeal |
| **Security / compliance** | Attack surface, data residency, audit | Assume breach; least privilege |
| **Product** | User/business outcome, roadmap fit | Outcome over technical elegance |
| **Future-planning** | 2–3 year horizon, scaling, migration cost | Optionality and exit ramps |
| **Blue-sky** | Non-obvious alternatives | Challenge the framing itself |
| **Non-technical / exec** | Strategy, org fit, narrative | Plain-language "so what?" |

## Prompt sketches

**Member prep (Phase 1):**
> You are *{name}*, the {role} on a decision panel. Your charter: {charter}. The decision:
> {question}. Options: {options}. Shared context: {contextPack}. First, think privately — mull it
> over in your own terms, surface what you would bring to the room, your strong views and your
> uncertainties. Ground every claim in the context, the repo, or tool results; never invent facts.
> Then emit your stance.

**Member cross-talk (Phase 2):**
> Round {n}. Here is the room so far: {transcript}. React as *{name}* ({charter}). Concede where
> others are right, push back where they are wrong, and say plainly if you have changed your mind.
> Update your stance.

**Chair convergence check:**
> Compare last round's stances to this round's. Has any member changed their preferred option? Has
> any new substantive objection appeared? Converged = true only if both answers are no. Summarize
> the room, the live tensions, and the front-runner.

## Failure modes

- **False/early consensus** — agents agree because they're the same model with the same prior. Fix
  with model diversity, sharper charters, and the groupthink guard.
- **Endless oscillation** — positions cycle without settling. The `maxRounds` cap + provisional
  decision prevents an infinite meeting; widen the option set or sharpen the brief next time.
- **Hallucinated grounding** — a member cites a fact or prior decision that isn't in the context
  pack. The chair should challenge unsourced claims and exclude them from the rationale.
- **Cost blowout** — `members × rounds` agent calls add up. Scale the panel to the decision; use
  lighter models for routine roles; lower `maxRounds` for low-stakes calls.
- **Args delivered as a JSON string:** the host can hand the script's `args` global to the
  Workflow as a JSON-encoded string rather than a parsed object (observed: a passed object arrives
  as its `JSON.stringify` form). `args.question` is then `undefined`, so the meeting silently runs
  on the empty-question default and the chair frames whatever it infers from the repo. The script
  now normalizes `args` (parses it when it is a string) before reading any field. If a run ignores
  your inputs, this is the first thing to check.
- **Substituted question:** even with a real question, the Frame chair can wander onto a more
  interesting repo topic. `briefPrompt()` pins the brief's `question` to the caller's decision;
  verify the returned `brief.question` still matches what you asked before trusting the result.
- **Empty StructuredOutput loop:** a stance agent writes a long prose preamble, then calls
  `StructuredOutput` with `{}`. When the stance schema marks fields `required`, the host rejects
  the empty call and re-prompts, and a degenerate model re-submits empty forever (no agent-layer
  retry cap), wedging the round barrier. Observed live across multiple agents (one looped 145×).
  A prompt nudge (`STANCE_OUTPUT_RULE`) was NOT enough to stop it. The real fix is structural:
  `STANCE_SCHEMA` declares nothing `required`, so an empty stance validates and the agent
  resolves; `normalizeStance()` backfills defaults and flags the member as abstaining (logged via
  `logAbstentions`), so one degenerate agent costs a single abstention instead of hanging the
  meeting. If you re-tighten the schema, you reintroduce the hang.

## Adapting the Workflow script

[resources/consensus.workflow.js](resources/consensus.workflow.js) is the Claude Code fast-path.
It runs Phase 1 as one `parallel()` fan-out, loops Phase 2 with a `parallel()` per round plus a
chair check, then synthesizes. Each agent uses the model the chair assigned in the brief. To
change panel size, rounds, or model spread, edit the brief schema constraints or the loop — the
script reads everything from the `args` and the chair's brief, so no hard-coded roster.
