---
description: Stage relevant work, write a meaningful commit, and push, stopping only for real concerns
---
Help me prepare and ship the git changes for what I am currently working on.

User-supplied context for this run: $@

Workflow:
1. Inspect the repository state first: branch/remotes, `git status --short --branch`, and a diff summary.
2. Infer the likely scope of the current work. Use the user-supplied context above if present, but verify it against the actual changes.
3. Stage only the files relevant to the current work. Never use `git add .` unless you have verified all current changes are in scope.
4. Briefly review the staged diff. If it does not match the intended scope, fix it before proceeding.
5. Commit with a concise, meaningful message based on the actual changes. Incorporate the user-supplied context naturally if it helps.
6. Push to the appropriate upstream branch.
7. Report back with: the staged files, the final commit message, the branch and remote pushed, and any assumptions you made.

Stop and ask for confirmation (via the `ask_user` tool, grouping related questions in one call) only when you hit a real concern:
- merge, rebase, cherry-pick, or conflict state
- ambiguity about what should be staged, or untracked files whose purpose is unclear
- ambiguity about the push target, upstream branch, or remote
- very large, destructive, or sensitive-looking changes
- verification failures you observed while checking the work
- commit or push failures that need a decision

In that confirmation request, summarize what you found, what you plan to stage, the proposed commit message, and the intended push target. Do not commit or push until I confirm.

If there is nothing to commit, say so and stop.
