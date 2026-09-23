---
name: renovate-batch-update
description: Consolidate all open Renovate PRs on quickpizza into tested, reviewable PRs. Splits GitHub Actions bumps into their own PR (validated by their own CI run) from code/library bumps (validated by local build + k6), merges as many as will merge cleanly into each batch branch, risk-assesses the survivors, and opens draft PRs summarizing what's in and what got dropped.
---

# /renovate-batch-update — Consolidated Dependency Update

Turns the weekly pile of individual Renovate PRs on `grafana/quickpizza` into tested
PRs, instead of reviewing/merging each one by hand.

**Boundary:** this skill opens **draft PRs to `main`**. It never merges to `main`
itself — that's a shared-branch action and stays a human call.

**Produces two separate PRs, not one:** a code/dependency batch (Go modules, npm
packages, Docker base image tags, security patches) and, only if any exist, a GitHub
Actions batch. This is a hard split, not optional risk-tiering — see "Why GitHub
Actions bumps get their own PR" below.

## Step 0: Sanity check

- Confirm the working tree is clean (`git status`). If not, stop and tell the user —
  don't stash or discard their work.
- Confirm the current branch, then `git fetch origin --prune`.
- Check whether port 3333 is already in use (`lsof -i :3333`). Quickpizza's port is
  hardcoded in `cmd/main.go` with no override, and a long-running local Docker
  container (`docker ps --filter publish=3333`) commonly holds it. If so, **ask the
  user** before touching it. If they agree, `docker stop <name>` before Step 4 and
  `docker start <name>` again once k6 finishes, pass or fail.

## Why GitHub Actions bumps get their own PR

A GitHub Actions version bump changes the CI workflow itself — the thing meant to
validate the batch. This skill's local testing (`make build` + k6) can't exercise
workflow-level behavior at all; only that PR's own CI run can.

1. **Never mix Actions bumps into the code/dependency batch.** A CI-breaking Actions
   change and a real code regression both just show up as "CI failed" if they're in
   the same batch — keep Actions bumps in a PR that contains only Actions bumps, so a
   failure there is unambiguous.
2. **The acceptance bar for the Actions batch is its own CI run, not a local check.**
   Push it and read its checks. A first-push failure is expected and is the batch
   doing its job — report it plainly in the PR body rather than fixing it silently.
   The fix itself (e.g. pinning a version in `ci.yaml`) is a `main`-level CI change,
   out of scope for a dependency-bump PR.

This holds regardless of which Actions bump happens to break something — the reason is
structural (only a workflow's own run can validate a change to that workflow), not tied
to any specific action.

## Step 1: Collect open Renovate PRs

```bash
gh pr list --state open --json number,title,headRefName,labels \
  --search "head:renovate/ OR head:security-" --limit 100
```

Renovate branches are prefixed `renovate/`; security branches use the
`additionalBranchPrefix: "security-"` from `renovate.json`, so also match
`security-*` heads. From each PR's labels, note: `update-major` / `update-minor` /
`update-patch`, and any `severity:*` / `automerge-security-update`.

Don't request `mergeable` from `gh pr list` — GitHub computes it lazily and it's
`UNKNOWN` for most PRs right after a fetch. Step 2's actual `git merge` is the only
reliable mergeability check.

**Dedupe overlapping PRs before merging, not by discovering conflicts.**
`renovate.json` groups npm/go/docker updates into one PR (e.g.
`renovate/npm-dependencies`), but Renovate also opens narrower individual `security-*`
PRs for the same packages. If a grouped PR and a security PR touch the same package
(compare titles), merge the **grouped** one and skip the narrower one — it's
superseded, and merging both guarantees a conflict.

**Exclude the observability-stack container images group entirely.** These are the
Grafana observability stack images (Alloy, LGTM, etc.) upgraded manually while deciding
whether to adopt new stack features — batching them defeats that review. Read
`renovate.json`'s `packageRules`, find the rule matching
`matchManagers: ["docker-compose", "terraform"]`, and take its `groupName`. Exclude any
PR whose title contains that groupName, including its `(major)` variant. Don't merge
these, risk-assess them, or mention them in the batch PR body — they're out of scope
for this skill, not a drop. Tell the user how many were left untouched by design.

**Split off GitHub Actions bumps into their own batch — filter by the
`github-actions` label** (applied via `presets/github-actions` in `renovate.json`'s
`extends`), not by branch name or title. Steps 2-6 below run **twice**: once for the
code/dependency PRs, once for the Actions PRs, each on its own branch and its own PR.
Within the Actions set, dedupe the same way as above — e.g. a digest-only pin and a
major-version bump for the same action will conflict; keep the lower-risk one.

## Step 2: Build the batch branch(es)

```bash
# Code/dependency batch:
git checkout -b renovate-batch/$(date +%Y-%m-%d) origin/main
# GitHub Actions batch, if any Actions PRs exist:
git checkout -b renovate-actions-batch/$(date +%Y-%m-%d) origin/main
```

Merge order within the code/dependency batch: lowest-risk first (security-patch,
security-minor), then grouped patch/minor PRs, then majors last (majors are the first
candidates to drop if later steps fail).

```bash
git merge --no-ff origin/<headRefName> -m "merge: <PR title> (#<number>)"
```

On a clean merge, continue. On a conflict, `git merge --abort`, record `<PR> — dropped:
merge conflict`, and continue to the next PR. Don't attempt manual conflict
resolution.

**Why conflicts are common here:** this repo vendors Go dependencies (`vendor/`), so
any single-module bump touches `go.mod`, `go.sum`, and often unrelated files under
`vendor/` (shared semconv/version directories get rewritten wholesale). Once one
otel/grpc/x-net-family bump is merged, every other PR touching a related module will
conflict with it, even though the version bumps are logically compatible. Treat these
as expected noise in the batch PR summary, not as unsafe changes that got rejected.

## Step 3: Risk-assess only what survived Step 2

Risk-assessing before merging wastes effort on PRs that just get dropped as conflicts.
Assess only the PRs that are actually in each batch branch.

For the **code/dependency batch**, route by ecosystem:
- **Go/npm code libraries**: `grafana-engineering:dependency-bump-context`
- **Docker/container image tags** (e.g. the Dockerfile base image group):
  `grafana-engineering:analyze-image-dep-bump-pr`

For the **GitHub Actions batch**, no skill covers this — read each action's actual
release notes between the current and target version
(`gh release view <version> -R <owner>/<repo>`), looking specifically for **breaking
changes to the action's runtime behavior**, not just its own dependency bumps. Version
number alone doesn't reveal this kind of change, and skipping the check is how a
CI-breaking bump gets through unnoticed.

Build a table — PR #, title, ecosystem, update type, severity, risk verdict — and keep
it; it becomes the batch PR body.

## Step 4: Build + test the batch

Applies to the **code/dependency batch only**. The Actions batch has no local
build/test step — skip straight to Step 6 for it.

```bash
make build
```

Use `make build`, not `npm run build` / `go build` directly — the frontend build needs
`PUBLIC_BACKEND_ENDPOINT`/`PUBLIC_BACKEND_WS_ENDPOINT` exported first, which only the
Makefile target does.

If `npm install` modified `pkg/web/package-lock.json` beyond what the merged PRs
already changed, discard that diff (`git checkout -- pkg/web/package-lock.json`) — it's
typically platform-specific optional-dependency drift, not a real change, and it must
not leak into the batch PR.

If the build fails, drop the most recently merged high-risk (major) update via `git
revert -m 1 <merge-commit>` and retry, up to twice. If it still fails, stop and report
the failure without opening a PR — don't keep reverting blindly.

If the build succeeds, run the app and the k6 suite against it:

```bash
./bin/quickpizza > /tmp/qp_batch.log 2>&1 &
QP_PID=$!
sleep 2
./k6/run-tests.sh -u http://localhost:3333 -t "k6/foundations/*.js"
K6_EXIT=$?
kill $QP_PID
```

Default to `k6/foundations/*.js`, not the full `k6/**/*.js` tree — some subtrees
(browser, extension examples) need the custom xk6 quickpizza extension binary or extra
credentials that aren't guaranteed to be available locally.

This can exceed a 180s foreground command timeout and move to background — that's
expected for the full 17-file suite. Treat the background task's exit code as the
pass/fail signal; the captured output may only contain the tail once it's moved.

If `K6_EXIT` is non-zero, apply the same drop-and-retry logic as a build failure, and
check `/tmp/qp_batch.log` for server-side errors, not just the exit code.

## Step 5: Track drops

Keep a running list of every PR dropped and why (merge conflict / build failure / test
failure). Group conflict-drops by root cause (e.g. "conflicted with the otel bumps
already in the batch") rather than listing them as unexplained failures.

## Step 6: Push and open the draft PR(s)

For the code/dependency batch, only after Step 4 succeeds (or partially succeeds with
drops recorded):

```bash
git push -u origin renovate-batch/$(date +%Y-%m-%d)
gh pr create --draft --title "chore(deps): batch renovate update $(date +%Y-%m-%d)" --body "$(cat <<'EOF'
## Included
<table from Step 3, filtered to what's actually merged>

## Dropped
<list from Step 5, grouped by root cause — omit if nothing was dropped>

## Testing
- `make build`: <pass/fail>
- `./k6/run-tests.sh`: <pass/fail, note any skipped/dropped-due-to-failure items>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

For the Actions batch, push and open it unconditionally — there's no local gate, its
own CI run is the test:

```bash
git push -u origin renovate-actions-batch/$(date +%Y-%m-%d)
gh pr create --draft --title "chore(deps): batch GitHub Actions update $(date +%Y-%m-%d)" --body "$(cat <<'EOF'
Separate from the code/dependency batch — see "Why GitHub Actions bumps get their own PR"
in the skill. This PR's own CI run is the test.

## Included
<table from Step 3>

## Dropped
<list from Step 5, if any>

## Risk notes
<anything found reading release notes in Step 3 — call out a breaking runtime/behavior
change explicitly, don't bury it in a version number>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

If the Actions batch's CI comes back red, don't silently drop the offending PR and
re-push. Edit the PR body to report which check failed and why, and let the human
decide whether to drop that PR or fix the CI config alongside it — the latter is a
`main`-level change, out of scope for this skill to make unilaterally.

Tell the user both PRs are **drafts** and summarize what's in/out for each. Don't mark
either ready for review or merge them.

## Step 7: Leave the original PRs alone

Don't close or comment on the individual Renovate PRs. Once a batch PR merges, Renovate
detects the deps are already at target versions on `main` and closes its own PRs on its
next run.

## Notes

- If Step 1 finds zero open Renovate PRs, say so and stop.
- If only one Renovate PR is open, still run the full process rather than
  special-casing "just merge it" — the value is the tested draft PR, not the batching.
- If either batch ends up empty after Step 1's filtering, skip that PR entirely.
- Safe to re-run: each run creates a dated branch. Re-running after a batch PR merges
  should clear out many conflict-drops automatically, since the conflict was against
  content that's now on `main`.

## Future improvement (not yet implemented)

The real fix for the vendor/lockfile conflict problem in Step 2 is to stop merging each
Renovate branch's generated diff, and instead collect the target version for each
accepted PR, apply them directly on the batch branch (`go get <module>@<version>` for
Go, edit `package.json` for npm), then run `go mod tidy && go mod vendor` / `npm
install` once for the whole batch. That would avoid nearly all vendor-churn conflicts,
at the cost of a more complex Step 2 — worth building once this skill is used
regularly enough to justify it.
