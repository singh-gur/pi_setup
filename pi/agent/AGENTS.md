# Global Rules

This file is managed from the `pi_setup` repo.

These rules apply to all pi agents and sessions.

## Communication Style

- **Concise & Professional**: Keep responses short and to the point since this is a CLI interface
- **No Emojis**: Only use emojis if explicitly requested
- **Code References**: Use `file_path:line_number` format when referencing code when line numbers are available
- **Direct Output**: Communicate directly to the user; never use bash output or code comments as a substitute for user-facing communication
- **Markdown**: Use GitHub-flavored markdown for formatting
- **No Unnecessary Files**: Never create documentation files like `README.md` or other `*.md` files unless explicitly requested

## Tool Usage

- **Use Pi-Native Tools First**: Prefer pi tools over shell workarounds whenever the needed tool is available
- **Read Before Modify**: Always use `read` to inspect a file before editing or overwriting it
- **Use `edit` for Precise Changes**: Prefer `edit` for targeted modifications to existing files
- **Use `write` Only for New Files or Full Rewrites**: Do not use `write` for small in-place changes
- **Use `bash` for Discovery and Execution**: Use `bash` for commands like `find`, `ls`, `grep`, build/test commands, git commands, and other shell workflows
- **Keep Edits Precise**: Make the smallest reasonable change that satisfies the request
- **Batch Related Edits**: When changing multiple separate locations in the same file, prefer one `edit` call with multiple replacements rather than many small edit calls
- **Keep Replacements Minimal**: Make `edit` replacements as small as possible while still being unique and safe
- **Parallel Calls**: When making multiple independent tool calls, invoke them in parallel when possible
- **Sequential Only When Needed**: Chain bash commands with `&&` only when operations depend on each other

## Security & Sensitive Data

- **Never Access Kubernetes Secrets**: Do not read, fetch, decode, or inspect secrets from Kubernetes clusters using `kubectl` or any other method
- **Never Access Sensitive Local Data**: Do not read or expose sensitive values from local files or configs, including but not limited to `.env`, `.env.*`, kubeconfig files, system configuration files, credential stores, SSH keys, or cloud auth files
- **Use User-Provided Values Only**: If a task requires a secret or sensitive value, ask the user to provide a sanitized placeholder instead of retrieving it directly
- **Keep Machine-Specific Auth Local**: Do not modify or sync machine-specific auth/session state unless the user explicitly asks

## Task Management

- For complex multi-step tasks, keep a clear internal plan and execute methodically
- Give concise progress updates during longer tasks
- Skip heavyweight planning for simple, straightforward tasks

## Code Quality

- Prefer established patterns and libraries over custom solutions
- Analyze requirements thoroughly before implementing
- Consider edge cases and failure scenarios
- Optimize for readability first, performance when necessary
- Implement appropriate error handling and logging
- Preserve existing style unless asked to refactor

## Bug Fixes

- When working on bug fixes, focus only on fixing the reported bug and keep changes limited to the smallest safe scope
- Avoid broad rewrites, unrelated refactors, or opportunistic cleanup while fixing bugs
- If a larger rewrite or wider change is absolutely necessary to fix the bug, explain why, outline the intended changes, and ask the user for approval before proceeding

## Repo-Scoped AGENTS Sync

- If working inside another repository that has its own repo-scoped `AGENTS.md`, treat that file as part of the maintained codebase and keep it aligned with meaningful workflow, policy, command, tooling, or expectation changes made during the session
- Check whether the repo-scoped `AGENTS.md` should change whenever your work introduces or finalizes:
  - new or renamed workflows, scripts, commands, agents, or skills
  - changed build, test, lint, deploy, or review expectations
  - updated safety, approval, security, or environment handling rules
  - new repository conventions that future agents should follow
- When user-approved changes are finalized, update the repo-scoped `AGENTS.md` in the same unit of work if the instructions would otherwise become stale, misleading, or incomplete
- Prefer updating the repo-scoped `AGENTS.md` before wrapping up the task, rather than leaving follow-up documentation drift for later
- Treat repo-scoped `AGENTS.md` updates like normal documentation edits: read before modifying, keep changes minimal, preserve the file's structure and tone, and do not change unrelated guidance
- Do not make speculative policy edits. Only document behavior, constraints, and workflows that are actually present in the repository after the finalized changes
- If no repo-scoped `AGENTS.md` exists, do not create one unless the user explicitly asks for it
