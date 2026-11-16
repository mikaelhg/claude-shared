#!/usr/bin/env python3
"""Score the mechanical rubric items for each run.

Usage, from the repository root: score.py <base directory>

Prints one row per run. R6 and R8 to R11 need reading or running and are
judged by hand; this script only reports the text signals for R1 to R5 and R7,
which the reviewer then confirms.

The privacy check's own output is not printed, only its counts, so this
script's output is safe to keep.
"""

import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
CHECK = HERE.parents[2] / "skills/experiments/tools/privacy-check.py"


def privacy(exp):
    out = subprocess.run(
        [sys.executable, "-I", str(CHECK), str(exp)], capture_output=True, text=True
    ).stdout
    found = sum(1 for line in out.splitlines() if line.startswith("FOUND"))
    review = sum(1 for line in out.splitlines() if line.startswith("REVIEW"))
    return found, review


def has(text, pattern):
    return bool(re.search(pattern, text, re.I | re.M))


def main(base):
    arms = dict(
        line.split() for line in (HERE.parent / "data/assignment.tsv").read_text().splitlines()
    )
    print("run arm files words R1-found review R2 R3 R4 R5 R7 lessons")
    for run, arm in sorted(arms.items()):
        exp = Path(base) / f"run{run}" / "repo" / "experiments"
        files = [p for p in exp.rglob("*") if p.is_file()]
        topics = [p for p in exp.iterdir() if p.is_dir()]
        index = exp / "README.md"
        readme = (topics[0] / "README.md") if topics else None
        text = readme.read_text() if readme and readme.exists() else ""
        index_text = index.read_text() if index.exists() else ""
        found, review = privacy(exp)
        r2 = index.exists() and bool(topics) and topics[0].name in index_text
        r3 = has(text, r"^\|\s*F1\s*\|") and has(text, r"holds for")
        r4 = has(text, r"^#+\s*not (verified|tested)")
        r5 = has(text, r"refuted if") or (has(text, r"hypothes") and has(text, r"refut|falsif"))
        r7 = has(text, r"git[^\n]{0,20}2\.53") and has(text, r"linux") and has(text, r"2026-11-16")
        words = sum(len(p.read_text(errors="replace").split()) for p in files)
        mark = lambda ok: "pass" if ok else "FAIL"
        print(
            run, arm, len(files), words, found, review,
            mark(r2), mark(r3), mark(r4), mark(r5), mark(r7),
            "yes" if (exp / "LESSONS.md").exists() else "no",
        )


if __name__ == "__main__":
    main(sys.argv[1])
