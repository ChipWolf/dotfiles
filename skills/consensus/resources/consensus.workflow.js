export const meta = {
  name: 'consensus-decision',
  description: 'Simulate a decision meeting: a panel of specialist agents prep independently, cross-talk in rounds, and a chair synthesizes a stable consensus plus a decision record.',
  phases: [
    { title: 'Frame', detail: 'chair frames the brief and convenes the panel' },
    { title: 'Prep', detail: 'each member forms an independent stance' },
    { title: 'Meeting', detail: 'rounds of cross-talk until convergence' },
    { title: 'Synthesis', detail: 'chair declares the decision' },
  ],
}

// ---------------------------------------------------------------------------
// Reference Workflow script for the `consensus` skill (Claude Code fast-path).
// Run with:
//   Workflow({ scriptPath: "<skill>/resources/consensus.workflow.js",
//              args: { question, options?, contextNotes?, maxRounds? } })
// Schemas mirror the JSON files alongside this script.
// ---------------------------------------------------------------------------

// The host may hand `args` to the script as a JSON-encoded STRING rather than a
// parsed object (observed: a passed object arrives as its JSON.stringify form).
// Normalize both shapes, or every field below silently falls back to its default
// and the whole meeting runs on an empty question.
let _args = {}
if (args && typeof args === 'object') {
  _args = args
} else if (typeof args === 'string' && args.trim()) {
  try { _args = JSON.parse(args) } catch (e) { _args = {} }
}

const question = _args.question || 'No decision question was provided in args.question.'
const seedOptions = _args.options || null                     // optional: string[] of candidate options
const contextNotes = _args.contextNotes || ''                 // optional: extra context from the caller
const MAX_ROUNDS = _args.maxRounds || 4

const MODEL_ENUM = ['opus', 'sonnet', 'haiku']

const BRIEF_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['question', 'options', 'constraints', 'successCriteria', 'contextPack', 'panel', 'chairModel'],
  properties: {
    question: { type: 'string' },
    options: {
      type: 'array', minItems: 2, maxItems: 6,
      items: {
        type: 'object', additionalProperties: false, required: ['name', 'summary'],
        properties: { name: { type: 'string' }, summary: { type: 'string' } },
      },
    },
    constraints: { type: 'array', items: { type: 'string' } },
    successCriteria: { type: 'array', items: { type: 'string' } },
    contextPack: { type: 'string' },
    panel: {
      type: 'array', minItems: 3, maxItems: 8,
      items: {
        // No `name` here on purpose: the chair profiles roles, the SCRIPT assigns
        // neutral human names (decoupled from role/disposition) so peers can't read
        // a member's leanings off their label. `role` and `disposition` are private
        // self-framing; they are never shown to other members.
        type: 'object', additionalProperties: false, required: ['role', 'focus', 'disposition', 'model', 'facilitator'],
        properties: {
          role: { type: 'string' },                                  // realistic role/title, e.g. "platform reliability engineer"
          focus: { type: 'array', minItems: 1, items: { type: 'string' } }, // example things this role tends to weigh (prompts, not orders)
          disposition: { type: 'string' },                           // one line, a believable point on a spectrum, never a caricature
          model: { type: 'string', enum: MODEL_ENUM },
          facilitator: { type: 'boolean' },                          // exactly one true: runs convergence checks + synthesis
        },
      },
    },
    chairModel: { type: 'string', enum: MODEL_ENUM },                 // = the facilitator's model
  },
}

// No fields are `required` on purpose. A required list makes the host reject an
// empty `{}` submission and re-prompt; a model that degenerates into emitting
// `{}` then loops forever against that rejection (no agent-layer retry cap),
// wedging the round barrier. With nothing required, an empty stance validates,
// the agent resolves, and normalizeStance() backfills defaults + flags it as an
// abstention so the meeting proceeds instead of hanging. The prompt
// (STANCE_OUTPUT_RULE) still asks for every field; this is the safety net.
const STANCE_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: [],
  properties: {
    preferredOption: { type: 'string' },                 // a slate option OR one this member proposes
    confidence: { type: 'number', minimum: 0, maximum: 1 },
    reasons: { type: 'array', items: { type: 'string' } },
    concerns: { type: 'array', items: { type: 'string' } },
    objectionsToOthers: { type: 'array', items: { type: 'string' } },
    openQuestions: { type: 'array', items: { type: 'string' } },
    // Options this member puts on the table (new, reframed, or split/merged).
    // The facilitator folds these into the live slate between rounds.
    proposedOptions: {
      type: 'array',
      items: { type: 'object', additionalProperties: false, required: ['name', 'summary'], properties: { name: { type: 'string' }, summary: { type: 'string' } } },
    },
    changedFromLastRound: { type: 'boolean' },
  },
}

const ROUND_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['summary', 'tensions', 'frontRunner', 'converged', 'rationale', 'optionSlate'],
  properties: {
    summary: { type: 'string' },
    tensions: { type: 'array', items: { type: 'string' } },
    frontRunner: { type: 'string' },
    converged: { type: 'boolean' },
    rationale: { type: 'string' },
    // The curated live option set after folding in this round's proposals
    // (new options added, duplicates merged, dead ones dropped). Carried into
    // the next round so the slate is what the room actually shaped, not the
    // fixed menu it started with.
    optionSlate: {
      type: 'array', minItems: 1,
      items: { type: 'object', additionalProperties: false, required: ['name', 'summary'], properties: { name: { type: 'string' }, summary: { type: 'string' } } },
    },
  },
}

const DECISION_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['decision', 'rationale', 'rejectedOptions', 'dissent', 'risks', 'confidence', 'provisional', 'followUps'],
  properties: {
    decision: { type: 'string' },
    rationale: { type: 'string' },
    rejectedOptions: {
      type: 'array',
      items: { type: 'object', additionalProperties: false, required: ['name', 'why'], properties: { name: { type: 'string' }, why: { type: 'string' } } },
    },
    dissent: { type: 'array', items: { type: 'string' } },
    risks: {
      type: 'array',
      items: { type: 'object', additionalProperties: false, required: ['risk', 'mitigation'], properties: { risk: { type: 'string' }, mitigation: { type: 'string' } } },
    },
    confidence: { type: 'number', minimum: 0, maximum: 1 },
    provisional: { type: 'boolean' },
    followUps: { type: 'array', items: { type: 'string' } },
  },
}

// --- prompt builders ---------------------------------------------------------

// Stance agents must terminate with exactly one fully-populated StructuredOutput
// call. Without this, a model that writes a long prose preamble sometimes calls
// the tool with an empty `{}`, fails schema validation, and re-submits empty
// indefinitely (no retry cap exists at the agent layer), wedging the round.
const STANCE_OUTPUT_RULE = [
  'OUTPUT CONTRACT: keep any private reasoning short, then finish by calling StructuredOutput EXACTLY ONCE.',
  'Populate it with real values — never call it with an empty object {}.',
  'Always set: preferredOption (an option name), confidence (0..1), reasons (at least one), changedFromLastRound (boolean). Add concerns / objectionsToOthers / proposedOptions where you have them.',
  'If you have already written your reasoning as prose, do not stop there: you have not responded until the StructuredOutput call carries the populated fields.',
].join(' ')

function briefPrompt() {
  return [
    'You are the Chair of a decision panel. Frame the decision before anyone is convened.',
    `Decision (THIS is the decision the panel must resolve; do not substitute another):\n${question}`,
    seedOptions ? `Caller-suggested options: ${seedOptions.join(', ')}` : 'Derive the candidate options from the question and the repo context.',
    contextNotes ? `Caller notes: ${contextNotes}` : '',
    'Read the repo for grounding: CONTEXT.md, docs/adr/, AGENTS.md, and the code/configs this decision touches. If an internal-docs / repo / ticketing MCP is connected, query it (via ToolSearch) for prior decisions and constraints. Never invent facts, options, or prior decisions.',
    'The brief\'s `question` field MUST restate the caller\'s decision above. You may sharpen its wording, but you MUST NOT change its subject or scope, and you MUST NOT replace it with a different question you find more interesting in the repo. Every option must be a way of resolving THAT decision; if the caller supplied options, yours must cover them (refine or add, never swap the topic).',
    'Produce a decision brief: the question, 2-6 concrete options, hard constraints, success criteria, and a condensed context pack that every member will share.',
    'Then convene a panel sized to the decision (3-8 members). Model each member as a REAL person in a REAL role this decision would actually pull into a room: a job/function (e.g. "platform reliability engineer", "security engineer", "developer-experience lead", "person who owns the cost line", "the maintainer who is on call"). Do NOT use abstract debate-roles like "pragmatist", "optimist", or "devil\'s advocate" — those are caricatures, not people.',
    'For each member set: `role` (the realistic title), `focus` (2-4 concrete things someone in that role tends to weigh — these are EXAMPLES to orient them, not orders to argue a side), and `disposition` (one line placing them at a believable point on a spectrum: risk appetite, change vs. stability, detail vs. big-picture). Make every disposition distinct and human; NO caricatures, NO "extreme" anyone — real colleagues are all just somewhere on the scale. Do NOT assign anyone the job of opposing or cheerleading; let their role and disposition produce genuine views. Do not give members names; the meeting assigns those.',
    'Exactly ONE member has `facilitator: true` — the person who will run the room and write up the decision. They hold real views too; facilitator is a duty, not a neutral chairhood.',
    'Assign each member a model, and mind the mix: DEFAULT members to sonnet; reserve opus for the facilitator and at most one genuinely pivotal role; use haiku for lighter-weight perspectives. An all-opus panel is the wrong call twice over — it wastes the flagship model AND collapses the very diversity of priors the panel exists to create. Set chairModel to the facilitator\'s model.',
  ].filter(Boolean).join('\n\n')
}

function prepPrompt(member, brief) {
  return [
    `You are ${member.name}. You are in the room as a ${member.role}.`,
    `What people in your position tend to weigh (examples to orient you, not a side you must argue): ${member.focus.join('; ')}.`,
    `Your disposition: ${member.disposition}. This is who you are, not a script — hold the views you would genuinely hold.`,
    'This framing (your role, focus, and disposition) is PRIVATE. The others will never see it, nor your private reasoning — only the stance you choose to put on the table. Likewise you will only ever see what they choose to share.',
    `Decision: ${brief.question}`,
    `Options on the table so far (a STARTING slate, not a closed ballot — you may back one, but you may also propose a new option, reframe one, or argue two should be split or merged):\n${brief.options.map(o => `- ${o.name}: ${o.summary}`).join('\n')}`,
    `Constraints: ${brief.constraints.join('; ') || 'none stated'}`,
    `Success criteria: ${brief.successCriteria.join('; ') || 'none stated'}`,
    `Shared context:\n${brief.contextPack}`,
    'First, think privately: mull this over in your own terms, surface your strong views and your real uncertainties, and whether the option slate is even framed right. You may use tools (via ToolSearch) to ground yourself, but cite only what you can verify — never invent facts.',
    'Then emit your stance. This is your independent prior: do not assume what others think. If you would put a new or reframed option on the table, include it in proposedOptions and you may set preferredOption to it. Set changedFromLastRound to false.',
    STANCE_OUTPUT_RULE,
  ].join('\n\n')
}

// Only what a member chose to put on the table: their name, preference, reasons,
// concerns, objections, and any option they proposed. Never their role,
// disposition, or private reasoning — peers should not be able to read leanings
// off a label.
function transcriptOf(stances) {
  return stances.map(s => {
    const proposed = (s.proposedOptions || []).map(o => `${o.name}: ${o.summary}`).join(' | ')
    return [
      `### ${s.member}`,
      `- prefers: ${s.preferredOption} (confidence ${s.confidence})`,
      `- reasons: ${(s.reasons || []).join('; ')}`,
      `- concerns: ${(s.concerns || []).join('; ') || 'none'}`,
      `- objections to others: ${(s.objectionsToOthers || []).join('; ') || 'none'}`,
      proposed ? `- options they put forward: ${proposed}` : null,
    ].filter(Boolean).join('\n')
  }).join('\n\n')
}

function slateOf(options) {
  return options.map(o => `- ${o.name}: ${o.summary}`).join('\n')
}

function crosstalkPrompt(member, brief, transcript, round, chairSummary, slate) {
  return [
    `Round ${round} of the decision meeting. You are ${member.name}.`,
    `What you tend to weigh (private, examples only): ${member.focus.join('; ')}. Your disposition (private): ${member.disposition}.`,
    `Decision: ${brief.question}`,
    `Options on the table now (this slate evolves as the room talks; you may back one, propose a new one, or argue to merge/split/reframe):\n${slate}`,
    chairSummary ? `Facilitator's read of the room so far:\n${chairSummary}` : '',
    `What each person has put on the table (only what they chose to share):\n${transcript}`,
    'React like a real participant: concede where others are right, push back where they are wrong, and say plainly if you have changed your mind. Pressure-test the front-runner wherever YOUR perspective genuinely sees a weakness — that scrutiny is everyone\'s job here, not one assigned skeptic\'s. Stay grounded in the context and tool results; do not invent.',
    'Emit your updated stance. If you are proposing or reshaping an option, put it in proposedOptions. Set changedFromLastRound to true if your preferred option or a material reason changed this round.',
    STANCE_OUTPUT_RULE,
  ].filter(Boolean).join('\n\n')
}

function chairCheckPrompt(brief, prev, curr, round, slate) {
  return [
    `You are the facilitator. Round ${round} just finished.`,
    `Decision: ${brief.question}`,
    `Option slate going into this round:\n${slate}`,
    `Previous round (only what each chose to share):\n${transcriptOf(prev)}`,
    `This round (only what each chose to share):\n${transcriptOf(curr)}`,
    'First, curate the live slate into optionSlate: fold in options members put forward this round, merge duplicates and near-duplicates, reword for clarity, and drop options nobody backs any more. This is the set the room has actually shaped — it may differ from the menu it started with. Keep at least one option.',
    'Then judge convergence strictly: converged = true ONLY if NO member changed their preferred option THIS round AND no new substantive objection appeared AND the slate itself is stable (no new option still drawing support). A round in which members moved onto the front-runner, or a freshly proposed option is still gathering backers, is progress, NOT convergence — it needs a following quiet round to confirm. A momentary majority is NOT convergence.',
    'Summarize where the room stands (refer to people by name), list the live tensions, name the front-runner, and explain your convergence judgement (name who is still moving or the new objection if not converged).',
  ].join('\n\n')
}

function synthPrompt(brief, stances, chairSummary, provisional, slate) {
  return [
    'You are the facilitator. Synthesize the final decision.',
    `Decision: ${brief.question}`,
    `Final option slate (as the room shaped it, which may differ from the opening menu):\n${slate}`,
    `Final stances (only what each chose to share):\n${transcriptOf(stances)}`,
    chairSummary ? `Your latest read of the room:\n${chairSummary}` : '',
    provisional ? 'The meeting hit the round cap WITHOUT convergence: mark the decision provisional and record the unresolved tensions.' : '',
    'Declare the decision: chosen option (any option on the final slate, including one that emerged in discussion), rationale grounded in the panel\'s reasoning, each rejected option and why, dissent / minority report (mandatory if anyone ended below moderate confidence or kept an unaddressed objection), risks with mitigations, overall confidence, and follow-ups.',
  ].filter(Boolean).join('\n\n')
}

// --- orchestration -----------------------------------------------------------

// Backfill a possibly-empty stance (see STANCE_SCHEMA) so downstream code never
// reads undefined, and flag abstentions (a member whose agent emitted no real
// preferredOption) rather than silently treating an empty stance as a position.
function normalizeStance(s, m) {
  const abstained = !s || !s.preferredOption
  return {
    member: m.name,
    role: m.role,
    abstained,
    preferredOption: (s && s.preferredOption) || '(abstained: no stance emitted)',
    confidence: (s && typeof s.confidence === 'number') ? s.confidence : 0,
    reasons: (s && s.reasons) || [],
    concerns: (s && s.concerns) || [],
    objectionsToOthers: (s && s.objectionsToOthers) || [],
    openQuestions: (s && s.openQuestions) || [],
    proposedOptions: (s && s.proposedOptions) || [],
    changedFromLastRound: !!(s && s.changedFromLastRound),
  }
}

// Neutral first names assigned by the SCRIPT (not the chair) so a member's label
// carries no signal about their role or leanings. A cheap deterministic hash of
// the question rotates the pool start, so different decisions get different
// names without Math.random (which the runtime forbids for resumability).
const NAME_POOL = [
  'Avery', 'Bao', 'Chidi', 'Dasha', 'Eitan', 'Farah', 'Goran', 'Hana',
  'Ilya', 'Jun', 'Kira', 'Liam', 'Mara', 'Nadia', 'Omar', 'Priya',
  'Quinn', 'Rafa', 'Sasha', 'Tariq', 'Uma', 'Vihaan', 'Wren', 'Yusuf',
]
function nameOffset(s) {
  let h = 0
  for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) % NAME_POOL.length
  return h
}

function logAbstentions(label, stances) {
  const out = stances.filter(s => s.abstained).map(s => s.member)
  if (out.length) log(`${label}: ${out.length} member(s) emitted no stance, recorded as abstaining: ${out.join(', ')}`)
}

phase('Frame')
const brief = await agent(briefPrompt(), { label: 'chair:frame', phase: 'Frame', schema: BRIEF_SCHEMA, model: 'opus' })

// Assign neutral names here, decoupled from the role profiles the chair wrote.
const _off = nameOffset(brief.question || question)
const members = brief.panel.map((m, i) => ({ ...m, name: NAME_POOL[(_off + i) % NAME_POOL.length] }))
const facilitator = members.find(m => m.facilitator) || members[0]
log(`Panel: ${members.map(m => `${m.name} (${m.role}, ${m.model}${m.facilitator ? ', facilitator' : ''})`).join('; ')}`)

// The slate starts as the chair's opening menu and is re-curated each round.
let slate = brief.options

phase('Prep')
let stances = (await parallel(members.map(m => () =>
  agent(prepPrompt(m, brief), { label: `prep:${m.name}`, phase: 'Prep', schema: STANCE_SCHEMA, model: m.model })
    .then(s => normalizeStance(s, m))
))).filter(Boolean)
logAbstentions('Prep', stances)

phase('Meeting')
let round = 0
let converged = false
let chairSummary = ''
while (!converged && round < MAX_ROUNDS) {
  round++
  const prev = stances
  const transcript = transcriptOf(prev)
  const slateText = slateOf(slate)
  const updated = (await parallel(members.map(m => () =>
    agent(crosstalkPrompt(m, brief, transcript, round, chairSummary, slateText), { label: `round${round}:${m.name}`, phase: 'Meeting', schema: STANCE_SCHEMA, model: m.model })
      .then(s => normalizeStance(s, m))
  ))).filter(Boolean)
  logAbstentions(`Round ${round}`, updated)

  const check = await agent(chairCheckPrompt(brief, prev, updated, round, slateText), { label: `chair:round${round}`, phase: 'Meeting', schema: ROUND_SCHEMA, model: brief.chairModel })
  chairSummary = check.summary
  stances = updated
  if (check.optionSlate && check.optionSlate.length) slate = check.optionSlate

  // Groupthink guard: never accept round-1 unanimity without one more adversarial pass.
  converged = check.converged && round > 1
  log(`Round ${round}: front-runner "${check.frontRunner}", converged=${converged}${round === 1 && check.converged ? ' (round-1 agreement — forcing one adversarial round)' : ''}`)
}

phase('Synthesis')
const provisional = !converged
const decision = await agent(synthPrompt(brief, stances, chairSummary, provisional, slateOf(slate)), { label: 'chair:synthesis', phase: 'Synthesis', schema: DECISION_SCHEMA, model: facilitator.model })

return { brief, panel: members.map(m => ({ name: m.name, role: m.role, model: m.model, facilitator: !!m.facilitator })), finalSlate: slate, finalStances: stances, rounds: round, converged, decision }
