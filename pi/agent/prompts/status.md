---
description: Report status of the in-progress work, then resume it
argument-hint: "[what to focus on]"
---
Pause briefly and give me a status report on the work you are currently doing, then continue it.

User-supplied focus for this report: $@

Report, from your own context and recent tool activity (do not start new investigation just to answer):
1. Goal: one line on what you are working on.
2. Done: what has been completed so far.
3. Now: what you are doing right now, including any long-running command or wait.
4. Next: remaining steps.
5. Blockers: anything stuck, failing, retried repeatedly, or needing my input. Say "none" if clear.

Keep it short. Then immediately resume the work where you left off without waiting for a reply. Do not restart or redo completed steps. If you are blocked on my input, ask via `ask_user` instead of resuming.
