# RELEASE_TO_MAIN.md

How the `main` (release) branch is built from `claude-dev` (development).

## Principle

`main` contains ONLY released project files. It MUST NOT contain Claude/dev
artifacts (`CLAUDE.md`, `claude-dev/`, `.ai-reviews/`, `background/`). `main` and
`claude-dev` have independent histories. **Never `git merge claude-dev` into
`main`** — that would drag the Claude files across. Release is a curated copy.

## What ships on main (release allowlist)

```
README.md            (ships as-is — no dev references, so no trim needed)
LICENSE
.gitignore
Invoke-AsaReview.ps1
Update-AsaEolData.ps1
src/                 (all)
data/                (all)
examples/            (sample output from the synthesized fixture)
```

What is excluded from main: `CLAUDE.md`, `claude-dev/`, `.ai-reviews/`,
`background/`, and **`tests/`** (the Pester suite + fixtures are dev-only; an end
user running a review does not need them). The tests live on `claude-dev` and are
verified there before each release — see the procedure below.

## Procedure (rebuild main from current claude-dev HEAD)

```sh
git checkout claude-dev            # ensure HEAD is the release-ready commit
pwsh -File tests/Invoke-Tests.ps1  # verify GREEN on claude-dev BEFORE cutting main
                                   #   (main no longer ships tests/, so this is the
                                   #    only place to run them; src/ + data/ are
                                   #    byte-identical on the release, so it is equivalent)
git branch -D main 2>/dev/null     # drop local main
git checkout --orphan main         # new history; index = full claude-dev tree
git rm -r --cached --quiet CLAUDE.md claude-dev .ai-reviews background tests
# README ships as-is (no dev references to trim), so just commit the remaining tree:
git commit -m "Release: cisco-asa-review <version>"
# verify no claude/dev files:
git ls-files | grep -E '^(CLAUDE.md|claude-dev/|.ai-reviews/|background/|tests/)' && echo LEAK || echo clean
git push -f origin main
git tag -f -a <version> -m "<notes>"; git push -f origin <version>
git checkout -f claude-dev         # restore the dev working tree (see caveat below)
```

**The repo is now PUBLIC (made public 2026-06-25), so this re-evaluation is due.**
The orphan-rebuild model force-pushes `main` (and moves tags) on every release,
which rewrites the history of the public default branch — disruptive to anyone who
has cloned or forked it. Decide before the next release:

- Keep `main` as a clean release branch but build it with normal, non-force commits
  (a curated copy committed on top of the existing `main` history, not an orphan
  rebuild), so history is append-only.
- Or drop the two-branch split: now that both branches are public, the "hide dev
  files from `main`" benefit is cosmetic, so a single linear history with release
  tags may be simpler and force-push-free.

Until that decision is made, treat a force-push of `main` as a known cost, not a
routine step. (It was acceptable while the repo was private and single-maintainer.)

### Caveat: the final `checkout claude-dev` needs `-f`

`git rm -r --cached CLAUDE.md claude-dev .ai-reviews background tests` only
*un-tracks* those paths on `main` — the files stay on disk as **untracked**. So a plain
`git checkout claude-dev` aborts with "untracked working tree files would be
overwritten" (claude-dev tracks the very files sitting there untracked). Use
`git checkout -f claude-dev`. This is safe **provided the release-ready commit was
committed and pushed on `claude-dev` first** (the procedure's first line): the
on-disk leftovers are identical to claude-dev's tracked versions, so forcing the
switch overwrites them with the same content and loses nothing. Confirm afterward:

```sh
git branch --show-current          # claude-dev
git status --short                 # empty (clean)
git log --oneline -1               # the release-ready dev commit
```

If you are unsure whether everything was committed, check `git status` on `main`
*before* switching: it should show only `??` (untracked) Claude paths and no
modified tracked files. Anything tracked-and-modified means uncommitted work —
commit it on `claude-dev` (after switching) rather than forcing past it.

## Notes

- Source-file comment headers reference design docs by name (e.g. ARCHITECTURE
  section N). Those are provenance breadcrumbs pointing at the `claude-dev`
  branch; they are comments, not files, so they are fine to ship on `main`.
- `.gitignore` retains the `claude-dev/*` ignore lines on `main`; they are
  harmless there (the paths do not exist) and required on `claude-dev`.
