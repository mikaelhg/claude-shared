#!/usr/bin/env bash
# Create one isolated run folder per subject.
# Usage, from the repository root: setup.sh <base directory>
#
# Each run folder gets a fresh project repository. Arms A and B also get a
# copy of the skill: A with the un-tightened SKILL.md, B with the tightened
# one. Templates and tools are identical in both commits. Arm C gets no skill.
set -euo pipefail

BASE=$1
HERE=experiments/skill-tightening-ab
A_COMMIT=7ad0fde
B_COMMIT=78c97bd

git --version
mkdir -p "$BASE"

while read -r run arm; do
  dir="$BASE/run$run"
  mkdir -p "$dir/repo"
  printf '# Scratch project\n\nA small project used as the subject of an experiment.\n' > "$dir/repo/README.md"
  (
    cd "$dir/repo"
    export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
    git init -q -b main
    git add README.md
    git -c user.name='Project Owner' -c user.email='owner@example.invalid' commit -q -m 'Initial commit'
  )
  case "$arm" in
    A) commit=$A_COMMIT ;;
    B) commit=$B_COMMIT ;;
    C) continue ;;
  esac
  mkdir -p "$dir/skill"
  git archive "$B_COMMIT" skills/experiments/templates skills/experiments/tools \
    | tar -x --strip-components=2 -C "$dir/skill"
  git show "$commit:skills/experiments/SKILL.md" > "$dir/skill/SKILL.md"
done < "$HERE/data/assignment.tsv"

wc -l "$BASE"/run*/skill/SKILL.md
