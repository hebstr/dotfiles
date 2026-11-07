# Anti-sycophancy: robust methods of agentic engineering

Sourced recommendation (via `/workflow:reco`, 2026-07-04).
Opening question: reducing or even removing agent sycophancy beyond the bare system instructions "be direct/impartial".

## Core thesis

Sycophancy is an artefact of the RLHF reward, not of the prompt.
A "be direct" instruction treats a symptom: it is the weakest lever.
Robustness comes from structural constraints that make agreement costly or impossible (isolated contexts, cross-model judges, neutral framing, forced disagreement).

## The structural levers (decreasing leverage, available to a Claude Code user)

### 0. Anchoring on executable truth (the strongest, verifiable tasks)

Sycophancy cannot express itself on a decision that does not ask for the model's opinion.
On a verifiable task, replacing "is this code good?" with "do the tests pass, is the lint clean, does the invariant hold?" takes the lever away from the bias instead of debiasing it.
This lever is of another order than the four that follow: they correct a judgement, this one removes it.
Scope: verifiable outputs (code, computation, structured extraction).
On open-ended generation with no oracle it does not apply (see "A divergence to keep in mind").
Action: the lint/format/test gate of `CLAUDE.md` serves as the final check and not as a substitute for judgement; route every verifiable decision to an executable oracle (a test, property-based testing, an invariant, a CI gate) rather than to a judge, and reserve the judges (levers 1-2) for the zones with no oracle.
Widening the executable surface takes priority over multiplying judges.

### 1. Adversarial critique in a fresh conversation

Intrinsic self-correction (self-critique inside the build thread) fails and can degrade a correct output: the model defends its own production or hallucinates defects in it.
The critic must live in a fresh context, with no stake in the output being evaluated.

### 2. Cross-provider judge

Decoupling generator and evaluator is not enough: a judge from the same model shares the self-preference bias (it overvalues familiar, low-perplexity texts, often its own).
Real decorrelation requires lineage diversity (cross-provider), not merely a second instance of the same model.
Tradeoff: `/audit:skill-adversary` stays Opus↔Sonnet (same lineage, weak decorrelation per Wu et al.) because it audits SKILL.md files rather than judgements about your code: lower sycophancy stake, nothing to carry.
DO NOT carry L2 into `/audit:sweep` (settled on 2026-07-04): sweep does not verify by design and sends its findings to the walkthrough, which applies the cross-provider L2, so carrying them there would duplicate that machinery and break the "sweep does not verify" contract.
Action: build nothing.
The only gap is behavioural: after a sweep, always follow with `/audit:walkthrough` on the Blocking/Required findings before acting, so as not to short-circuit the L2.
Never rely on a same-model judge when the decision is about code Claude produced.

### 3. "Ask don't tell"

Rephrasing a statement as a neutral question before asking for an opinion reduces sycophancy far more effectively than a "do not be sycophantic" instruction.
Hiding your preference from the evaluator is the best-validated prompt lever.
It started on the user's side, and the "Neutralize a stated stance before judging it" rule of `CLAUDE.md` (section Communication) takes it up on the model's side, so coverage no longer depends on the user's discipline.

### 4. Forced disagreement in multi-agent

Naive fan-out amplifies sycophancy: agents in debate politely approve each other ("reinforce each other's responses instead of critically engaging") and propagate the error.
Distinct personas and explicit adversarial roles are required, otherwise the consensus reached is polite and false.
Action: when fanning out, assign distinct adversarial roles.
The split is already carried by `rules/agents.md` ("Each agent prompt targets a non-overlapping facet; never give the same broad prompt to several agents", injected on the first `Agent` call) and by the disjoint scopes of `/audit:sweep`; nothing carries the adversariality of the roles, "Adversarial review" of `CLAUDE.md` settling only who stops the rounds.

## A lever investigated and rejected: provenance blinding (2026-07-04)

A candidate addition to the structural levers: hiding from the judge who authored the candidate being evaluated, a cheap corollary of the self-preference bias (Wu et al.) already cited at lever 2.
In theory, a universal and zero-cost complement to cross-provider, which is itself conditional (`OPENROUTER_API_KEY`) and limited to the high-stake paths.
Source inspection (hebstr `~/Documents/packages/claude-code-plugins`): the lever has no real application surface once the code is read.

- Blindspot `agents/cross-model-judge.md` §2: the prompt discloses the author ("authored by ... Claude, Anthropic"), but the judge is cross-provider (Gemini/GPT/DeepSeek/Llama).
  Disjoint lineages: self-preference does not fire, and the disclosure usefully primes the adversarial posture.
  Do not blind.
- Walkthrough L2: cross-provider, and that is the only reason that holds.
  "Out of surface" also rested on a non-editable internal prompt, which dropping Ouroboros (2026-10-08) undid by bringing the prompt back into the repository, observed here on 2026-10-13 (`feedback_audit_walkthrough` holds the new naming): the target still has disjoint lineages, which is enough for the conclusion, but the non-editability argument is not to be reused.
- Walkthrough L1 within the family (Opus↔Sonnet): the only same-lineage target in the whole machinery, so the only place where self-preference could bite.
  But L1 is a fresh agent with no build context, evaluating a finding produced by another reviewer: no authorship signal reaches it.
  Self-preference needs that signal to express itself; it is already absent.
  The existing anti-anchoring also covers independence from the report: "Start from the code, not from the review report" opens `2b. Re-evaluate` in walkthrough's `SKILL.md`, and `1. Rapid pre-verdict` of `batch-triage.md` repeats it for batch mode.

Decision: build nothing.
The structural separation already in place (fresh contexts, cross-provider on the stake-carrying paths, L1 anti-anchoring) covers the mechanism blinding would target.
Same reason as the refusal to carry L2 into sweep (see lever 2): an addition with no real consumer is dead metadata.
Do not re-propose provenance blinding as a structural lever.
The one leftover on the user's side: when you yourself present two options to settle in direct conversation, give them with no authorship attribution.
That is already under your control, with no rule to add.

## Levers out of reach of a Claude Code user

They live on the model-training side, cited for completeness:
- Anti-sycophancy fine-tuning on synthetic data (DeepMind): reduces it significantly on held-out.
- Activation steering (the CAA family): an intervention internal to inference.
- A sober bound: training directly against sycophancy reduces it without eliminating it ("Sycophancy to Subterfuge"); layered defences, not a single fix.

## Calibration: a weak lever

Verbalized confidence is systematically overconfident (clusters at 80-100%).
Do not treat declared confidence or the model's agreement as a signal of truth.
Structural separation is what carries, not calibration.

## Debiasing an LLM-as-judge (reminder)

- An explicit rubric.
- Randomization or swapping of the candidate order (position bias can move a win-rate by 10-15 pts).
- Panels of judges from different lineages (a same-family panel shares the bias).
- Verbosity bias is more stubborn because it is learned rather than merely positional.
- Monitoring against human labels.

## A divergence to keep in mind

Self-Refine (helps) and "Cannot Self-Correct" (harms) do not contradict each other: it depends on the task type.

- Open-ended generation: refinement loops help.
- Verifiable reasoning: self-critique alone does not make it reliable, an external anchor is required (tests, lint, a rubric).

## Sources (URLs verified in a main thread unless stated otherwise)

Verified:
- Sharma et al. (Anthropic), "Towards Understanding Sycophancy in Language Models": https://arxiv.org/abs/2310.13548
- Huang et al. (DeepMind), "Large Language Models Cannot Self-Correct Reasoning Yet": https://arxiv.org/abs/2310.01798
- Wu et al., "Self-Preference Bias in LLM-as-a-Judge": https://arxiv.org/abs/2410.21819
- Dubois et al. (UK AISI), "Ask don't tell: Reducing sycophancy in large language models": https://arxiv.org/abs/2602.23971
- "CONSENSAGENT: ... Consensus in Multi-Agent LLM Interactions Through Sycophancy Mitigation": https://aclanthology.org/2025.findings-acl.1141/
- Anthropic Engineering, "How we built our multi-agent research system": https://www.anthropic.com/engineering/multi-agent-research-system

Reported by an agent, not re-verified in a main thread (corroborative, lower confidence on the verbatim):
- OpenAI, "Sycophancy in GPT-4o: What happened..." (April 2025; blocks automated fetching, HTTP 403)
- Snorkel AI, "The Self-Critique Paradox"
- Fanous et al., "SycEval": https://arxiv.org/abs/2502.08177
- Zheng et al., "Judging LLM-as-a-Judge with MT-Bench...": https://arxiv.org/abs/2306.05685
- Denison et al. (Anthropic), "Sycophancy to Subterfuge": https://arxiv.org/abs/2406.10162
- Wei et al. (DeepMind), "Simple synthetic data reduces sycophancy...": https://arxiv.org/abs/2308.03958
