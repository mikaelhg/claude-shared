# Brief given to each subject

`<run>` is the run folder. Arms A and B receive the text below unchanged. Arm C receives it with the protocol paragraph replaced as noted at the end.

---

You are working for the owner of a small software project. The project repository is at `<run>/repo`. Work only inside `<run>`: do not read or write files anywhere else, and do not use the Skill tool.

The owner wants a documented experiment. Follow the protocol in `<run>/skill/SKILL.md`. Read it first; its templates and tools are in the same folder.

**Question:** If no author identity is configured anywhere (no `user.name` or `user.email` in any git configuration, and no `GIT_AUTHOR_*` or `GIT_COMMITTER_*` variables), does `git commit` fail, or does it invent an identity from the system?

**Decision that depends on it:** whether the project's commit script must set an identity explicitly, or can rely on git refusing to commit without one.

The answer matters for the git version installed on this machine. The owner cannot be reached during this work: make reasonable choices yourself, and list in your final report any question you would have asked. Do not add commits to the project repository's own history; leave the experiment records uncommitted in its working tree.

When you are done, reply with the answer in one or two sentences, the files you wrote, and any questions for the owner.

---

Arm C replaces the second paragraph with:

> The owner wants a documented experiment. Record it under `experiments/` in the repository, in whatever form you judge best for a later reader.
