---
name: renovate-batch-update
description: Consolidate all open Renovate PRs on quickpizza into one tested, reviewable PR. Fetches every open renovate/* branch, merges them into a single batch branch, assesses risk per dependency (via dependency-bump-context), drops anything that fails to merge or breaks the build/k6 suite, and opens one draft PR to main summarizing what's in and what got dropped.
allowed-tools: Bash, Read, Grep, Glob
---

# /renovate-batch-update — Consolidated Dependency Update

Turns the weekly pile of individual Renovate PRs on `grafana/quickpizza` into a single
tested PR, instead of reviewing/merging each one by hand.

**Boundary:** this skill opens a **draft PR to `main`**. It never merges to `main` itself —
that's a shared-branch action and stays a human call.

## Step 0: Sanity check

- Confirm working tree is clean (`git status`). If not, stop and tell the user — do not
  stash or discard their work silently.
- Confirm current branch, then `git fetch origin --prune`.

## Step 1: Collect open Renovate PRs

```bash
gh pr list --state open --json number,title,headRefName,labels,mergeable \
  --search "head:renovate/ OR head:security-" --limit 100
```

Renovate branches are prefixed `renovate/`; security branches use the
`additionalBranchPrefix: "security-"` from `renovate.json`, so also match
`security-*` heads. For each PR, extract from labels: `update-major` /
`update-minor` / `update-patch`, and any `severity:*` / `automerge-security-update`.

## Step 2: Risk-assess each dependency

For every PR (or, when Renovate already grouped several deps into one PR per
`renovate.json`'s `packageRules` — npm/go/docker groups — treat that PR as one unit),
invoke the `grafana-engineering:dependency-bump-context` skill to check:
- the actual upstream diff for the version delta
- whether quickpizza's code touches the changed paths
- any noted breaking changes

Build a table: PR #, title, ecosystem, update type (major/minor/patch/security),
severity (if security), dependency-bump-context verdict. This table becomes the
batch PR body later — don't discard it.

**Major-version bumps**: keep them in the batch by default (per the user's choice to
batch everything), but mark them clearly in the table. If the batch build/tests fail
later, majors are the first candidates to drop (Step 5).

## Step 3: Build the batch branch

```bash
git checkout -b renovate-batch/$(date +%Y-%m-%d) origin/main
```

For each PR from Step 1, in order from lowest-risk (patch/security-patch) to
highest-risk (major):

```bash
git merge --no-ff origin/<headRefName> -m "merge: <PR title> (#<number>)"
```

- On a clean merge: continue.
- On a conflict: `git merge --abort`, record `<PR> — dropped: merge conflict`, continue
  to the next one. Do not attempt manual conflict resolution — Renovate branches are
  machine-generated and conflicts usually mean two PRs touch the same lockfile; resolving
  by hand risks silently picking the wrong version.

## Step 4: Build + test the batch

```bash
make build
```

If the build fails, `git log --oneline` to see which merges are in, and drop the most
recently merged high-risk (major) update first via `git revert -m 1 <merge-commit>`,
then retry the build. Repeat at most twice. If it still fails, stop — don't keep
reverting blindly — and report the failure in the summary (Step 6) without opening a PR.

If the build succeeds, run the app and the k6 suite against it:

```bash
./bin/quickpizza &
QP_PID=$!
sleep 2
./k6/run-tests.sh -u http://localhost:3333 -t "k6/**/*.js"
K6_EXIT=$?
kill $QP_PID
```

If `K6_EXIT` is non-zero, apply the same drop-and-retry logic as the build failure
(revert the most recently merged high-risk update, retest, max 2 attempts) before
giving up on the batch.

## Step 5: Track drops

Keep a running list of every dependency dropped and why (merge conflict / build failure
/ test failure), separate from the ones that made it in. This list is required content
for the PR body — a batch PR that silently drops updates without saying so defeats the
point of the process.

## Step 6: Push and open the draft PR

Only after Step 4 succeeds (or partially succeeds with drops recorded):

```bash
git push -u origin renovate-batch/$(date +%Y-%m-%d)
gh pr create --draft --title "chore(deps): batch renovate update $(date +%Y-%m-%d)" --body "$(cat <<'EOF'
## Included
<table from Step 2, filtered to what's actually merged>

## Dropped
<list from Step 5, with reason per item — omit this section if nothing was dropped>

## Testing
- `make build`: <pass/fail>
- `./k6/run-tests.sh`: <pass/fail, note any skipped/dropped-due-to-failure items>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Tell the user the PR is a **draft** and summarize what's in/out — do not mark it ready
for review or merge it yourself.

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
- This skill is safe to re-run: each run creates a dated branch, so re-running after a
  previous batch PR is still open just makes a second batch of whatever's newly opened.
