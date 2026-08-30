---
description: Describe the working-copy change, update bookmarks, and push via jj, stopping only for real concerns
---
Help me prepare and ship the jj (Jujutsu) changes for what I am currently working on.

User-supplied context for this run: $@

Workflow:
1. Inspect the repository state first: `jj status`, a summary of `jj log -r 'ancestors(@, 10)'`, and `jj diff --stat`.
2. Infer the likely scope of the current change. Use the user-supplied context above if present, but verify it against the actual diff.
3. There is no staging area in jj; the working copy is itself a commit. If unrelated changes are present in `@`, split them out (`jj split`) or ask before touching them. Never rewrite or abandon changes that look unrelated to the current work.
4. Review the diff of `@`. If it does not match the intended scope, fix it before proceeding.
5. Set a concise, meaningful description with `jj describe`. Incorporate the user-supplied context naturally if it helps. Leave `@` on the finished change (do not run `jj new`) so the change can be bookmarked and pushed.
6. Ensure a bookmark points at the change to push: create (`jj bookmark set`) or move (`jj bookmark move`) the appropriate bookmark, following the repository's existing bookmark conventions. Use `jj bookmark list` to check tracked bookmarks and their targets first.
7. Push with `jj git push` (or a specific `--bookmark` when appropriate). Fetch first if the remote may have moved.
8. Start the next change on top with `jj new` only if that matches the user's intent for this run; otherwise leave the working copy where it is.
9. Report back with: the change ID(s) and descriptions, the bookmark(s) pushed, the remote, and any assumptions you made.

Stop and ask for confirmation (via the `ask_user` tool, grouping related questions in one call) only when you hit a real concern:
- conflicted changes or a conflicted bookmark that needs resolution first
- ambiguity about what belongs in this change, or unrelated changes present in `@`
- ambiguity about which bookmark to create, move, or push, or which remote to use
- a push that would require force-pushing, diverging, or rewriting shared history
- very large, destructive, or sensitive-looking changes
- verification failures or push failures that need a decision

In that confirmation request, summarize what you found, the proposed description, the bookmark and remote you intend to push. Do not move bookmarks or push until I confirm.

If there is nothing to ship (empty diff and no undescribed changes), say so and stop.
