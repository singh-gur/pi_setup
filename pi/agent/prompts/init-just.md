---
description: Create a helpful project justfile with documented tasks and a default task list
argument-hint: "[workflow goals or commands to include]"
---

Create a `justfile` for this project.

User-supplied context for this run: $@

Follow this workflow:

1. Inspect the repository to understand its stack, package manager, scripts, test/lint/build commands, and existing developer workflows.
2. Create or update a root `justfile` with useful, repeatable tasks for this project.
3. Prefer tasks that wrap existing project commands rather than inventing new workflows.
4. Add concise usage details as comments above tasks, including arguments or modes where helpful.
5. Include a default task that lists available `just` tasks, typically:

   ```just
   # Show available recipes.
   default:
       @just --list
   ```

6. Keep the `justfile` small, practical, and aligned with existing project conventions.
7. Do not overwrite unrelated existing recipes. If a `justfile` already exists, preserve useful current tasks and add only clearly helpful improvements.
8. Run a quick validation when possible, such as `just --list`, and report what changed.

Only ask before continuing if the project has multiple plausible command sets and the right workflow is unclear from repository evidence or user context.
