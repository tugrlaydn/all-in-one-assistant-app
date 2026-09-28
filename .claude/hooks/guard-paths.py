#!/usr/bin/env python3
"""PreToolUse guard (A17, file-organization.md O5, working-agreements §8.6).

Blocks, before any permission mode applies:
- file writes outside the repo, $TMPDIR, /tmp and ~/Library/Caches/Persona;
- any write to docs/SPEC.md (the owner's file);
- shell commands that mention iCloud Drive or the personal folders;
- `defaults write/delete` for anything but the *.persona.debug domain;
- rm/mv/cp/tee/sed -i or a redirection whose target is outside the allowed places.

Exit 2 = block (stderr is shown to the agent). Exit 0 = allow.
The shell checks are a heuristic fence, not a shell parser.
"""
import json
import os
import re
import shlex
import sys

HOME = os.path.expanduser("~")
PROJECT = os.path.realpath(os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd())
SPEC = os.path.join(PROJECT, "docs", "SPEC.md")

FORBIDDEN_MENTIONS = [
    r"mobile\\?\s*documents",
    r"com~apple~clouddocs",
    r"icloud drive",
    r"(~|\$home|\$\{home\}|/users/[^/\s]+)/(documents|desktop|downloads)\b",
]
WRITE_COMMANDS = {"rm", "rmdir", "mv", "cp", "tee", "truncate", "touch", "mkdir", "ln", "rsync", "ditto", "install"}
COPY_COMMANDS = {"cp", "ln", "rsync", "ditto", "install"}
SEGMENT_SPLIT = re.compile(r"&&|\|\||;|\||\n")
REDIRECT = re.compile(r"^(?:\d|&)?>>?(.*)$")


def allowed_roots():
    roots = [PROJECT, "/tmp", "/private/tmp", os.path.join(HOME, "Library/Caches/Persona")]
    if os.environ.get("TMPDIR"):
        roots.append(os.environ["TMPDIR"])
    return [os.path.realpath(r) for r in roots]


ROOTS = allowed_roots()


def block(reason):
    print(f"Blocked by .claude/hooks/guard-paths.py: {reason}", file=sys.stderr)
    sys.exit(2)


def resolve(path, cwd):
    """Absolute, symlink-resolved path; works for files that don't exist yet."""
    path = os.path.expandvars(os.path.expanduser(path))
    if not os.path.isabs(path):
        path = os.path.join(cwd, path)
    path = os.path.normpath(path)
    head, tail = path, []
    while not os.path.exists(head) and head != os.path.dirname(head):
        head, part = os.path.split(head)
        tail.append(part)
    return os.path.normpath(os.path.join(os.path.realpath(head), *reversed(tail)))


def inside(path, root):
    return path == root or path.startswith(root.rstrip("/") + "/")


def check_write_path(raw, cwd):
    path = resolve(raw, cwd)
    if path == os.path.realpath(SPEC):
        block("docs/SPEC.md belongs to the owner; agents never edit it (O9).")
    if not any(inside(path, r) for r in ROOTS):
        block(f"write outside the repo, $TMPDIR and ~/Library/Caches/Persona: {path} (§8.6).")


def check_bash(command, cwd):
    lowered = command.lower()
    for pattern in FORBIDDEN_MENTIONS:
        if re.search(pattern, lowered):
            block("shell commands may not touch iCloud Drive or the personal folders (§8.6).")

    for segment in SEGMENT_SPLIT.split(command):
        try:
            tokens = shlex.split(segment)
        except ValueError:
            tokens = segment.split()
        if not tokens:
            continue

        for i, tok in enumerate(tokens):
            m = REDIRECT.match(tok)
            if not m:
                continue
            target = m.group(1) or (tokens[i + 1] if i + 1 < len(tokens) else "")
            if target and target != "/dev/null" and not target.startswith("&"):
                check_write_path(target, cwd)

        while tokens and (tokens[0] in ("sudo", "env", "command") or "=" in tokens[0]):
            tokens = tokens[1:]
        if not tokens:
            continue
        cmd = os.path.basename(tokens[0])
        args = [t for t in tokens[1:] if not t.startswith("-")]

        if cmd == "defaults" and args[:1] and args[0] in ("write", "delete", "import", "rename"):
            if len(args) < 2 or not args[1].endswith(".persona.debug"):
                block("`defaults` may only change the *.persona.debug domain (§8.6).")

        if cmd in WRITE_COMMANDS:
            # cp-like commands only write their destination; the rest touch every argument.
            targets = args[-1:] if cmd in COPY_COMMANDS else args
            for tok in targets:
                check_write_path(tok, cwd)
        elif cmd == "sed" and any(t.startswith("-i") for t in tokens[1:]):
            for tok in args:
                if "SPEC.md" in tok or os.path.isfile(resolve(tok, cwd)):
                    check_write_path(tok, cwd)


def main():
    try:
        payload = json.load(sys.stdin)
    except (ValueError, OSError):
        return 0
    tool = payload.get("tool_name", "")
    tool_input = payload.get("tool_input") or {}
    cwd = payload.get("cwd") or os.getcwd()
    if tool in ("Edit", "Write", "MultiEdit", "NotebookEdit"):
        raw = tool_input.get("file_path") or tool_input.get("notebook_path")
        if raw:
            check_write_path(raw, cwd)
    elif tool == "Bash":
        check_bash(tool_input.get("command", ""), cwd)
    return 0


if __name__ == "__main__":
    sys.exit(main())
