---
name: renovate-batch-update
description: Consolidate all open Renovate PRs on quickpizza into one tested, reviewable PR. Fetches every open renovate/* branch, merges as many as will merge cleanly into a single batch branch, risk-assesses the survivors, builds + runs the k6 suite, and opens one draft PR to main summarizing what's in and what got dropped.
allowed-tools: Bash, Read, Grep, Glob
---

# /renovate-batch-update — Consolidated Dependency Update

Turns the weekly pile of individual Renovate PRs on `grafana/quickpizza` into a single
tested PR, instead of reviewing/merging each one by hand.

**Boundary:** this skill opens a **draft PR to `main`**. It never merges to `main` itself —
that's a shared-branch action and stays a human call.

**Known limitation (from the 2026-09-22 dry run, PR #544):** with 29 open Renovate PRs,
only 13 merged cleanly — the other 18 were dropped purely on `git merge` conflicts in
`vendor/`, `go.sum`, and `pkg/web/package-lock.json`, not real incompatibilities. See
Step 2 for the mitigations this taught, and "Future improvement" at the bottom for the
real fix (bump via `go get`/`npm install` instead of merging generated diffs).

## Step 0: Sanity check

- Confirm working tree is clean (`git status`). If not, stop and tell the user — do not
  stash or discard their work silently.
- Confirm current branch, then `git fetch origin --prune`.
- Check if port 3333 is already in use (`lsof -i :3333`) — quickpizza's port is hardcoded
  in `cmd/main.go` with no override, and it's common to have a long-running local Docker
  container (`docker ps --filter publish=3333`) bound to it already. If so, **ask the user**
  before touching it — don't kill an unrelated process. If they agree, `docker stop <name>`
  before Step 4 and `docker start <name>` again once k6 finishes, whether it passed or not.

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

## Step 2: Build the batch branch

```bash
git checkout -b renovate-batch/$(date +%Y-%m-%d) origin/main
```

Merge order: lowest-risk first (security-patch, security-minor by severity LOW), then
grouped patch/minor PRs, then GitHub Actions bumps, then major-version bumps last (majors
are the first candidates to drop if later steps fail).

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
only the PRs that are actually in the batch branch.

Route by ecosystem — one skill doesn't cover everything:
- **Go/npm code libraries** (module/package version bumps): `grafana-engineering:dependency-bump-context`
- **Docker/container image tags**: `grafana-engineering:analyze-image-dep-bump-pr`
- **GitHub Actions version bumps** (`actions/checkout`, `actions/setup-go`, etc.): neither
  skill covers this. Do a quick manual check instead — read the action's release notes for
  the target version (`gh release view <version> -R <owner>/<repo>`) and note anything
  breaking; don't skip the row, just don't force-fit a skill that doesn't apply.

Build a table: PR #, title, ecosystem, update type (major/minor/patch/security), severity
(if security), risk verdict. This table becomes the batch PR body — don't discard it.

## Step 4: Build + test the batch

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

## Step 6: Push and open the draft PR

Only after Step 4 succeeds (or partially succeeds with drops recorded):

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
