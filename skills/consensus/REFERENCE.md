# Consensus — reference

Full protocol behind [SKILL.md](SKILL.md). Read this when running a real decision, extending the
persona catalog, or adapting the Workflow script.

## Domain language

| Term | Meaning |
|---|---|
| **Decision brief** | The framed question + options + constraints + success criteria + context pack + panel roster. Output of Phase 0. Schema: [resources/decision-brief.schema.json](resources/decision-brief.schema.json). |
| **Panel** | The members convened for this decision. Each is a real role with a human disposition, not a debate-archetype. |
| **Member** | One participant: a realistic role (security engineer, on-call maintainer, cost owner…), a few example focus areas, a distinct disposition on a normal spectrum, and a model. Exactly one is the facilitator. |
| **Facilitator** | The member who runs the room and writes up the decision. Holds real views too; not a neutral chair. |
| **Role / focus / disposition** | A member's *private* self-framing: their job, the things people in that job tend to weigh (examples, not orders), and where they sit on a spectrum. Never shown to other members. |
| **Neutral name** | A human first name the *script* assigns, decoupled from role, so peers can't read leanings off a label. |
| **Context pack** | The condensed shared context every member receives (repo facts, prior ADRs, MCP findings). |
| **Inner monologue / prep note** | A member's private pre-round thinking. Never shared; it distills into a stance. |
| **Stance** | What a member chooses to put on the table: preferred option, confidence (0–1), grounded reasons, blocking concerns, objections, and any option they propose. Schema: [resources/stance.schema.json](resources/stance.schema.json). |
| **Option slate** | The live set of options. It starts as the brief's opening menu and is re-curated each round as members propose, reframe, merge, and drop options — it is what the room shaped, not a fixed ballot. |
| **Round** | One meeting pass: members react to the shared transcript and update stances. |
| **Cross-talk** | Members reading and responding to *what each other chose to share* (never each other's private framing or reasoning). |
| **Convergence** | The facilitator's judgement that things are *stable*: no preferred option changed, no new substantive objection, and the slate itself settled, across one full round. Schema: [resources/round.schema.json](resources/round.schema.json). |
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
- Crisp question and 2–5 concrete **opening** options (each with a one-line summary). These seed
  the slate; the panel can add, reframe, split, or merge options as it talks.
- Hard constraints and success criteria.
- A **context pack**: the condensed, citable facts all members share.
- A **panel** sized to the decision (3–7 members typical): real roles this question actually pulls
  in. For each: the realistic `role`, a few `focus` examples, a distinct `disposition`, a `model`,
  and one `facilitator: true`. Do NOT assign debate-archetypes ("pragmatist", "devil's advocate")
  and do NOT name members — the script assigns neutral names.

Do not invent options or constraints. If the brief is underspecified, ask the user before
convening — a panel built on a wrong frame produces confident nonsense.

### Phase 1 — Prep (parallel, isolated)
Spawn every member at once, each blind to the others. Each thinks privately (mull, argue with
self, decide whether the slate is even framed right) then emits a **stance** — which may include
new or reframed options. Keep them isolated — if they see each other here, you lose the
independent priors that make the result robust. Their role, disposition, and reasoning stay
private; only the stance they choose to share ever reaches the room.

### Phase 2 — Meeting rounds (loop)
Each round:
1. The facilitator compiles a **transcript** (each member's *shared* stance), the **live option
   slate**, and the open tensions.
2. Every member reads the transcript and responds — concede, push back, refine, propose or reframe
   an option — then emits an updated stance. (Reacting to the prior round's transcript is the
   cross-talk channel; for stricter turn-taking, run members sequentially within the round and
   append each reply to the transcript before the next member.)
3. Pressure-testing the front-runner is **everyone's** job: each member is asked to attack it
   wherever their own perspective genuinely sees a weakness, rather than delegating skepticism to
   one assigned contrarian.
4. The facilitator **re-curates the option slate** (fold in proposals, merge duplicates, drop dead
   options), then writes a round summary and a **convergence check** (see schema).
5. Carry a short private reflection forward between rounds ("thinking between meetings").

Stop when converged or at `maxRounds` (default 4). On hitting the cap without convergence, the
chair still synthesizes but records the decision as **provisional** with the unresolved tensions.

**Convergence tie-break.** Convergence = a round with *zero* preferred-option changes, no new
substantive objection, and a stable slate (no freshly proposed option still gathering backers). A
round in which members move *onto* the front-runner, or a new option is still drawing support, is
progress, not convergence — require a following quiet round to confirm stability. Do not let
"everyone agrees now" on a moving round end the meeting; the next round must show the agreement
holds.

**Groupthink guard:** agreement that comes too easily is suspect — round-1 unanimity, near-
unanimity, or unanimity at low confidence all earn one more round of scrutiny before acceptance.
The scrutiny is shared (every member pressure-tests the front-runner from their own angle) and the
facilitator holds the room there for the extra pass rather than rubber-stamping the easy agreement.

### Phase 3 — Synthesis (facilitator)
The facilitator declares: decision (any option on the *final* slate, including one that emerged in
discussion), rationale, each rejected option and why, **dissent / minority report**, risks with
mitigations, overall confidence, and follow-ups. Dissent is mandatory if any member ended below
moderate confidence or kept an unaddressed objection.

### Phase 4 — Record
Write an ADR from [resources/adr-template.md](resources/adr-template.md) into `docs/adr/` using
the next sequence number, following the repo's existing ADR style. Return the summary to the user.
If the repo has no `docs/adr/`, return the summary and offer to create the directory rather than
writing silently.

## Building the panel (real roles, not archetypes)

Convene the people this decision would actually pull into a room. Pick **roles**, give each a few
**focus** examples and a distinct **disposition**, and let genuine views emerge — do not assign
anyone the job of opposing or cheerleading. The roles below are a prompt for *which functions* to
consider, not labels to stamp on members:

| Function to consider | Tends to weigh (focus examples) |
|---|---|
| Reliability / SRE / on-call maintainer | Operability, failure modes, steady-state on-call load |
| Security / compliance | Attack surface, key custody, blast radius, data residency, audit |
| Cost owner | TCO, opex, lock-in, egress, the long-run bill |
| Product / business | User and business outcome, roadmap fit |
| Developer experience | Day-to-day ergonomics, onboarding, cognitive load |
| Future-planning | 2–3 year horizon, scaling, migration and exit cost |
| Domain expert | Whatever specialist knowledge *this* decision turns on |
| Skeptical generalist | Whether the framing itself is right; non-obvious alternatives |

Each member also needs a **disposition** — a believable point on a spectrum (risk appetite, change
vs. stability, detail vs. big-picture). Make them distinct and human; no two identical, none
"extreme". One member is the **facilitator**. The script assigns neutral names; you do not.

## Prompt sketches

**Member prep (Phase 1):**
> You are *{name}*. You're in the room as a {role}. Things someone in your position tends to weigh
> (examples, not a side to argue): {focus}. Your disposition: {disposition}. This framing is
> private — others see only what you put on the table. The decision: {question}. Options so far (a
> starting slate, not a closed ballot — you may back one, propose a new one, or argue to
> merge/split): {options}. Shared context: {contextPack}. Think privately, ground every claim in
> the context or tool results, then emit your stance (including any option you'd put forward).

**Member cross-talk (Phase 2):**
> Round {n}. The current slate: {slate}. What each person chose to share: {transcript}. React as a
> real participant: concede where others are right, push back where they are wrong, propose or
> reframe an option if you'd table one, and pressure-test the front-runner wherever YOUR
> perspective sees a weakness. Say plainly if you've changed your mind. Update your stance.

**Facilitator convergence check:**
> Curate the live slate (fold in this round's proposals, merge duplicates, drop dead options).
> Then: has any member changed their preferred option? Any new substantive objection? Any freshly
> proposed option still gathering backers? Converged = true only if all three answers are no.
> Summarize the room (by name), the live tensions, and the front-runner.

## Failure modes

- **False/early consensus** — agents agree because they're the same model with the same prior. Fix
  with model diversity (not an all-flagship panel), distinct role/disposition profiles, and the
  groupthink guard.
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
- **The empty-args culprit is the long-context flagship.** The empty-`{}` submissions correlate
  cleanly with the `opus` tier resolving to a long-context (`[1m]`) build: across runs the opus
  agents emitted empty tool args (one 145×, and a facilitator abstained every round) while sonnet
  and haiku agents populated their stance first try, every time. The model knew the values — one
  opus agent wrote "I am clearly failing to attach the arguments" then spelled them out in prose —
  it just failed to attach them to the call. `agent()` exposes only coarse tiers (`opus`/`sonnet`/
  `haiku`), so the script cannot request a non-long-context opus; the model guidance therefore
  keeps the facilitator and any strict-schema role on sonnet and reserves opus for at most one
  non-facilitator deliberation voice (where an empty stance degrades to a logged abstention rather
  than a hang). `ROUND_SCHEMA` and `DECISION_SCHEMA` are deliberately left strict, so this
  facilitator-model choice is what keeps the convergence check and synthesis from hanging.

## Adapting the Workflow script

[resources/consensus.workflow.js](resources/consensus.workflow.js) is the Claude Code fast-path.
It normalizes `args` (which the host may deliver as a JSON string), runs Phase 1 as one
`parallel()` fan-out, loops Phase 2 with a `parallel()` per round plus a facilitator check that
re-curates the option slate, then synthesizes from the final slate. The script assigns neutral
member names (decoupled from role); each agent uses the model the chair profiled. To change panel
size, rounds, or model spread, edit the brief schema constraints or the loop — the script reads
everything from `args` and the chair's brief, so no hard-coded roster. The stance schema marks
nothing `required` on purpose (see the empty-StructuredOutput failure mode); do not re-tighten it.
