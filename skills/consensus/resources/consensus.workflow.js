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

const question = (args && args.question) || 'No decision question was provided in args.question.'
const seedOptions = (args && args.options) || null            // optional: string[] of candidate options
const contextNotes = (args && args.contextNotes) || ''        // optional: extra context from the caller
const MAX_ROUNDS = (args && args.maxRounds) || 4

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
        type: 'object', additionalProperties: false, required: ['name', 'role', 'charter', 'model'],
        properties: {
          name: { type: 'string' },
          role: { type: 'string', enum: ['chair', 'pragmatist', 'devils-advocate', 'scribe', 'specialist'] },
          charter: { type: 'string' },
          model: { type: 'string', enum: MODEL_ENUM },
        },
      },
    },
    chairModel: { type: 'string', enum: MODEL_ENUM },
  },
}

const STANCE_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['preferredOption', 'confidence', 'reasons', 'concerns', 'changedFromLastRound'],
  properties: {
    preferredOption: { type: 'string' },
    confidence: { type: 'number', minimum: 0, maximum: 1 },
    reasons: { type: 'array', minItems: 1, items: { type: 'string' } },
    concerns: { type: 'array', items: { type: 'string' } },
    objectionsToOthers: { type: 'array', items: { type: 'string' } },
    openQuestions: { type: 'array', items: { type: 'string' } },
    changedFromLastRound: { type: 'boolean' },
  },
}

const ROUND_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['summary', 'tensions', 'frontRunner', 'converged', 'rationale'],
  properties: {
    summary: { type: 'string' },
    tensions: { type: 'array', items: { type: 'string' } },
    frontRunner: { type: 'string' },
    converged: { type: 'boolean' },
    rationale: { type: 'string' },
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

function briefPrompt() {
  return [
    'You are the Chair of a decision panel. Frame the decision before anyone is convened.',
    `Decision: ${question}`,
    seedOptions ? `Caller-suggested options: ${seedOptions.join(', ')}` : 'Derive the candidate options from the question and the repo context.',
    contextNotes ? `Caller notes: ${contextNotes}` : '',
    'Read the repo for grounding: CONTEXT.md, docs/adr/, AGENTS.md, and the code/configs this decision touches. If an internal-docs / repo / ticketing MCP is connected, query it (via ToolSearch) for prior decisions and constraints. Never invent facts, options, or prior decisions.',
    'Produce a decision brief: the question, 2-6 concrete options, hard constraints, success criteria, and a condensed context pack that every member will share.',
    'Then convene a panel sized to the decision (3-8 members): the core (chair, pragmatist, devils-advocate, scribe) plus the specialists THIS decision actually needs (e.g. cost, reliability/SRE, security, product, future-planning, blue-sky, non-technical). Give each a sharp persona charter (what they optimize for and the bias they bring).',
    'Assign each member a model. Diversify deliberately so priors do not collapse into one model\'s bias; give heavier reasoning to the chair and pivotal specialists, lighter to routine roles. Set chairModel to the strongest you assign.',
  ].filter(Boolean).join('\n\n')
}

function prepPrompt(member, brief) {
  return [
    `You are ${member.name}, the ${member.role} on a decision panel.`,
    `Your charter: ${member.charter}`,
    `Decision: ${brief.question}`,
    `Options:\n${brief.options.map(o => `- ${o.name}: ${o.summary}`).join('\n')}`,
    `Constraints: ${brief.constraints.join('; ') || 'none stated'}`,
    `Success criteria: ${brief.successCriteria.join('; ') || 'none stated'}`,
    `Shared context:\n${brief.contextPack}`,
    'First, think privately: mull this over in your own terms, surface what you would bring to the room, your strong views and your real uncertainties. You may use tools (via ToolSearch) to ground yourself, but cite only what you can verify — never invent facts.',
    'Then emit your stance. This is your independent prior: do not assume what others think. Set changedFromLastRound to false.',
  ].join('\n\n')
}

function transcriptOf(stances) {
  return stances.map(s =>
    `### ${s.member}\n- prefers: ${s.preferredOption} (confidence ${s.confidence})\n- reasons: ${(s.reasons || []).join('; ')}\n- concerns: ${(s.concerns || []).join('; ') || 'none'}\n- objections to others: ${(s.objectionsToOthers || []).join('; ') || 'none'}`
  ).join('\n\n')
}

function crosstalkPrompt(member, brief, transcript, round, chairSummary) {
  return [
    `Round ${round} of the decision meeting. You are ${member.name}, the ${member.role}.`,
    `Your charter: ${member.charter}`,
    `Decision: ${brief.question}`,
    chairSummary ? `Chair's summary of the room so far:\n${chairSummary}` : '',
    `The room right now:\n${transcript}`,
    'React: concede where others are right, push back where they are wrong, and say plainly if you have changed your mind. The devil\'s advocate should hammer the front-runner. Stay grounded in the context and tool results; do not invent.',
    'Emit your updated stance. Set changedFromLastRound to true if your preferred option or a material reason changed this round.',
  ].filter(Boolean).join('\n\n')
}

function chairCheckPrompt(brief, prev, curr, round) {
  return [
    `You are the Chair. Round ${round} just finished.`,
    `Decision: ${brief.question}`,
    `Previous round stances:\n${transcriptOf(prev)}`,
    `This round stances:\n${transcriptOf(curr)}`,
    'Judge convergence strictly: converged = true ONLY if no member changed their preferred option this round AND no new substantive objection appeared. A momentary majority is NOT convergence.',
    'Summarize where the room stands, list the live tensions, name the front-runner, and explain your convergence judgement (name who is still moving or the new objection if not converged).',
  ].join('\n\n')
}

function synthPrompt(brief, stances, chairSummary, provisional) {
  return [
    'You are the Chair. Synthesize the final decision.',
    `Decision: ${brief.question}`,
    `Options:\n${brief.options.map(o => `- ${o.name}: ${o.summary}`).join('\n')}`,
    `Final stances:\n${transcriptOf(stances)}`,
    chairSummary ? `Your latest room summary:\n${chairSummary}` : '',
    provisional ? 'The meeting hit the round cap WITHOUT convergence: mark the decision provisional and record the unresolved tensions.' : '',
    'Declare the decision: chosen option, rationale grounded in the panel\'s reasoning, each rejected option and why, dissent / minority report (mandatory if anyone ended below moderate confidence or kept an unaddressed objection), risks with mitigations, overall confidence, and follow-ups.',
  ].filter(Boolean).join('\n\n')
}

// --- orchestration -----------------------------------------------------------

phase('Frame')
const brief = await agent(briefPrompt(), { label: 'chair:frame', phase: 'Frame', schema: BRIEF_SCHEMA, model: 'opus' })

// The scribe is the chair/script itself; everyone else actively deliberates.
const members = brief.panel.filter(m => m.role !== 'scribe')

phase('Prep')
let stances = (await parallel(members.map(m => () =>
  agent(prepPrompt(m, brief), { label: `prep:${m.name}`, phase: 'Prep', schema: STANCE_SCHEMA, model: m.model })
    .then(s => ({ ...s, member: m.name, role: m.role }))
))).filter(Boolean)

phase('Meeting')
let round = 0
let converged = false
let chairSummary = ''
while (!converged && round < MAX_ROUNDS) {
  round++
  const prev = stances
  const transcript = transcriptOf(prev)
  const updated = (await parallel(members.map(m => () =>
    agent(crosstalkPrompt(m, brief, transcript, round, chairSummary), { label: `round${round}:${m.name}`, phase: 'Meeting', schema: STANCE_SCHEMA, model: m.model })
      .then(s => ({ ...s, member: m.name, role: m.role }))
  ))).filter(Boolean)

  const check = await agent(chairCheckPrompt(brief, prev, updated, round), { label: `chair:round${round}`, phase: 'Meeting', schema: ROUND_SCHEMA, model: brief.chairModel })
  chairSummary = check.summary
  stances = updated

  // Groupthink guard: never accept round-1 unanimity without one more adversarial pass.
  converged = check.converged && round > 1
  log(`Round ${round}: front-runner "${check.frontRunner}", converged=${converged}${round === 1 && check.converged ? ' (round-1 agreement — forcing one adversarial round)' : ''}`)
}

phase('Synthesis')
const provisional = !converged
const decision = await agent(synthPrompt(brief, stances, chairSummary, provisional), { label: 'chair:synthesis', phase: 'Synthesis', schema: DECISION_SCHEMA, model: brief.chairModel })

return { brief, finalStances: stances, rounds: round, converged, decision }
