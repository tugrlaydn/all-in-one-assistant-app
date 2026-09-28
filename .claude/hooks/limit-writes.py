#!/usr/bin/env python3
"""PreToolUse hook for subagents with a write fence (A18).

Usage: limit-writes.py <repo-relative prefix> [<prefix> ...]
File tools may write only under the given prefixes. The shell may not commit,
push or rewrite git state (the primary owns commits, §8.5), and redirections /
rm / mv / cp targets must also sit under a prefix or in the temp directory.
Exit 2 = block.
"""
import json
import os
import re
import shlex
import sys

PROJECT = os.path.realpath(os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd())
PREFIXES = [os.path.join(PROJECT, p.strip("/")) for p in sys.argv[1:]]
TEMP = [os.path.realpath(p) for p in ("/tmp", "/private/tmp", os.environ.get("TMPDIR", "/tmp"))]
GIT_WRITES = {"commit", "push", "reset", "checkout", "switch", "rebase", "merge", "stash", "tag", "rm", "mv", "restore", "clean"}
WRITE_COMMANDS = {"rm", "rmdir", "mv", "cp", "tee", "touch", "mkdir", "truncate", "ln"}


def block(reason):
    print(f"Blocked by .claude/hooks/limit-writes.py: {reason}", file=sys.stderr)
    sys.exit(2)


def inside(path, root):
    return path == root or path.startswith(root.rstrip("/") + "/")


def check_path(raw, cwd, allow_temp=False):
    path = os.path.expanduser(raw)
    if not os.path.isabs(path):
        path = os.path.join(cwd, path)
    path = os.path.normpath(path)
    roots = PREFIXES + (TEMP if allow_temp else [])
    if not any(inside(path, r) for r in roots):
        block(f"this agent may write only under {', '.join(sys.argv[1:])}: {path}")


def check_bash(command, cwd):
    for segment in re.split(r"&&|\|\||;|\||\n", command):
        try:
            tokens = shlex.split(segment)
        except ValueError:
            tokens = segment.split()
        if not tokens:
            continue
        if tokens[0] == "git" and len(tokens) > 1 and tokens[1] in GIT_WRITES:
            block("subagents never change git state; the primary commits (§8.5).")
        for i, tok in enumerate(tokens):
            m = re.match(r"^(?:\d|&)?>>?(.*)$", tok)
            if m:
                target = m.group(1) or (tokens[i + 1] if i + 1 < len(tokens) else "")
                if target and target != "/dev/null" and not target.startswith("&"):
                    check_path(target, cwd, allow_temp=True)
        if tokens[0] in WRITE_COMMANDS:
            args = [t for t in tokens[1:] if not t.startswith("-")]
            for tok in (args[-1:] if tokens[0] in ("cp", "ln") else args):
                check_path(tok, cwd, allow_temp=True)


def main():
    try:
        payload = json.load(sys.stdin)
    except ValueError:
        return 0
    tool = payload.get("tool_name", "")
    tool_input = payload.get("tool_input") or {}
    cwd = payload.get("cwd") or PROJECT
    if tool in ("Edit", "Write", "MultiEdit", "NotebookEdit"):
        raw = tool_input.get("file_path") or tool_input.get("notebook_path")
        if raw:
            check_path(raw, cwd)
    elif tool == "Bash":
        check_bash(tool_input.get("command", ""), cwd)
    return 0


if __name__ == "__main__":
    sys.exit(main())
