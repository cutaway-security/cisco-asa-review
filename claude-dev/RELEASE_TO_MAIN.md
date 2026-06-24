# RELEASE_TO_MAIN.md

How the `main` (release) branch is built from `claude-dev` (development).

## Principle

`main` contains ONLY released project files. It MUST NOT contain Claude/dev
artifacts (`CLAUDE.md`, `claude-dev/`, `.ai-reviews/`, `background/`). `main` and
`claude-dev` have independent histories. **Never `git merge claude-dev` into
`main`** — that would drag the Claude files across. Release is a curated copy.

## What ships on main (release allowlist)

```
README.md            (release variant: no claude-dev/ companion links)
LICENSE
.gitignore
Invoke-AsaReview.ps1
src/                 (all)
data/                (all)
tests/               (all; tests/fixtures/real/ stays gitignored)
```

What is excluded from main: `CLAUDE.md`, `claude-dev/`, `.ai-reviews/`,
`background/`.

## Procedure (rebuild main from current claude-dev HEAD)

```sh
git checkout claude-dev            # ensure HEAD is the release-ready commit
git branch -D main 2>/dev/null     # drop local main
git checkout --orphan main         # new history; index = full claude-dev tree
git rm -r --cached --quiet CLAUDE.md claude-dev .ai-reviews background
# trim README for release (drop the claude-dev companion-doc links), then:
git add README.md
git commit -m "Release: cisco-asa-review <version>"
# verify no claude files:
git ls-files | grep -E '^(CLAUDE.md|claude-dev/|.ai-reviews/|background/)' && echo LEAK || echo clean
pwsh -File tests/Invoke-Tests.ps1  # expect green on the release tree
git push -f origin main
git tag -f -a <version> -m "<notes>"; git push -f origin <version>
git checkout claude-dev            # restore the dev working tree
```

Force-push of `main`/tags is acceptable while the repo is private and
single-maintainer. Re-evaluate once there are collaborators or the repo is public.

## Notes

- Source-file comment headers reference design docs by name (e.g. ARCHITECTURE
  section N). Those are provenance breadcrumbs pointing at the `claude-dev`
  branch; they are comments, not files, so they are fine to ship on `main`.
- `.gitignore` retains the `claude-dev/*` ignore lines on `main`; they are
  harmless there (the paths do not exist) and required on `claude-dev`.
