#!/usr/bin/env python3
"""Search experiment records for details that identify the person or machine.

Usage: privacy-check.py [PATH ...]        (default: ./experiments)

Two kinds of result:

  FOUND   a value taken from this machine (account name, hostname, home
          directory, real name, git identity) appears in a file or file name.
          These must be fixed. Exit status 1.
  REVIEW  text that has the shape of something private (an email address, an
          IP or MAC address, a home directory path, a private key block).
          Read each one and decide. These do not change the exit status.

The output quotes the matching lines, so it contains the private values.
Read it in the terminal; never save it in the repository.

Standard library only.
"""

import os
import pwd
import re
import subprocess
import sys
from pathlib import Path

MIN_NEEDLE = 3  # shorter values would match almost everything
SKIP_DIRS = {".git"}


def git_config(key):
    try:
        out = subprocess.run(
            ["git", "config", "--get", key],
            capture_output=True, text=True, timeout=10,
        )
    except (OSError, subprocess.SubprocessError):
        return ""
    return out.stdout.strip()


def machine_values():
    """Return {label: value} for the identifying values of this machine."""
    values = {}
    try:
        entry = pwd.getpwuid(os.getuid())
        values["account name"] = entry.pw_name
        values["real name"] = entry.pw_gecos.split(",")[0]
    except KeyError:
        pass
    values["home directory"] = str(Path.home())
    node = os.uname().nodename
    values["hostname"] = node
    values["short hostname"] = node.split(".")[0]
    values["git user.name"] = git_config("user.name")
    values["git user.email"] = git_config("user.email")

    needles, skipped = {}, []
    for label, value in values.items():
        value = value.strip()
        if not value or value.lower() in {v.lower() for v in needles.values()}:
            continue
        if len(value) < MIN_NEEDLE or value in {"root", "localhost", "/root", "/"}:
            skipped.append(label)
            continue
        needles[label] = value
    return needles, skipped


RESERVED_MAIL = re.compile(
    r"(@|\.)(example\.(com|org|net)|example|invalid|test|localhost)$", re.I
)
DOC_IP = re.compile(r"^(127\.|0\.0\.0\.0$|192\.0\.2\.|198\.51\.100\.|203\.0\.113\.)")

PATTERNS = [
    ("email address", re.compile(r"[\w.+-]+@[\w-]+(?:\.[\w-]+)+"),
     lambda m: not RESERVED_MAIL.search(m)),
    ("IPv4 address", re.compile(r"(?<![\w.])(?:\d{1,3}\.){3}\d{1,3}(?![\w.])"),
     lambda m: not DOC_IP.match(m)),
    ("MAC address", re.compile(r"(?<![0-9A-Fa-f:])(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}(?![0-9A-Fa-f:])"),
     lambda m: True),
    ("home directory path", re.compile(r"/(?:home|Users)/[^/\s<>$\"']+"),
     lambda m: True),
    ("private key block", re.compile(r"BEGIN [A-Z ]*PRIVATE KEY"),
     lambda m: True),
]


def files_under(paths):
    for root in paths:
        root = Path(root)
        if root.is_file():
            yield root
            continue
        for dirpath, dirnames, filenames in os.walk(root):
            dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
            for name in sorted(filenames):
                yield Path(dirpath) / name


def main(argv):
    paths = argv[1:] or ["experiments"]
    missing = [p for p in paths if not Path(p).exists()]
    if missing:
        print(f"privacy-check: no such path: {', '.join(missing)}", file=sys.stderr)
        return 2

    needles, skipped = machine_values()
    found, review, scanned = [], [], 0

    for path in files_under(paths):
        scanned += 1
        shown = str(path)
        for label, value in needles.items():
            if value.lower() in shown.lower():
                found.append((shown, 0, label, "(in the file name)"))
        try:
            text = path.read_bytes().decode("utf-8", errors="replace")
        except OSError as err:
            print(f"privacy-check: cannot read {shown}: {err}", file=sys.stderr)
            continue
        for number, line in enumerate(text.splitlines(), 1):
            lowered = line.lower()
            for label, value in needles.items():
                if value.lower() in lowered:
                    found.append((shown, number, label, line.strip()[:200]))
            for label, pattern, keep in PATTERNS:
                for match in pattern.findall(line):
                    if keep(match):
                        review.append((shown, number, label, line.strip()[:200]))
                        break

    for title, rows in (("FOUND", found), ("REVIEW", review)):
        for shown, number, label, line in rows:
            where = f"{shown}:{number}" if number else shown
            print(f"{title}  {where}  [{label}]  {line}")

    print(
        f"\n{scanned} files scanned; {len(found)} found, {len(review)} to review. "
        f"Searched for: {', '.join(needles) or 'nothing'}."
    )
    if skipped:
        print(f"Not searched, value too short or generic: {', '.join(skipped)}.")
    if found:
        print("Fix every FOUND line, then run again.")
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
