---
description: Quickly stage the current work, commit it, and push with minimal friction
---
Help me ship the git changes for what I am currently working on with a more YOLO workflow.

User-supplied context for this run: $@

Follow this workflow:
1. Inspect the repository state first so you know what changed. Check branch/remotes, `git status --short --branch`, and a diff summary.
2. Infer the likely scope of the current work from the actual changes and the user-supplied context above.
3. Move fast. Unless something is clearly dangerous or ambiguous, do not stop for extra confirmation.
4. Stage the files that appear to belong to the current work. Prefer the obvious in-scope set instead of over-optimizing the staging decision.
5. Review the staged diff briefly. If something looks obviously unrelated, fix the staged set before continuing.
6. Write a concise, meaningful commit message based on the actual changes.
7. Commit the staged changes.
8. Push the commit to the current upstream branch when it is clear.
9. Report back with:
   - the staged files
   - the final commit message
   - the branch and remote that were pushed
   - any assumptions you made

Only stop and ask me before continuing if one of these is true:
- the repo is in a merge, rebase, cherry-pick, or conflict state
- the push target or upstream branch is unclear
- there is nothing clearly in scope to stage
- the changes look highly destructive or sensitive
- commit or push fails in a way that needs a decision

Important guardrails:
- Do not use `git add .` unless you have verified that everything currently changed is in scope.
- If there is nothing to commit, say so and stop.
- Prefer action over ceremony, but avoid clearly risky guesses.
