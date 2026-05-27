#!/usr/bin/env node

const token = process.env.GITHUB_TOKEN;

if (!token) {
  console.error('GITHUB_TOKEN is required.');
  process.exit(1);
}

const args = new Map();
for (let index = 2; index < process.argv.length; index += 2) {
  args.set(process.argv[index], process.argv[index + 1]);
}

const owner = args.get('--owner') ?? process.env.GITHUB_REPOSITORY_OWNER ?? 'grafana';
const repo =
  args.get('--repo') ??
  process.env.GITHUB_REPOSITORY?.split('/')[1] ??
  'mobile-o11y-demo';
const minMergedAgeDays = Number(args.get('--min-merged-age-days') ?? '7');
const includeAutomation = args.get('--include-automation') === 'true';

if (!Number.isFinite(minMergedAgeDays) || minMergedAgeDays < 0) {
  console.error('--min-merged-age-days must be a non-negative number.');
  process.exit(1);
}

const graphqlUrl = 'https://api.github.com/graphql';
const headers = {
  authorization: `Bearer ${token}`,
  'content-type': 'application/json',
  'user-agent': 'mobile-o11y-branch-audit',
};

async function graphql(query, variables) {
  const response = await fetch(graphqlUrl, {
    method: 'POST',
    headers,
    body: JSON.stringify({ query, variables }),
  });

  if (!response.ok) {
    throw new Error(`GitHub GraphQL request failed: ${response.status} ${await response.text()}`);
  }

  const payload = await response.json();
  if (payload.errors?.length) {
    throw new Error(`GitHub GraphQL errors: ${JSON.stringify(payload.errors)}`);
  }

  return payload.data;
}

async function getBranches() {
  const branches = [];
  let cursor = null;
  let defaultBranchName = 'main';

  do {
    const data = await graphql(
      `query($owner: String!, $repo: String!, $cursor: String) {
        repository(owner: $owner, name: $repo) {
          defaultBranchRef { name }
          refs(
            refPrefix: "refs/heads/"
            first: 100
            after: $cursor
            orderBy: { field: TAG_COMMIT_DATE, direction: DESC }
          ) {
            pageInfo { hasNextPage endCursor }
            nodes {
              name
              target {
                ... on Commit {
                  oid
                  committedDate
                  messageHeadline
                  author { user { login } name }
                }
              }
              associatedPullRequests(first: 10) {
                nodes {
                  number
                  title
                  state
                  merged
                  mergedAt
                  isDraft
                  url
                  author { login }
                  headRefName
                  headRepository { name owner { login } }
                  baseRepository { name owner { login } }
                }
              }
            }
          }
        }
      }`,
      { owner, repo, cursor }
    );

    defaultBranchName = data.repository.defaultBranchRef?.name ?? defaultBranchName;
    branches.push(...data.repository.refs.nodes);
    cursor = data.repository.refs.pageInfo.hasNextPage
      ? data.repository.refs.pageInfo.endCursor
      : null;
  } while (cursor);

  return { branches, defaultBranchName };
}

function isAutomationBranch(branchName) {
  return (
    branchName.startsWith('dependabot/') ||
    branchName.startsWith('renovate/') ||
    branchName.startsWith('release-please--')
  );
}

function mergedAgeDays(mergedAt) {
  return (Date.now() - new Date(mergedAt).getTime()) / 86_400_000;
}

function classify(branch, defaultBranchName) {
  const pullRequests = branch.associatedPullRequests.nodes.filter(
    (candidate) =>
      candidate.headRefName === branch.name &&
      candidate.headRepository?.name === repo &&
      candidate.headRepository?.owner?.login === owner &&
      candidate.baseRepository?.name === repo &&
      candidate.baseRepository?.owner?.login === owner
  );
  const pullRequest =
    pullRequests.find((candidate) => candidate.merged) ??
    pullRequests.find((candidate) => candidate.state === 'OPEN') ??
    pullRequests[0];

  if (branch.name === defaultBranchName) {
    return { bucket: 'protected', branch, pullRequest, reason: 'default branch' };
  }

  const automation = isAutomationBranch(branch.name);
  if (automation && !includeAutomation) {
    return { bucket: 'automation', branch, pullRequest, reason: 'automation branch' };
  }

  if (!pullRequest) {
    return { bucket: 'noPr', branch, pullRequest, reason: 'no linked PR found' };
  }

  if (pullRequest.state === 'OPEN') {
    return { bucket: 'open', branch, pullRequest, reason: 'open PR' };
  }

  if (!pullRequest.merged) {
    return { bucket: 'closedUnmerged', branch, pullRequest, reason: 'closed but not merged' };
  }

  if (mergedAgeDays(pullRequest.mergedAt) < minMergedAgeDays) {
    return {
      bucket: 'recentMerged',
      branch,
      pullRequest,
      reason: `merged less than ${minMergedAgeDays} days ago`,
    };
  }

  return { bucket: 'mergedCandidate', branch, pullRequest, reason: 'merged PR branch' };
}

function row(item) {
  const pr = item.pullRequest;
  const prText = pr ? `[#${pr.number}](${pr.url})` : '-';
  const updated = item.branch.target?.committedDate ?? '-';
  const author =
    item.branch.target?.author?.user?.login ?? item.branch.target?.author?.name ?? '-';
  const sha = item.branch.target?.oid ?? '-';
  return `| \`${item.branch.name}\` | ${prText} | ${author} | ${updated} | \`${sha}\` | ${item.reason} |`;
}

function section(title, items) {
  if (!items.length) {
    return `## ${title}\n\nNone.\n`;
  }

  return [
    `## ${title}`,
    '',
    '| Branch | PR | Last author | Last commit date | SHA | Reason |',
    '| --- | --- | --- | --- | --- | --- |',
    ...items.map(row),
    '',
  ].join('\n');
}

const { branches, defaultBranchName } = await getBranches();
const groups = branches.reduce((accumulator, branch) => {
  const item = classify(branch, defaultBranchName);
  accumulator[item.bucket] ??= [];
  accumulator[item.bucket].push(item);
  return accumulator;
}, {});

const report = [
  `# Branch Cleanup Dry Run: ${owner}/${repo}`,
  '',
  `Generated: ${new Date().toISOString()}`,
  '',
  `This is a dry-run report. It does not delete branches.`,
  `Cross-repo audits require a token with read access to the target repository.`,
  '',
  `Minimum merged-branch age: ${minMergedAgeDays} days`,
  `Automation branches included as delete candidates: ${includeAutomation}`,
  '',
  '## Summary',
  '',
  `- Total branches: ${branches.length}`,
  `- Merged branch cleanup candidates: ${groups.mergedCandidate?.length ?? 0}`,
  `- Recent merged branches skipped: ${groups.recentMerged?.length ?? 0}`,
  `- Open PR branches skipped: ${groups.open?.length ?? 0}`,
  `- Closed-unmerged branches needing review: ${groups.closedUnmerged?.length ?? 0}`,
  `- No-PR branches needing review: ${groups.noPr?.length ?? 0}`,
  `- Automation branches skipped: ${groups.automation?.length ?? 0}`,
  '',
  section('Merged Branch Cleanup Candidates', groups.mergedCandidate ?? []),
  section('Recent Merged Branches Skipped', groups.recentMerged ?? []),
  section('Open PR Branches Skipped', groups.open ?? []),
  section('Closed-Unmerged Branches Needing Review', groups.closedUnmerged ?? []),
  section('No-PR Branches Needing Review', groups.noPr ?? []),
  section('Automation Branches Skipped', groups.automation ?? []),
].join('\n');

console.log(report);
