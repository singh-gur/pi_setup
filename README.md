# pi_setup

**One repo. One command. The same pi coding agent on every machine.**

`pi_setup` is a declarative, version-controlled setup for the [pi coding agent](https://pi.dev). Clone it on a new laptop, a server, or a Mac mini, run `just install`, and you get the same config, prompts, custom agents, packages, and skills you use everywhere else. It doesn't touch your credentials or session history.

```bash
git clone git@github.com:singh-gur/pi_setup.git && cd pi_setup
just install
```

---

## Why pi_setup

- **Reproducible.** Config lives in git, and every machine converges on the same state with `git pull && just install`.
- **Declarative.** Packages and skills are on/off switches in JSON. Set `true` to install a package or skill, and `false` to remove it.
- **Non-destructive.** Your settings are deep-merged, not overwritten. `auth.json` and `sessions/` are never touched, and your own custom agents are never deleted.
- **Ready to use.** It ships with workflow prompts, four specialist subagents, a curated package set, and an external skill catalog.
- **Safe to rerun.** Running it again only changes what is out of date.
- **Tested.** An installer regression suite runs with `just check`.

## What you get

| Component | What it adds | Source |
| --- | --- | --- |
| **Prompt templates** | `/gitship`, `/jjship`, `/status`, `/plan-progress`, `/init-just`, `/clone-prompt` | `pi/agent/prompts/` |
| **Specialist agents** | Plan auditor, brief analyst, diagram producer, verification runner | `pi/agent/agents/workbench/` |
| **Global rules** | Shared agent instructions for every session | `pi/agent/AGENTS.md` |
| **Settings** | Theme, fullscreen TUI, startup, and warning defaults | `pi/agent/settings.json` |
| **Model overrides** | 1M context for `openai-codex` `gpt-6.1-sol` and `gpt-6-astra` | `pi/agent/models.json` |
| **pi packages** | Subagents, web access, themes, usage tracking, todo, ask-user, and more | `packages.json` |
| **External skills** | Planning, architecture, diagrams, security review, CI, browser automation, and more | `skills-install.json` |
| **Provider helper** | Interactive setup for API keys and custom/local models | `scripts/add-provider-api-key.sh` |

### Prompt templates

| Command | What it does |
| --- | --- |
| `/gitship` | Stage relevant work, write a meaningful commit, and push; stops only for real concerns |
| `/jjship` | Describe the working-copy change, update bookmarks, and push via jj |
| `/status` | Report progress and blockers of in-progress work, then resume it |
| `/plan-progress` | Check a plan file against the current repository, with evidence for each status |
| `/init-just` | Create a project `justfile` with documented tasks and a default task list |
| `/clone-prompt` | Study the current repo and generate prompts for building something similar |

---

## Prerequisites

| Tool | Used for |
| --- | --- |
| bash 4.4+ | `install.sh` and helper scripts |
| Python 3 (3.10+ for `just check`) | JSON merges, provider helper, regression tests |
| `jq` | Parsing `packages.json` and `skills-install.json` |
| `just` | Helper recipes (optional; `./install.sh` works directly) |
| Node.js / `npx` | Installing external skills via the `skills` CLI |
| `curl` | Installing pi with `--install-pi` |

### Linux

Most distributions ship a modern bash and Python. Install the rest with your package manager, for example:

```bash
sudo apt install jq just nodejs npm curl
```

### macOS

macOS ships bash 3.2 and Python 3.9, so `./install.sh` fails with `bad substitution` until you switch to the Homebrew versions:

```bash
brew install bash python jq just node
```

Homebrew must also come before `/bin` and `/usr/bin` on your `PATH`. If `/opt/homebrew/bin` isn't already near the front, add this to `~/.zprofile`:

```bash
eval "$(/opt/homebrew/bin/brew shellenv)"
```

Then **open a new terminal tab**, because existing tabs and running `pi` sessions keep the old `PATH`. Check it:

```bash
command -v bash   # /opt/homebrew/bin/bash
bash --version    # 4.4 or newer
```

---

## Quick start

```bash
just install full   # install/update pi, sync everything, update packages and skills
pi                  # start pi, then run /login or export provider API keys
```

Already have pi? Use `just install` instead.

## Commands

### just recipes

| Command | What it does |
| --- | --- |
| `just` | List available recipes |
| `just install` | Sync config, install missing packages, sync external skills |
| `just install config` | Sync only repo-managed files under `pi/agent/` |
| `just install packages` | Sync only pi packages from `packages.json` |
| `just install skills` | Sync only external skills from `skills-install.json` |
| `just install symlink` | Sync config as symlinks into the repo instead of copies |
| `just install update` | Sync, then update pi, its extensions, and external skills |
| `just install full` | Install/update pi, sync, then update packages and skills |
| `just install clean` | Remove and reinstall managed config and configured packages |
| `just update` | Same as `just install update` |
| `just add-provider` | Configure provider API keys or custom models |
| `just check` | Validate scripts and JSON, and run installer regression tests |

### install.sh flags

| Flag | Effect |
| --- | --- |
| `--symlink` | Symlink files instead of copying them |
| `--install-pi` | Install/update pi via the official `https://pi.dev/install.sh` installer |
| `--update` | After syncing, run `pi update` and `pi update --extensions` |
| `--config-only` | Sync only repo-managed config files |
| `--packages-only` | Sync only pi packages |
| `--clean` | Remove managed config targets and configured packages, then reinstall |
| `--update-packages` | Run one `pi update --extensions` after package sync |
| `--update-skills` | Run `npx skills update -g` before syncing skills |
| `--pi-dir <path>` | Target a different pi config dir (or set `PI_CODING_AGENT_DIR`) |

---

## How syncing works

By default, each top-level item in `pi/agent/` is copied into `~/.pi/agent`. Some paths get special handling:

| Target path | Behavior |
| --- | --- |
| `settings.json` | Deep-merged. Your local keys survive; repo keys win on conflict |
| `models.json` | Deep-merged and never removed, even by `--clean`. Your providers and models are kept |
| `agents/workbench/` | The only part of `agents/` the installer owns. Other agents are never touched |
| `auth.json`, `sessions/` | Protected and never read, written, or removed |
| Everything else | Copied (or symlinked with `--symlink`). Changed files are replaced |

Safety guarantees:

- The installer refuses to run if the target `agents/` is a symlink or not a directory. It checks this before changing anything, including before `--install-pi` or `--update`.
- `--clean` removes the target `settings.json` before re-merging, so local settings overrides are lost in that mode. Use a normal install to keep them.
- If `pi` isn't on `PATH` yet, package sync is skipped with a warning. Failed skill installs are reported, and the installer continues with the remaining skills.

To manage more global pi files, drop them into `pi/agent/`, for example `keybindings.json`, `SYSTEM.md`, `skills/`, `extensions/`, or `themes/`.

---

## Configuration

### pi packages: `packages.json`

```json
{
  "packages": {
    "npm:pi-subagents": true,
    "npm:old-extension": false,
    "git:github.com/user/pi-package": true
  }
}
```

- `true`: installed if missing
- `false`: removed if installed
- Version pins work as usual, for example `npm:pkg@1.2.3`

See [`packages.json`](packages.json) for the current set.

### External skills: `skills-install.json`

Maps repository URLs to skill switches:

```json
{
  "https://github.com/singh-gur/agent_skills": {
    "plan": true,
    "old-skill": false
  },
  "https://github.com/vercel-labs/agent-browser": {
    "agent-browser": true
  }
}
```

Skills are installed globally with:

```bash
npx skills add <repo> --skill <skill> -g -y -a pi -a universal
```

The `-a pi -a universal` flags limit installs to pi and the shared `~/.agents/skills/` directory. This avoids `skills` CLI agents that don't support global installs. Legacy arrays of skill names are still treated as enabled. See [`skills-install.json`](skills-install.json) for the current catalog.

---

## Workbench specialist agents

Four native custom agents install into `~/.pi/agent/agents/workbench/`, where the `pi-subagents` extension discovers them:

| Agent | Role |
| --- | --- |
| `workbench-plan-auditor` | Read-only audit of a plan against the real repository, including Workhorse/Smart handoff readiness. Returns evidence, gaps, and minimal corrections |
| `workbench-brief-analyst` | Read-only analysis of a brief or spec: contradictions, load-bearing assumptions, and dependency-ready questions |
| `workbench-diagram-producer` | Turns an approved diagram brief into rendered, visually inspected diagrams via the `draw-diagram` skill |
| `workbench-verification-runner` | Runs approved verification commands and reports exact commands, exit codes, and pass/fail/not-run verdicts |

Design choices:

- **No pinned models.** Your `subagents.defaultModel`, `subagents.agentOverrides.<name>`, and per-run overrides stay in control. These agents sit outside Agent Loadout tiers, which accept only built-in roles.
- **Tight scope.** Each agent has a strict tool allowlist, starts with fresh context, doesn't inherit the skills catalog, and can't spawn nested subagents.
- **Discoverable.** All four set `advertise: true`. After changing them, restart pi or run `/reload`. Parents confirm availability with `subagent({ action: "list", capabilities: true })`.

> **Shell caveat:** `workbench-verification-runner` and `workbench-diagram-producer` have `bash`. The shell is not a sandbox; both are limited by their prompts to commands and paths the parent session approves. Treat their reports as evidence, not as a security boundary.

---

## Provider setup helper

Set up API keys and custom models interactively, without committing anything to the repo:

```bash
just add-provider                           # choose auth, models, or both
./scripts/add-provider-api-key.sh --auth    # API key into ~/.pi/agent/auth.json
./scripts/add-provider-api-key.sh --models  # custom provider into ~/.pi/agent/models.json
```

**`--auth`** asks for a supported provider key and a hidden API key. Supported providers: `anthropic`, `azure-openai-responses`, `openai`, `google`, `mistral`, `groq`, `cerebras`, `cursor`, `xai`, `openrouter`, `vercel-ai-gateway`, `zai`, `opencode`, `opencode-go`, `huggingface`, `kimi-coding`, `minimax`, `minimax-cn`.

**`--models`** sets up custom or local providers such as Ollama. It supports the `openai-completions`, `openai-responses`, `anthropic-messages`, and `google-generative-ai` API types, with token presets:

| Preset | Context window | Max output |
| --- | --- | --- |
| Standard coding | 128,000 | 16,384 |
| Small/local | 32,000 | 4,096 |
| Large coding | 200,000 | 32,000 |
| Huge context | 1,000,000 | 65,536 |
| Custom | any positive integer | any positive integer |

Example result:

```json
{
  "providers": {
    "ollama": {
      "baseUrl": "http://localhost:11434/v1",
      "api": "openai-completions",
      "apiKey": "ollama",
      "models": [{ "id": "llama3.1:8b", "contextWindow": 128000, "maxTokens": 16384 }]
    }
  }
}
```

Both flows keep existing entries, back up the file before writing, and save it with `0600` permissions. Prefer `$ENV_VAR`, `${ENV_VAR}`, or `!command` API key values over raw secrets. See the [pi models docs](https://pi.dev/docs/latest/models).

---

## Keeping machines in sync

```bash
git pull && just install          # converge on the latest config
just install update               # ...and update pi, extensions, and skills
just install clean                # start fresh (auth, sessions, and models.json are kept)
```

## Development

```bash
just check
```

This runs:

- `bash -n` on every shell script
- A smoke test of the provider helper
- JSON validation
- `scripts/test-install.py`: config-only installer regression tests in disposable temp dirs, covering agent ownership, settings merge, symlink/copy transitions, and refusal cases

Run it after changing `install.sh`, `scripts/`, `pi/agent/agents/workbench/`, `packages.json`, or `skills-install.json`.

## Repo layout

```text
.
├── install.sh                 # main installer
├── justfile                   # helper recipes
├── packages.json              # pi package switches
├── skills-install.json        # external skill switches
├── scripts/
│   ├── add-provider-api-key.sh
│   ├── install-skills.sh
│   ├── merge-json.py
│   ├── test-install.py
│   └── update-provider-config.py
└── pi/agent/                  # synced into ~/.pi/agent
    ├── AGENTS.md
    ├── agents/workbench/      # four specialist agents
    ├── prompts/               # slash-command prompt templates
    ├── models.json
    └── settings.json
```

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `bad substitution` or `declare: -A: invalid option` | Old bash (macOS); see [macOS prerequisites](#macos) |
| `pi is not available on PATH yet` | Run `just install full`, or add `~/.pi/agent/bin` to `PATH` |
| Packages or skills skipped with a `jq`/`npx` warning | Install the missing tool and rerun |
| `refusing to sync agents` | The target `agents/` is a symlink or a file; replace it with a real directory |
| New agents or prompts not showing up | Restart pi or run `/reload` |
