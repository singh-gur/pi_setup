---
description: Stage relevant work, write a meaningful commit, and push unless concerns need confirmation
---
Help me safely prepare and ship the git changes for what I am currently working on.

User-supplied context for this run: $@

Follow this workflow:
1. Inspect the repository state first before changing anything. Review branch/remotes, `git status --short --branch`, and a diff summary so you understand what changed.
2. Infer the likely scope of the current work. Use the user-supplied context above if present, but verify it against the actual changes.
3. Identify concerns before making git changes. Concerns include, at minimum:
   - unrelated or suspicious untracked files
   - mixed concerns that should probably be split into multiple commits
   - very large or destructive changes
   - merge, rebase, cherry-pick, or conflict state
   - ambiguity about what should be staged
   - ambiguity about the push target, upstream branch, or remote
   - any verification failures you observed while checking the work
4. If there are concerns, stop and ask me for confirmation before continuing. In that confirmation request, summarize:
   - what you found
   - what you plan to stage
   - the proposed commit message
   - the intended push target
   Do not commit or push until I confirm.
5. If there are no concerns, stage only the files that are relevant to the current work. Do not blindly stage unrelated changes.
6. Review the staged diff before committing. If the staged set does not match the intended scope, fix it before proceeding.
7. Write a meaningful commit message based on the actual changes. Keep it specific and useful. If the user-supplied context helps, incorporate it naturally instead of copying it blindly.
8. Commit the staged changes.
9. Push the commit to the appropriate upstream branch.
10. Report back with:
   - the staged files
   - the final commit message
   - the branch and remote that were pushed
   - any concerns you handled or assumptions you made

Important guardrails:
- Never use `git add .` or stage everything unless you have verified that all current changes are in scope.
- Ask before including untracked files when their purpose is unclear.
- Ask before pushing if the remote or target branch is unclear.
- If there is nothing to commit, say so and stop.
- Prefer a brief confirmation question over making a risky assumption.
