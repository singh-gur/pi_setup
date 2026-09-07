#!/usr/bin/env python3
"""Regression tests for pi_setup installer config sync.

Runs ./install.sh --config-only against disposable temp target dirs only.
Never touches the real user pi config, the network, or installed state.
"""

import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
INSTALL_SH = REPO / "install.sh"
SOURCE_AGENTS = REPO / "pi" / "agent" / "agents" / "workbench"
AGENT_FILES = ("plan-auditor.md", "brief-analyst.md", "diagram-producer.md", "verification-runner.md")
MANAGED_REL = Path("agents/workbench")

failures: list[str] = []


def check(name: str, cond: bool, detail: str = "") -> None:
    status = "ok" if cond else "FAIL"
    print(f"[{status}] {name}" + (f" — {detail}" if detail and not cond else ""))
    if not cond:
        failures.append(name)


def run_install(target: Path | None, *args: str, env_extra: dict | None = None) -> subprocess.CompletedProcess:
    env = {k: v for k, v in os.environ.items() if k != "PI_CODING_AGENT_DIR"}
    if env_extra:
        env.update(env_extra)
    cmd = [str(INSTALL_SH), "--config-only"]
    if target is not None:
        cmd += ["--pi-dir", str(target)]
    return subprocess.run(
        [*cmd, *args],
        capture_output=True,
        text=True,
        env=env,
        cwd=str(REPO),
    )


def write_agent_fixtures(target: Path) -> None:
    (target / "agents" / "nested").mkdir(parents=True, exist_ok=True)
    (target / "agents" / "personal.md").write_text("name: personal\ndescription: user agent\n")
    (target / "agents" / "nested" / "deep.md").write_text("name: deep\ndescription: nested user agent\n")


def assert_agents_state(target: Path, name: str) -> None:
    managed = target / MANAGED_REL
    check(f"{name}: managed agent files installed", managed.is_dir() and sorted(p.name for p in managed.iterdir()) == sorted(AGENT_FILES))
    check(f"{name}: unrelated root agent preserved", (target / "agents" / "personal.md").is_file())
    check(f"{name}: unrelated nested agent preserved", (target / "agents" / "nested" / "deep.md").is_file())


def tree_hash(path: Path) -> str:
    sha = hashlib.sha256()
    for p in sorted(path.rglob("*")):
        sha.update(str(p.relative_to(path)).encode())
        if p.is_file() and not p.is_symlink():
            sha.update(p.read_bytes())
    return sha.hexdigest()


def test_fresh_install_preserves_user_state() -> None:
    with tempfile.TemporaryDirectory(prefix="pi-setup-test-") as tmp:
        target = Path(tmp)
        write_agent_fixtures(target)
        (target / "settings.json").write_text(
            json.dumps({"subagents": {"agentOverrides": {"workbench-plan-auditor": {"model": "my-local-model"}}}, "unowned": True})
        )
        (target / "auth.json").write_text('{"anthropic": {"api_key": "x"}}')
        (target / "sessions").mkdir()
        (target / "sessions" / "s1.json").write_text("{}")
        result = run_install(target)
        check("fresh install: exit 0", result.returncode == 0, result.stderr)
        assert_agents_state(target, "fresh install")
        check("fresh install: protected auth preserved", json.loads((target / "auth.json").read_text())["anthropic"]["api_key"] == "x")
        check("fresh install: protected sessions preserved", (target / "sessions" / "s1.json").is_file())
        merged = json.loads((target / "settings.json").read_text())
        check("fresh install: repo settings merged", merged.get("theme") == "catppuccin-mocha/catppuccin-mocha")
        check(
            "fresh install: unowned model override preserved",
            merged.get("subagents") == {"agentOverrides": {"workbench-plan-auditor": {"model": "my-local-model"}}},
        )
        check("fresh install: unowned settings key preserved", merged.get("unowned") is True)


def test_repeat_install_removes_retired_managed_file() -> None:
    with tempfile.TemporaryDirectory(prefix="pi-setup-test-") as tmp:
        target = Path(tmp)
        write_agent_fixtures(target)
        run_install(target)
        (target / MANAGED_REL / "retired.md").write_text("stale managed file\n")
        (target / MANAGED_REL / AGENT_FILES[0]).write_text("tampered\n")
        result = run_install(target)
        check("repeat install: exit 0", result.returncode == 0, result.stderr)
        check("repeat install: retired managed file removed", not (target / MANAGED_REL / "retired.md").exists())
        check(
            "repeat install: managed file restored",
            (target / MANAGED_REL / AGENT_FILES[0]).read_text() == (SOURCE_AGENTS / AGENT_FILES[0]).read_text(),
        )
        assert_agents_state(target, "repeat install")


def test_symlink_copy_transitions() -> None:
    with tempfile.TemporaryDirectory(prefix="pi-setup-test-") as tmp:
        target = Path(tmp)
        write_agent_fixtures(target)
        source_hash = tree_hash(SOURCE_AGENTS)
        run_install(target)
        check("transition: copy mode creates real dir", (target / MANAGED_REL).is_dir() and not (target / MANAGED_REL).is_symlink())
        result = run_install(target, "--symlink")
        check("transition: symlink mode exit 0", result.returncode == 0, result.stderr)
        link = target / MANAGED_REL
        check("transition: managed subtree is symlink to source", link.is_symlink() and os.readlink(link) == str(SOURCE_AGENTS))
        assert_agents_state(target, "symlink mode")
        result = run_install(target)
        check("transition: back to copy exit 0", result.returncode == 0, result.stderr)
        check("transition: copy mode replaces symlink with real dir", (target / MANAGED_REL).is_dir() and not (target / MANAGED_REL).is_symlink())
        assert_agents_state(target, "copy after symlink")
        check("transition: source tree unmodified", tree_hash(SOURCE_AGENTS) == source_hash)


def test_clean_boundary() -> None:
    with tempfile.TemporaryDirectory(prefix="pi-setup-test-") as tmp:
        target = Path(tmp)
        write_agent_fixtures(target)
        (target / "auth.json").write_text("{}")
        (target / "models.json").write_text("{}")
        (target / "sessions").mkdir()
        run_install(target)
        (target / MANAGED_REL / "retired.md").write_text("stale\n")
        result = run_install(target, "--clean")
        check("clean: exit 0", result.returncode == 0, result.stderr)
        check("clean: retired managed file removed", not (target / MANAGED_REL / "retired.md").exists())
        assert_agents_state(target, "clean")
        check("clean: protected targets preserved", (target / "auth.json").is_file() and (target / "models.json").is_file() and (target / "sessions").is_dir())


def test_rejects_symlink_agents_parent() -> None:
    with tempfile.TemporaryDirectory(prefix="pi-setup-test-") as tmp:
        base = Path(tmp)
        target = base / "target"
        target.mkdir()
        unrelated = base / "unrelated-tree"
        unrelated.mkdir()
        (unrelated / "marker.md").write_text("keep me\n")
        (target / "agents").symlink_to(unrelated)
        settings = target / "settings.json"
        settings.write_text('{"unowned": true}')
        result = run_install(target)
        check("symlink agents parent: refused", result.returncode != 0)
        check("symlink agents parent: error names agents", "agents" in result.stderr, result.stderr)
        check("symlink agents parent: no config mutation", settings.read_text() == '{"unowned": true}' and not (target / "prompts").exists())
        check("symlink agents parent: referent untouched", (unrelated / "marker.md").read_text() == "keep me\n")


def test_rejects_file_agents_parent() -> None:
    with tempfile.TemporaryDirectory(prefix="pi-setup-test-") as tmp:
        target = Path(tmp) / "target"
        target.mkdir()
        (target / "agents").write_text("not a directory\n")
        result = run_install(target)
        check("file agents parent: refused", result.returncode != 0)
        check("file agents parent: error names agents", "agents" in result.stderr, result.stderr)
        check("file agents parent: file untouched", (target / "agents").read_text() == "not a directory\n")


def test_refusal_precedes_pi_install_update() -> None:
    with tempfile.TemporaryDirectory(prefix="pi-setup-test-") as tmp:
        base = Path(tmp)
        target = base / "target"
        target.mkdir()
        unrelated = base / "unrelated-tree"
        unrelated.mkdir()
        (target / "agents").symlink_to(unrelated)
        # Stub curl/pi write markers if invoked; the preflight must refuse first.
        stub_bin = base / "bin"
        stub_bin.mkdir()
        for tool in ("curl", "pi"):
            stub = stub_bin / tool
            stub.write_text(f"#!/bin/sh\ntouch {base / (tool + '.called')}\nexit 0\n")
            stub.chmod(0o755)
        env = {k: v for k, v in os.environ.items() if k != "PI_CODING_AGENT_DIR"}
        env["PATH"] = f"{stub_bin}:{env.get('PATH', '')}"
        result = subprocess.run(
            [str(INSTALL_SH), "--config-only", "--install-pi", "--update", "--pi-dir", str(target)],
            capture_output=True,
            text=True,
            env=env,
            cwd=str(REPO),
        )
        check("refusal ordering: refused with unsafe agents parent", result.returncode != 0)
        check("refusal ordering: install_pi never invoked", not (base / "curl.called").exists())
        check("refusal ordering: update_pi never invoked", not (base / "pi.called").exists())


def test_custom_target_via_env() -> None:
    with tempfile.TemporaryDirectory(prefix="pi-setup-test-") as tmp:
        target = Path(tmp) / "env-target"
        result = run_install(None, env_extra={"PI_CODING_AGENT_DIR": str(target)})
        check("env target: exit 0", result.returncode == 0, result.stderr)
        check("env target: managed agents installed", (target / MANAGED_REL / AGENT_FILES[0]).is_file())


def parse_frontmatter(path: Path) -> tuple[dict[str, str], str]:
    text = path.read_text()
    parts = text.split("\n---\n", 2)
    if not text.startswith("---") or len(parts) < 2:
        raise ValueError(f"{path}: missing frontmatter")
    fm: dict[str, str] = {}
    for line in parts[0][4:].splitlines():
        if ":" in line and not line.startswith((" ", "\t", "-")):
            key, _, value = line.partition(":")
            fm[key.strip()] = value.strip()
    body = parts[1] if len(parts) == 2 else parts[1] + "\n---\n" + parts[2]
    return fm, body


EXPECTED_TOOLS = {
    "plan-auditor": "read, grep, find, ls, contact_supervisor",
    "brief-analyst": "read, grep, find, ls, contact_supervisor",
    "diagram-producer": "read, grep, find, ls, bash, edit, write, contact_supervisor",
    "verification-runner": "read, grep, find, ls, bash, contact_supervisor",
}


def test_agent_frontmatter_contracts() -> None:
    for stem, expected_tools in EXPECTED_TOOLS.items():
        path = SOURCE_AGENTS / f"{stem}.md"
        fm, body = parse_frontmatter(path)
        check(f"{stem}: name", fm.get("name") == f"workbench-{stem}")
        desc = fm.get("description", "")
        check(f"{stem}: description present and advertised-size safe", bool(desc) and len(desc.encode()) <= 512)
        check(f"{stem}: advertise true", fm.get("advertise") == "true")
        check(f"{stem}: fresh default context", fm.get("defaultContext") == "fresh")
        check(f"{stem}: context inheritance", fm.get("inheritProjectContext") == "true" and fm.get("inheritGlobalContext") == "true")
        check(f"{stem}: skills not inherited", fm.get("inheritSkills") == "false")
        check(f"{stem}: strict tools", fm.get("tools") == expected_tools, fm.get("tools", ""))
        check(f"{stem}: no model or thinking pins", "model" not in fm and "thinking" not in fm and "fallbackModels" not in fm)
        check(f"{stem}: no nested delegation", "subagent" not in fm.get("tools", "") and "allowNestedSubagents" not in fm)
        check(f"{stem}: body present", len(body.strip()) > 200)
    ro = {"plan-auditor", "brief-analyst", "verification-runner"}
    for stem in ro:
        fm, _ = parse_frontmatter(SOURCE_AGENTS / f"{stem}.md")
        check(f"{stem}: acceptanceRole read-only", fm.get("acceptanceRole") == "read-only")
    fm, _ = parse_frontmatter(SOURCE_AGENTS / "verification-runner.md")
    check("verification-runner: completionGuard false", fm.get("completionGuard") == "false")
    fm, _ = parse_frontmatter(SOURCE_AGENTS / "diagram-producer.md")
    check("diagram-producer: selects draw-diagram skill", fm.get("skills") == "draw-diagram")
    check("diagram-producer: writer role", fm.get("acceptanceRole") == "writer")
    read_only = ("plan-auditor", "brief-analyst")
    for stem in read_only:
        fm, _ = parse_frontmatter(SOURCE_AGENTS / f"{stem}.md")
        check(f"{stem}: no skills selected", "skills" not in fm)


def test_native_frontmatter_parser_smoke() -> None:
    parser = Path.home() / ".pi/agent/npm/node_modules/pi-subagents/src/agents/frontmatter.ts"
    node = shutil.which("node")
    if not parser.is_file() or node is None:
        print("[skip] native parser smoke: installed pi-subagents source or node unavailable")
        return
    # Node refuses type stripping inside node_modules; the parser has zero
    # imports, so run an isolated copy from a temp dir.
    with tempfile.TemporaryDirectory(prefix="pi-setup-parser-") as tmp:
        isolated = Path(tmp) / "frontmatter.ts"
        shutil.copy(parser, isolated)
        script = (
            "import { parseFrontmatter } from " + json.dumps(isolated.as_uri()) + ";\n"
            "import { readFileSync } from 'node:fs';\n"
            "for (const f of " + json.dumps([str(SOURCE_AGENTS / f) for f in AGENT_FILES]) + ") {\n"
            "  const { frontmatter, body } = parseFrontmatter(readFileSync(f, 'utf-8'));\n"
            "  if (!frontmatter.name || !frontmatter.description) throw new Error(f + ': missing name/description');\n"
            "  if (!body.trim()) throw new Error(f + ': empty body');\n"
            "  console.log('parsed ' + frontmatter.name);\n"
            "}\n"
        )
        result = subprocess.run([node, "--input-type=module", "-e", script], capture_output=True, text=True)
    check("native parser smoke: all four agents parse", result.returncode == 0, result.stderr.strip())


def main() -> int:
    test_agent_frontmatter_contracts()
    test_native_frontmatter_parser_smoke()
    test_fresh_install_preserves_user_state()
    test_repeat_install_removes_retired_managed_file()
    test_symlink_copy_transitions()
    test_clean_boundary()
    test_rejects_symlink_agents_parent()
    test_rejects_file_agents_parent()
    test_refusal_precedes_pi_install_update()
    test_custom_target_via_env()
    if failures:
        print(f"\n{len(failures)} check(s) failed:")
        for name in failures:
            print(f"  - {name}")
        return 1
    print("\nall checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
