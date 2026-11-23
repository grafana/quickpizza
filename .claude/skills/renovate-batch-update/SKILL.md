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

**Sequential mode (when the user wants to test and merge PRs one by one).** If the user
says they will approve and merge the Renovate PRs themselves, skip the batch branches.
Test one PR at a time, lowest-risk first, and report pass/fail with what you actually
verified. After each merge, `git fetch` and re-assess every remaining PR from scratch
(see "Re-check after every merge" in Step 2) before testing the next one. Do not close,
rebase or comment on the PRs yourself.

**Don't change `renovate.json` to fix overlapping PRs.** Its schedule, `rebaseWhen` and
per-manager grouping are deliberate (PR #560, aligned with other k6 repos). Security
PRs come from `vulnerabilityAlerts` (one PR per package, own schedule), so overlap
between them is expected. Handle it in testing and merge order, not in the config.

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
validate the batch. This skill's local testing (`make build` + `make test-go` + k6)
can't exercise workflow-level behavior at all; only that PR's own CI run can.

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

Renovate branches are prefixed `renovate/`, and security branches are
`renovate/security-*`, so matching `head:renovate/` covers both. From each PR's labels,
note: `update-major` / `update-minor` / `update-patch`, and any `severity:*` /
`automerge-security-update`. A PR with no update-type label may be lock file
maintenance (see Step 4).

Don't request `mergeable` from `gh pr list` — GitHub computes it lazily and it's
`UNKNOWN` for most PRs right after a fetch. Step 2's actual `git merge` is the only
reliable mergeability check.

**Dedupe overlapping PRs before merging, not by discovering conflicts.**
`renovate.json` groups npm/go/docker updates into one PR (e.g.
`renovate/npm-dependencies`), but Renovate also opens narrower individual `security-*`
PRs for the same packages. If a grouped PR and a security PR touch the same package
(compare titles), merge the **grouped** one and skip the narrower one — it's
superseded, and merging both guarantees a conflict.

Related modules move together. Bumping one `go.opentelemetry.io/otel*` module in the
root `go.mod` pulls the others to the same version, and `k6/extensions/quickpizzaext`
resolves its versions through the root via `replace => ../../..`. So several
single-package security PRs often collapse into the first one that merges.

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

**Re-check after every merge.** Once a PR lands on `main`, the PRs still open can be
redundant, stale or conflicting. Before testing the next one:

- Test the real merge result, not the PR's own branch. Renovate rebases with a delay
  (`rebaseWhen: behind-base-branch`), so a branch can be behind `main`. Merge it onto a
  scratch branch off current `main` and test that.
- Check redundancy with a two-dot diff of the files it changes against `main`
  (`git diff origin/main <branch> -- <file>`). The PR's own diff is against its old
  merge-base and still shows changes that `main` already has. If the files are
  identical, or the trial merge stages nothing, the PR is redundant: don't merge it,
  and let Renovate close it. Closing it by hand can make Renovate ignore that version.
- A conflict between two PRs that bump the same module family usually means one covers
  the other. Keep the PR that includes the other's changes.

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

Whatever the ecosystem, check whether the bumped package is actually used: which
packages of it our code imports (`go mod why`, grep the imports), and whether it's
instantiated at runtime or only compiled in as a transitive dependency. A major bump
of a package we never call is much lower risk than the version number suggests. A
bump of the code we do exercise (for example the OpenTelemetry SDK) is higher risk
than its patch-level number suggests.

Build a table — PR #, title, ecosystem, update type, severity, risk verdict — and keep
it; it becomes the batch PR body.

## Step 4: Build + test the batch

Applies to the **code/dependency batch only**. The Actions batch has no local
build/test step — skip straight to Step 6 for it.

**Test the logic the dependency affects, not the whole suite.** Read each PR's CI
first (`gh pr checks <n>`). The repo's CI already runs the full k6 suites and browser
tests on every PR, so repeating them locally adds little. Use local time for what CI
can't show: decide, from the package and from how our code uses it (Step 3), which
behavior could break, then exercise that behavior and look for evidence that it works.
You choose the commands. Some examples of the reasoning, not a checklist:

- A library that is only configured at runtime (OpenTelemetry is initialized only when
  `QUICKPIZZA_OTLP_ENDPOINT` is set) is not exercised by build, unit tests and a smoke
  run. Run the app with it enabled against a real backend and confirm the telemetry
  arrives.
- Code that is a separate Go module (`k6/extensions/*`) needs its own build and a run
  of the example that loads it, since `make build` doesn't compile it.
- Frontend tooling bumps need the frontend built, the embedded assets served, and the
  browser-test CI jobs read.
- A package we only compile in and never call needs little beyond the build.

Compare against a baseline on `main` before calling something a regression, because
this repo has failures that predate the PR (for example one check in
`k6/extensions/01.quickpizzaext.js` fails 0 of 25 on `main`). State what you verified
and what you did not. A pass means the checks you ran passed, not that the dependency
was exhaustively tested.

Also run a baseline sanity check, as below.

```bash
make build
```

Use `make build`, not `npm run build` / `go build` directly — the frontend build needs
`PUBLIC_BACKEND_ENDPOINT`/`PUBLIC_BACKEND_WS_ENDPOINT` exported first, which only the
Makefile target does.

If `npm install` modified `pkg/web/package-lock.json` beyond what the merged PRs
already changed, discard that diff (`git checkout -- pkg/web/package-lock.json`) — it's
typically platform-specific optional-dependency drift, not a real change, and it must
not leak into the batch PR. `make build` re-creates this drift every time, and it
blocks `git checkout` to another branch, so discard it after every build.

If the build fails, drop the most recently merged high-risk (major) update via `git
revert -m 1 <merge-commit>` and retry, up to twice. If it still fails, stop and report
the failure without opening a PR — don't keep reverting blindly.

If the build succeeds, run the Go unit tests next — they're fast and catch regressions
in pure logic (e.g. `pkg/password`'s bcrypt round-trip) that a black-box k6 test might
not exercise:

```bash
make test-go
```

Apply the same drop-and-retry logic on failure as the build step above.

If that succeeds, start the app and run a smoke test against it, plus whatever
impacted-logic checks you chose above:

```bash
./bin/quickpizza > /tmp/qp_batch.log 2>&1 &
QP_PID=$!
sleep 2
./k6/run-tests.sh -u http://localhost:3333 -t "k6/foundations/01.basic.js"
K6_EXIT=$?
kill $QP_PID
```

A single script is enough when the PR's CI is green, because CI runs the full suites.
Only run `k6/foundations/*.js` (17 files, long enough to exceed a 180s foreground
timeout and move to background) when you have no CI result to rely on, and avoid the
full `k6/**/*.js` tree: some subtrees need the custom xk6 extension binary or extra
credentials. If a long run moves to the background, treat its exit code as the
pass/fail signal. Don't leave the app running when you finish, and confirm port 3333
is free.

If `K6_EXIT` is non-zero, apply the same drop-and-retry logic as a build failure, and
check `/tmp/qp_batch.log` for server-side errors, not just the exit code.

**Lock file maintenance PRs** (no update-type label, only `package-lock.json`, title
"lock file maintenance") refresh transitive npm packages, mostly dev tooling. Build
the frontend, compare build warnings against `main`, confirm the embedded frontend and
its assets are served, and read the browser-test CI jobs. Check for major jumps among
the transitive packages and for a pending `renovate/stability-days` check, which
means Renovate is holding the PR until the packages are old enough.

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
- `make test-go`: <pass/fail>
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
next run. Closing one by hand can make Renovate ignore that version, so leave the
redundant ones for it to close.

When you report a PR as ready to merge, mention the merge gates so they aren't mistaken
for failures. The `main` ruleset requires one approving review with approval of the
last push (any new push, including a Renovate rebase, dismisses it), the TruffleHog and
zizmor workflows, and an org "Assistant approvals" workflow whose status shows
"Expected" until it runs. `renovate/stability-days` stays pending until packages reach
the minimum release age.

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
