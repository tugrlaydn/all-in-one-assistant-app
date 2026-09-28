#!/usr/bin/env python3
"""PreToolUse hook for the `reviewer` subagent (A18): its shell may only read.

Allows a short list of read-only commands plus `make build` / `make test` /
`swift build` / `swift test` (they write only build products inside the repo).
Blocks redirections, in-place edits and every git command that changes state.
Exit 2 = block.
"""
import json
import re
import shlex
import sys

READ_ONLY = {
    "ls", "cat", "head", "tail", "wc", "grep", "rg", "find", "file", "stat", "tree",
    "diff", "sort", "uniq", "cut", "awk", "jq", "echo", "printf", "pwd", "which", "true",
    "plutil", "xcodebuild",
}
GIT_READ = {"log", "diff", "show", "status", "blame", "ls-files", "rev-parse", "branch", "grep"}
BUILD = {("make", "build"), ("make", "test"), ("swift", "build"), ("swift", "test")}


def block(reason):
    print(f"Blocked by .claude/hooks/read-only-bash.py: {reason}", file=sys.stderr)
    sys.exit(2)


def check(command):
    if re.search(r"(^|[^0-9&])>>?(?!\s*/dev/null)|\btee\b", command):
        block("the reviewer is read-only: no redirections or tee.")
    for segment in re.split(r"&&|\|\||;|\||\n", command):
        try:
            tokens = shlex.split(segment)
        except ValueError:
            block("could not parse the command.")
        if not tokens:
            continue
        cmd, args = tokens[0], tokens[1:]
        if cmd == "git":
            if not args or args[0] not in GIT_READ:
                block(f"git {args[0] if args else ''} is not read-only.")
        elif (cmd, args[0] if args else "") in BUILD:
            continue
        elif cmd == "find" and any(a in ("-delete", "-exec", "-execdir", "-fprint") for a in args):
            block("find with -delete/-exec is not read-only.")
        elif cmd in ("sed", "awk") and any(a.startswith("-i") for a in args):
            block("in-place edits are not read-only.")
        elif cmd == "xcodebuild" and not any(a in ("-list", "-showBuildSettings", "-version") for a in args):
            block("use `make build` / `make test` instead of raw xcodebuild.")
        elif cmd not in READ_ONLY and cmd != "sed":
            block(f"`{cmd}` is not on the reviewer's read-only list.")


def main():
    try:
        payload = json.load(sys.stdin)
    except ValueError:
        return 0
    if payload.get("tool_name") == "Bash":
        check((payload.get("tool_input") or {}).get("command", ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
