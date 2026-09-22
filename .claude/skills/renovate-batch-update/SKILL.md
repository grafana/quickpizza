---
name: renovate-batch-update
description: Consolidate all open Renovate PRs on quickpizza into tested, reviewable PRs. Splits GitHub Actions bumps into their own PR (validated by their own CI run) from code/library bumps (validated by local build + k6), merges as many as will merge cleanly into each batch branch, risk-assesses the survivors, and opens draft PRs summarizing what's in and what got dropped.
allowed-tools: Bash, Read, Grep, Glob
---

# /renovate-batch-update — Consolidated Dependency Update

Turns the weekly pile of individual Renovate PRs on `grafana/quickpizza` into tested
PRs, instead of reviewing/merging each one by hand.

**Boundary:** this skill opens **draft PRs to `main`**. It never merges to `main` itself —
that's a shared-branch action and stays a human call.

**This produces two separate PRs, not one:** a code/dependency batch (Go modules, npm
packages, Docker base image tags, security patches) and, only if any exist, a GitHub
Actions batch. See "Why GitHub Actions bumps get their own PR" below — this isn't
optional risk-tiering, it's a hard split.

**Known limitation (from the 2026-09-22 dry run, PR #544):** with 29 open Renovate PRs,
only 13 merged cleanly — the other 18 were dropped purely on `git merge` conflicts in
`vendor/`, `go.sum`, and `pkg/web/package-lock.json`, not real incompatibilities. See
Step 2 for the mitigations this taught, and "Future improvement" at the bottom for the
real fix (bump via `go get`/`npm install` instead of merging generated diffs).

**Correction from the same run:** PR #544 included PR #487 ("update container images"),
which it should never have touched — the observability stack images (Alloy, LGTM, etc.)
are upgraded manually as a deliberate step when deciding whether to adopt new stack
features, not batched. Step 1 now excludes this group entirely.

**Second correction, same run:** PR #544 also included four GitHub Actions bumps
(`actions/setup-go`, `actions/setup-node`, `actions/github-script`, `actions/checkout`
digest). One of them — `actions/setup-go` v5→v7 — broke the PR's own `runner-job` CI
check: `setup-go` v6.0.0 force-sets `GOTOOLCHAIN=local`, which stops `go` from
auto-downloading a toolchain newer than what's pre-installed on the runner, and this
repo's CI installs `goimports@latest` without pinning a Go version. Confirmed by testing
an unrelated throwaway branch off `main` (no batch content) side-by-side: same workflow
file *before* the setup-go bump ran fine (auto-downloaded the needed toolchain); the
batch branch *with* the bump failed at that exact step. Local `make build` + k6 can't
catch this class of failure — it's a change to the CI workflow's own behavior, only
observable by that workflow actually running. See "Why GitHub Actions bumps get their
own PR" below.

## Step 0: Sanity check

- Confirm working tree is clean (`git status`). If not, stop and tell the user — do not
  stash or discard their work silently.
- Confirm current branch, then `git fetch origin --prune`.
- Check if port 3333 is already in use (`lsof -i :3333`) — quickpizza's port is hardcoded
  in `cmd/main.go` with no override, and it's common to have a long-running local Docker
  container (`docker ps --filter publish=3333`) bound to it already. If so, **ask the user**
  before touching it — don't kill an unrelated process. If they agree, `docker stop <name>`
  before Step 4 and `docker start <name>` again once k6 finishes, whether it passed or not.

## Why GitHub Actions bumps get their own PR

A GitHub Actions version bump changes the CI workflow itself — the thing that's
supposed to validate the batch. This skill's own testing (`make build` + k6) runs
locally and has no way to exercise workflow-level behavior; the *only* real test for
an Actions bump is that PR's own CI run. Two consequences:

1. **Never mix Actions bumps into the code/dependency batch.** If a bad Actions bump
   breaks CI, it either masks a real code regression in the same batch (both show up as
   "CI failed," can't tell which) or gets masked by one. Keep them in a PR that contains
   *only* Actions bumps, so a CI failure there is unambiguous.
2. **The acceptance bar for the Actions batch is its own CI run passing, not a local
   check.** Push it and look at its checks — don't try to predict the outcome locally.
   It's fine, expected even, for that first push to fail; that failure is the actual
   signal this batch exists to surface. Report it plainly in the PR body rather than
   fixing it silently — the fix (e.g. pinning `go-version` in `ci.yaml`) is a `main`-level
   CI hardening change, out of scope for a dependency-bump PR.

## Step 1: Collect open Renovate PRs

```bash
gh pr list --state open --json number,title,headRefName,labels \
  --search "head:renovate/ OR head:security-" --limit 100
```

Renovate branches are prefixed `renovate/`; security branches use the
`additionalBranchPrefix: "security-"` from `renovate.json`, so also match
`security-*` heads. For each PR, extract from labels: `update-major` /
`update-minor` / `update-patch`, and any `severity:*` / `automerge-security-update`.

Don't bother requesting `mergeable` from `gh pr list` — GitHub computes it lazily and it
comes back `UNKNOWN` for most PRs right after a fetch. Step 2's actual `git merge` is the
only reliable mergeability check; don't gate anything on the API field.

**Dedupe overlapping PRs before merging, not by discovering conflicts:** `renovate.json`
groups npm/go/docker updates into one PR (e.g. `renovate/npm-dependencies`), but Renovate
also opens narrower individual `security-*` PRs for the same packages. If a grouped PR and
a security PR touch the same package (check titles — e.g. `npm-dependencies` and
`security-pkgweb-@sveltejskit` both bump `@sveltejs/kit`), merge the **grouped** one first
and skip the narrower one — it's superseded, and merging both just guarantees a conflict.
This was the single biggest cause of drops in the first run.

**Exclude the observability-stack container images group entirely — never merge it as
part of a batch.** These are the Grafana observability stack images (Alloy, LGTM, etc.)
used in the demo/workshop compose and Terraform setups, and they get upgraded manually
while deciding whether to adopt new stack features — a batch PR silently including them
defeats that review. Identify this group from `renovate.json` itself rather than
hardcoding a name, since the groupName could change:

```bash
# Find the packageRule whose matchManagers is exactly docker-compose+terraform, and
# read its groupName (currently "container images" per renovate.json).
```

Read `renovate.json`'s `packageRules`, find the rule matching
`matchManagers: ["docker-compose", "terraform"]`, and take its `groupName`. Exclude any
PR from Step 1 whose title contains that groupName — this covers both the regular and
`(major)` variants Renovate splits out (e.g. PR #487 "update container images" and PR
#500 "update container images (major)"). Don't merge these, don't risk-assess them,
don't mention them in the batch PR body at all — they're out of scope for this skill,
not a drop. Note in your summary to the user that N container-image PRs were left
untouched by design, so it's clear this wasn't an oversight.

**Split off GitHub Actions bumps into their own batch — filter by the `github-actions`
label**, which Renovate already applies to these PRs (from `presets/github-actions` in
`renovate.json`'s `extends`), rather than matching branch names or titles. Everything
from here on (Steps 2-6) runs **twice**: once for the code/dependency PRs, once for the
Actions PRs, each on its own branch, each as its own PR. See "Why GitHub Actions bumps
get their own PR" above for why this isn't optional. Within the Actions set, dedupe the
same way as Step 1's grouped/security overlap check — e.g. a digest-only pin and a
major-version bump for the *same* action (like `actions/checkout`) will conflict with
each other; keep the lower-risk one and drop the other as superseded, don't merge both.

## Step 2: Build the batch branch(es)

```bash
# Code/dependency batch:
git checkout -b renovate-batch/$(date +%Y-%m-%d) origin/main
# GitHub Actions batch, if any Actions PRs exist (separate branch, separate PR later):
git checkout -b renovate-actions-batch/$(date +%Y-%m-%d) origin/main
```

Merge order within the code/dependency batch: lowest-risk first (security-patch,
security-minor by severity LOW), then grouped patch/minor PRs, then major-version bumps
last (majors are the first candidates to drop if later steps fail). GitHub Actions PRs
never enter this branch — see the split-off step above.

```bash
git merge --no-ff origin/<headRefName> -m "merge: <PR title> (#<number>)"
```

- On a clean merge: continue.
- On a conflict: `git merge --abort`, record `<PR> — dropped: merge conflict`, continue
  to the next one. Do not attempt manual conflict resolution.

**Why conflicts are so common here, and what it means:** this repo vendors Go
dependencies (`vendor/`), so *any* single-module Renovate bump touches `go.mod`, `go.sum`,
and often unrelated files under `vendor/` (shared semconv/version directories get
rewritten wholesale). Once you've merged one otel/grpc/x-net-family bump, every other PR
touching a related module will conflict with it — even though the actual version bumps
are logically compatible. In the first run this dropped 15 of 18 conflicts. Treat these as
expected noise, not real risk, when writing the PR summary — don't imply they were unsafe,
just unmerged.

## Step 3: Risk-assess only what survived Step 2

Assessing risk before merging wastes calls on PRs that just get dropped as conflicts —
in the first run that would have been ~60% wasted effort. Risk-assess after Step 2, using
only the PRs that are actually in each batch branch.

For the **code/dependency batch**, route by ecosystem — one skill doesn't cover everything:
- **Go/npm code libraries** (module/package version bumps): `grafana-engineering:dependency-bump-context`
- **Docker/container image tags** (e.g. the Dockerfile base image group): `grafana-engineering:analyze-image-dep-bump-pr`

For the **GitHub Actions batch**, there's no skill that covers this — do the manual check
for real, don't just note that one should happen. For each action being bumped, actually
read its release notes between the current and target version
(`gh api repos/<owner>/<repo>/releases --paginate` or `gh release view <version> -R
<owner>/<repo>`) and look specifically for **breaking changes to the action's runtime
behavior**, not just its own dependency bumps — version-number size alone doesn't tell
you this. This is exactly the check that would have caught `actions/setup-go` v6.0.0's
`GOTOOLCHAIN=local` change before it broke CI; skipping it or treating it as a formality
is how that regression got through the first time.

Build a table: PR #, title, ecosystem, update type (major/minor/patch/security), severity
(if security), risk verdict. This table becomes the batch PR body — don't discard it.

## Step 4: Build + test the batch

This step applies to the **code/dependency batch only**. The Actions batch has no local
build/test step — its own CI run on the pushed PR is the test (see "Why GitHub Actions
bumps get their own PR"). Skip straight to Step 6 for it.

```bash
make build
```

Use `make build`, not the underlying `npm run build` / `go build` directly — the frontend
build requires `PUBLIC_BACKEND_ENDPOINT`/`PUBLIC_BACKEND_WS_ENDPOINT` exported first, which
only the Makefile target does; running the raw npm command fails with a misleading
"missing export" error that looks like a real regression but isn't.

If `npm install` ran as part of the build and it modified `pkg/web/package-lock.json`
beyond what the merged PRs already changed, discard that diff
(`git checkout -- pkg/web/package-lock.json`) before proceeding — it's typically just
platform-specific optional-dependency drift (e.g. macOS vs. Linux native binaries for
rollup/esbuild), not a real change, and it must not leak into the batch PR.

If the build fails, `git log --oneline` to see which merges are in, and drop the most
recently merged high-risk (major) update first via `git revert -m 1 <merge-commit>`,
then retry the build. Repeat at most twice. If it still fails, stop — don't keep
reverting blindly — and report the failure in the summary (Step 6) without opening a PR.

If the build succeeds, run the app and the k6 suite against it:

```bash
./bin/quickpizza > /tmp/qp_batch.log 2>&1 &
QP_PID=$!
sleep 2
./k6/run-tests.sh -u http://localhost:3333 -t "k6/foundations/*.js"
K6_EXIT=$?
kill $QP_PID
```

Default to `k6/foundations/*.js`, not the full `k6/**/*.js` tree — some subtrees (browser,
extension examples) need the custom xk6 quickpizza extension binary or extra credentials
that aren't guaranteed to be set up locally. Foundations is the representative smoke test
for "did this batch break the app."

This run can exceed a 180s foreground command timeout and get moved to background — that's
expected for the full 17-file foundations suite; treat the background task's exit code as
the pass/fail signal rather than needing to see the full scrolled output (the captured
background-output file may only contain the tail, not the full run, once it's moved).

If `K6_EXIT` is non-zero, apply the same drop-and-retry logic as the build failure
(revert the most recently merged high-risk update, retest, max 2 attempts) before
giving up on the batch. Also check `/tmp/qp_batch.log` for server-side errors, not just
the k6 exit code.

## Step 5: Track drops

Keep a running list of every dependency dropped and why (merge conflict / build failure /
test failure), separate from the ones that made it in. Group conflict-drops by root cause
(e.g. "conflicted with the otel bumps already in the batch") rather than listing them as
unexplained failures — see Step 2's note on why this is expected, not a red flag.

## Step 6: Push and open the draft PR(s)

For the code/dependency batch, only after Step 4 succeeds (or partially succeeds with
drops recorded):

```bash
git push -u origin renovate-batch/$(date +%Y-%m-%d)
gh pr create --draft --title "chore(deps): batch renovate update $(date +%Y-%m-%d)" --body "$(cat <<'EOF'
## Included
<table from Step 3, filtered to what's actually merged>

## Dropped
<list from Step 5, with reason per item, grouped by root cause — omit this section if nothing was dropped>

## Testing
- `make build`: <pass/fail>
- `./k6/run-tests.sh`: <pass/fail, note any skipped/dropped-due-to-failure items>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

For the Actions batch, push and open it unconditionally — there's no local pass/fail
gate for it, its own CI run is the test:

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
<anything found actually reading release notes in Step 3 — call out explicitly if a
breaking runtime/behavior change was found, don't bury it in a version number>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

If the Actions batch's CI comes back red, don't silently fix it by dropping the
offending PR and re-pushing — report which check failed and why in the PR body (edit
it after the run, like the container-images and Actions corrections on PR #544/#546),
and let the human decide whether to drop that PR from the batch or fix the CI config
alongside it. That decision involves a `main`-level CI change, which is out of scope for
this skill to make unilaterally.

Tell the user both PRs are **drafts** and summarize what's in/out for each — do not mark
either ready for review or merge them yourself.

## Step 7: Leave the original PRs alone

Don't close or comment on the individual Renovate PRs. Once the batch PR merges,
Renovate detects the deps are already at target versions on `main` and closes its own
PRs automatically on its next run. Closing them manually beforehand just creates noise
if the batch PR needs changes first.

## Notes

- If Step 1 finds zero open Renovate PRs, say so and stop — nothing to batch.
- If only one Renovate PR is open, still run the full process (risk assessment +
  build/test) rather than special-casing "just merge it" — the value here is the
  tested draft PR, not just the batching.
- If either the code batch or the Actions batch ends up empty after Step 1's filtering
  (e.g. no open Actions PRs this run), just skip that batch's PR entirely — don't open
  an empty one.
- This skill is safe to re-run: each run creates a dated branch, so re-running after a
  previous batch PR is still open just makes a second batch of whatever's newly opened.
  Since most drops are conflicts among *un-merged* PRs, re-running after the current
  batch PR merges should clear out a lot of them automatically (the conflict is against
  content that's now already on `main`).

## Future improvement (not yet implemented)

The real fix for the vendor/lockfile conflict problem (Step 2) is to stop merging each
Renovate branch's generated diff, and instead: collect the target version for each
accepted PR, apply them directly on the batch branch (`go get <module>@<version>` for Go,
edit `package.json` for npm), then run `go mod tidy && go mod vendor` / `npm install`
**once** for the whole batch. That would avoid nearly all of the vendor-churn conflicts
seen in the first run, at the cost of a more complex Step 2. Worth building once this
skill is used regularly enough to justify it.
