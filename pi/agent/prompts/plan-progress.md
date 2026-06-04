---
description: Review PLAN.md or a named plan file against current repo progress with repo evidence
---
Review implementation progress against a plan file in this repository.

User-supplied hint for this run: $@

Follow this workflow:
1. Use the `ask_user` tool before analysis to ask which plan to review.
   - Offer `PLAN.md (Recommended)` as the first option.
   - Also allow a custom plan name or relative path.
   - Ask exactly one focused question.
2. Resolve the target plan path using these rules:
   - If the user chooses the default or gives no usable value, use `PLAN.md`.
   - If the user gives a simple plan name without `.md`, check `plans/<name>.md`.
   - If the user gives a value ending in `.md` without a slash, check `plans/<value>` first, then `<value>`.
   - If the user gives a relative path containing a slash, treat it as an exact relative path.
3. If no matching plan file exists:
   - stop
   - tell the user exactly which paths you checked
   - do not guess beyond the rules above
4. Read the selected plan file carefully.
5. Inspect the repository to determine actual implementation status.
   - review files and directories mentioned by the plan
   - search for routes, commands, handlers, tests, migrations, configs, docs, and other concrete artifacts implied by the plan
   - distinguish fully implemented work from partial scaffolding, configuration, docs-only work, or placeholders
6. Compare the plan to the repo and produce a progress review.
7. Preserve the plan's structure when practical.
   - if it uses phases, milestones, or numbered sections, mirror that structure
   - if it is a flat checklist, keep the response grouped in a similarly readable way

For each meaningful plan item or phase, classify it as one of:
- `done`
- `in progress`
- `not started`
- `unclear`

For every classification:
- cite concrete repo evidence with `file_path:line_number` references when available
- explain why the status fits
- call out important gaps, blockers, or partial implementation
- say explicitly when something is only documented, configured, scaffolded, or stubbed rather than implemented

Your final response should include:

## Plan Reviewed
- the exact plan path used

## Overall Progress
- a short assessment of overall progress

## Item-by-Item Status
- concise bullets for each phase or item with status and evidence

## Risks or Gaps
- missing, inconsistent, or likely overlooked work

## Recommended Next Steps
- the highest-value next implementation steps based on the current repo state

Rules:
- Use `ask_user` before doing the main analysis.
- Be evidence-based; do not mark work complete without repository support.
- Prefer concise, high-signal output.
- If an item is ambiguous or aspirational, mark it `unclear` instead of guessing.
