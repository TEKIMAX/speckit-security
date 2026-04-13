---
description: "Pin model version, define eval criteria, rollback plan"
---

# Model Governance

Catch **Model Debt** at the DESIGN phase. Pin model versions, define
evaluation baselines, and write the rollback plan — before any code is
written.

## User Input

$ARGUMENTS

## Context

Any model integration without pinning, eval criteria, and a rollback
plan is reckless debt. This command forces the spec to answer those
questions in a machine-readable way so the gate-check can enforce them.

## Steps

1. **Read the active spec**. If it has no AI integration, exit with
   "no governance required — feature has no model integration".

2. **Collect or ask the user for**:
   - **Provider** — any model provider (e.g. Gemini, OpenAI, Anthropic, self-hosted).
   - **Model name and exact version** — no "latest", no unpinned tags.
   - **Gateway routing** — must route through the configured AI gateway.
     Reject any answer that calls the provider directly.
   - **Evaluation criteria** — pick at least three:
     - Accuracy / correctness benchmark
     - p50 and p95 latency thresholds
     - Cost per request ceiling (USD)
     - Safety score (jailbreak resistance)
     - Citation / grounding requirement
   - **Baseline values** — the current measurements for those criteria
     (if not yet measured, mark `[PRE-EVAL]` and schedule before
     `speckit.tasks`).
   - **Rollback trigger** — what metric crossing what threshold forces
     a rollback? Examples: p95 latency > 3s, error rate > 2%, cost
     spike > 150% of baseline, safety score drop > 10%.
   - **Rollback target** — which prior version do we roll back to?
     How fast can it happen (versioned runtime deploy can be
     near-instant)?
   - **Rollback owner** — who's paged, who has the authority to trigger?

3. **Write the governance section** to the spec under
   `## 3. AI Integration / Model Governance`:

   ```markdown
   ### Model Configuration

   - Provider: <name>
   - Model: <name>
   - Version: <exact version string, pinned>
   - Gateway: configured AI gateway (required)
   - Temperature / top-p: ...
   - Max tokens in / out: ...

   ### Evaluation Baselines

   | Metric | Threshold | Baseline | Measured |
   |--------|-----------|----------|----------|
   | Accuracy | ≥ 0.92 | 0.94 | 2026-04-12 |
   | p95 latency | < 2000 ms | 1650 ms | 2026-04-12 |
   | Cost / req | < $0.01 | $0.007 | 2026-04-12 |
   | Jailbreak resistance | ≥ 0.98 | 0.99 | 2026-04-12 |

   ### Rollback Plan

   - **Trigger**: <metric> crosses <threshold>
   - **Target version**: <prior pinned version>
   - **Mechanism**: versioned runtime deploy with instant rollback
   - **Time budget**: <seconds>
   - **Owner**: <name/role>
   - **Verification**: how we confirm rollback succeeded
   ```

4. **Write the pinned model into `.tekimax-security/stack.yml`** (create
   if missing) so `gate-check` can verify it:

   ```yaml
   ai:
     provider: <your-provider>
     model: <your-model>
     version: "<exact>"
     gateway: <your-ai-gateway>
     pinned_at: 2026-04-12
   ```

5. **Summarize**: pinned version, thresholds, rollback target, owner.

## Rules

- Reject any answer containing "latest", "stable", or an unpinned tag.
- Every threshold must be a number, not a word ("fast", "cheap" are
  not acceptable).
- Rollback target must exist (the prior version must have been deployed
  at least once — check your runtime's prior versions or the
  `deployments/` log).
- If the user cannot provide a rollback target, fail the command and
  instruct them to ship a baseline version first.
