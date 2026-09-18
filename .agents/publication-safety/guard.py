#!/usr/bin/env python3
"""Portable, value-redacting repository publication floor; not a complete secret scanner."""

import argparse
import hashlib
import os
from pathlib import Path
import re
import subprocess
import sys

LIMIT = 5 * 1024 * 1024
SENSITIVE = re.compile(r"(^|/)(\.env($|\.(?!example$|sample$|template$)[^/]+$)|\.(npmrc|pypirc|netrc|git-credentials)$|\.aws/credentials$|\.kube/config$|id_(rsa|ed25519|ecdsa|dsa)$|[^/]*\.(pem|p12|pfx|key)$|credentials?\.json$|secrets?\.(json|ya?ml|toml)$|service.account[^/]*\.json$)", re.I)
PATTERNS = {
    "private-key": re.compile(rb"-----BEGIN (?:[A-Z ]+ )?PRIVATE KEY-----"),
    "github-token": re.compile(rb"\b(?:gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,})\b"),
    "cloud-key": re.compile(rb"\b(?:AKIA|ASIA)[A-Z0-9]{16}\b"),
    "provider-key": re.compile(rb"\b(?:sk_(?:live|test)_[A-Za-z0-9]{12,}|sk-[A-Za-z0-9_-]{24,})\b"),
    "credential-assignment": re.compile(rb"(?im)^\s*[A-Z_]*(?:API_KEY|ACCESS_TOKEN|CLIENT_SECRET|PRIVATE_KEY|PASSWORD|DATABASE_URL|REDIS_URL|MONGO(?:DB)?_URI|CONNECTION_STRING)\s*[:=]\s*['\"]?(?!example\b|sample\b|placeholder\b|your[_-])[^\s'\"#]{16,}"),
}


def git(repo, *args):
    return subprocess.run(["git", "-C", str(repo), *args], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE).stdout


def validate(repo):
    try:
        root = Path(os.fsdecode(git(repo, "rev-parse", "--show-toplevel").strip())).resolve()
    except subprocess.CalledProcessError as exc:
        raise RuntimeError("not a readable Git worktree") from exc
    if root != repo.resolve():
        raise RuntimeError("--repo must name the Git worktree root")


def inspect(label, path, content, findings):
    path = path.replace("\\", "/")
    reasons = []
    if SENSITIVE.search(path):
        reasons.append("sensitive-path")
    if any(pattern.search(os.fsencode(path)) for pattern in PATTERNS.values()):
        reasons.append("sensitive-filename")
    if content is None or len(content) > LIMIT:
        reasons.append("oversized-unreviewed")
    else:
        if content.startswith(b"version https://git-lfs.github.com/spec/v1\n"):
            reasons.append("lfs-payload-unreviewed")
        for name, pattern in PATTERNS.items():
            if pattern.search(content):
                reasons.append(name)
    for reason in reasons:
        findings.add((label, path, reason))


def blob(repo, sha):
    if int(git(repo, "cat-file", "-s", sha).strip()) > LIMIT:
        return None
    return git(repo, "cat-file", "-p", sha)


def path_id(path):
    return hashlib.sha256(os.fsencode(path)).hexdigest()[:16]


def scan(repo, scope, message_file=None):
    findings = set()
    notices = set()
    if scope == "commit-message":
        if message_file is None or not message_file.is_file():
            raise RuntimeError("missing commit message file")
        inspect("commit-message", "<pending-commit-message>", message_file.read_bytes() if message_file.stat().st_size <= LIMIT else None, findings)
    if scope in ("staged", "all"):
        for record in git(repo, "ls-files", "--stage", "-z").split(b"\0"):
            if not record:
                continue
            meta, path = record.split(b"\t", 1)
            mode, sha, stage = meta.decode().split()
            name = os.fsdecode(path)
            if stage != "0":
                findings.add(("staged", name, "unmerged-index"))
            elif mode == "160000":
                findings.add(("staged", name, "submodule-review"))
            elif mode == "120000":
                findings.add(("staged", name, "symlink-review"))
            else:
                inspect("staged", name, blob(repo, sha), findings)
    if scope in ("worktree", "all"):
        paths = git(repo, "ls-files", "--cached", "--others", "--exclude-standard", "-z").split(b"\0")
        for raw in paths:
            if not raw:
                continue
            name = os.fsdecode(raw)
            target = repo / name
            if target.is_symlink():
                findings.add(("worktree", name, "symlink-review"))
            elif target.is_file():
                inspect("worktree", name, target.read_bytes() if target.stat().st_size <= LIMIT else None, findings)
        for raw in git(repo, "ls-files", "--others", "--ignored", "--exclude-standard", "-z").split(b"\0"):
            if raw and SENSITIVE.search(os.fsdecode(raw)):
                notices.add(("ignored-local", os.fsdecode(raw), "confirm-never-published"))
    if scope in ("history", "outgoing", "all"):
        if git(repo, "rev-parse", "--is-shallow-repository").strip() != b"false":
            raise RuntimeError("incomplete shallow history")
        additions = []
        if scope == "outgoing":
            for line in sys.stdin.buffer.read().splitlines():
                parts = line.split()
                if len(parts) != 4 or not re.fullmatch(rb"[0-9a-fA-F]{40,64}", parts[1]):
                    raise RuntimeError("invalid pre-push update record")
                if set(parts[1]) != {48}:
                    additions.append(parts[1].decode("ascii"))
        seen = set()
        for record in git(repo, "rev-list", "--objects", "--all", *additions).splitlines():
            sha, _, raw_path = record.partition(b" ")
            if sha in seen:
                continue
            seen.add(sha)
            kind = git(repo, "cat-file", "-t", sha).strip()
            if kind == b"blob":
                inspect("history", os.fsdecode(raw_path) or "<unmapped-blob>", blob(repo, sha.decode()), findings)
            elif kind in (b"commit", b"tag"):
                inspect("history-metadata", f"<{kind.decode()}:{sha.decode()}>", blob(repo, sha.decode()), findings)
        # rev-list gives one path hint per blob. A historical alias needs its own check.
        if git(repo, "rev-list", "--all", *additions).strip():
            for raw in git(repo, "log", "--all", *additions, "--root", "--format=", "--name-only", "-z").split(b"\0"):
                name = os.fsdecode(raw.lstrip(b"\n"))
                if name:
                    inspect("history-path", name, b"", findings)
        for raw in git(repo, "for-each-ref", "--format=%(refname)").splitlines():
            if raw:
                inspect("ref-name", os.fsdecode(raw), b"", findings)
    for label, path, reason in sorted(findings | notices):
        print(f"{label}: path-sha256={path_id(path)}: {reason}")
    print(f"{scope}: {len(findings)} blocking finding(s), {len(notices)} review notice(s); matched values withheld")
    return 1 if findings else 0


def install(repo):
    validate(repo)
    # A missing key is normal; any existing hook path belongs to its owner.
    hooks_path = subprocess.run(["git", "-C", str(repo), "config", "--get", "core.hooksPath"], capture_output=True)
    if hooks_path.returncode == 0:
        raise RuntimeError("existing core.hooksPath: integrate the guard without replacing hooks")
    if hooks_path.returncode != 1:
        raise RuntimeError("cannot inspect Git hook configuration")
    original_hooks = Path(os.fsdecode(git(repo, "rev-parse", "--git-path", "hooks").strip()))
    if not original_hooks.is_absolute():
        original_hooks = repo / original_hooks
    if original_hooks.is_dir() and any(p.is_file() and os.access(p, os.X_OK) and not p.name.endswith(".sample") for p in original_hooks.iterdir()):
        raise RuntimeError("existing executable Git hooks: integrate without replacing them")
    target = repo / ".agents/publication-safety/guard.py"
    hooks = repo / ".githooks"
    workflow = repo / ".github/workflows/publication-safety.yml"
    instructions = repo / "AGENTS.md"
    if hooks.exists() or hooks.is_symlink() or instructions.is_symlink():
        raise RuntimeError("existing hook directory or linked instructions: integrate manually")
    block = ("\n## Publication safety\n\nBefore every commit or push, run "
             "`python3 .agents/publication-safety/guard.py scan --repo . --scope all`; "
             "resolve findings without printing values. Never bypass hooks with `--no-verify`. "
             "Before public release, run the independent history scanner and review non-code surfaces.\n")
    prior = instructions.read_text() if instructions.exists() else ""
    if "## Publication safety" in prior:
        raise RuntimeError("existing publication instructions: integrate manually")
    outputs = {
        target: Path(__file__).read_bytes(),
        hooks / "pre-commit": b'#!/bin/sh\nset -eu\nexec python3 .agents/publication-safety/guard.py scan --repo . --scope staged\n',
        hooks / "commit-msg": b'#!/bin/sh\nset -eu\nexec python3 .agents/publication-safety/guard.py scan --repo . --scope commit-message --message-file "$1"\n',
        hooks / "pre-push": b'#!/bin/sh\nset -eu\nexec python3 .agents/publication-safety/guard.py scan --repo . --scope outgoing\n',
        workflow: b'name: Publication safety\non: [pull_request, push]\npermissions:\n  contents: read\njobs:\n  guard:\n    runs-on: ubuntu-latest\n    steps:\n      - uses: actions/checkout@v4\n        with:\n          fetch-depth: 0\n      - run: python3 .agents/publication-safety/guard.py scan --repo . --scope all\n',
    }
    for path in outputs:
        if path.exists() or path.is_symlink():
            raise RuntimeError(f"target already exists: {path.relative_to(repo)}")
    for path, content in outputs.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("xb") as handle:
            handle.write(content)
    for name in ("pre-commit", "commit-msg", "pre-push"):
        (hooks / name).chmod(0o755)
    instructions.write_text(prior.rstrip("\n") + "\n" + block)
    git(repo, "config", "--local", "core.hooksPath", ".githooks")
    print("Guard installed; review and commit the generated files, then verify hooks and CI.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    for command in ("scan", "install"):
        p = sub.add_parser(command)
        p.add_argument("--repo", type=Path, required=True)
        if command == "scan":
            p.add_argument("--scope", choices=("staged", "worktree", "history", "outgoing", "commit-message", "all"), default="all")
            p.add_argument("--message-file", type=Path)
    args = parser.parse_args()
    try:
        validate(args.repo)
        return scan(args.repo, args.scope, args.message_file) if args.command == "scan" else install(args.repo) or 0
    except (RuntimeError, OSError, subprocess.CalledProcessError) as exc:
        print(f"publication guard incomplete: {type(exc).__name__}; inspect repository and retry", file=sys.stderr)
        return 2

if __name__ == "__main__":
    sys.exit(main())
