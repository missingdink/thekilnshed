# Template Sync

How structural updates (workflows, scripts, config) flow from the upstream template into this site.

## What it does

A weekly GitHub Actions workflow (`.github/workflows/template-sync.yml`) shallow-clones the upstream template repo, diffs each path listed in `.template-sync.yml#tracked`, and opens a PR with any deltas. Dependencies (`Gemfile`, `package.json`) are out of scope — those are handled by Dependabot.

## What's tracked vs excluded

`.template-sync.yml`:

- `tracked:` — files that are overwritten unconditionally on sync. Shared infra: workflows, build configs, binstubs, etc.
- `excluded:` — files this site owns. Never touched by sync. Site content (`src/`, `frontend/`), site-specific config (`config/initializers.rb`, `Gemfile`, `package.json`, `README.md`), and one-shot/per-site scripts (`bin/init-site`, `oauth-worker/`).

## When sync runs

- Cron: every Monday 10:00 UTC
- Manual: `workflow_dispatch` from the Actions tab
- Local dry-run: `bin/template-sync --dry-run=true`

## How to review a sync PR

1. Read the PR title (`Template sync: <short-sha>`) — that's the upstream commit you're picking up
2. Look at each file's diff individually
3. Merge if changes are wanted

## How to diverge from the template on a tracked file

You have three options:

1. **Move it to `excluded:`** — site owns the file from now on. Sync won't touch it. Document why in a code comment.
2. **Accept the overwrite and re-apply your local change** — file in a follow-up PR.
3. **Send your change upstream** — file a PR against `beflagrant/flagrant-site-template`. Everyone benefits.

## How to opt out entirely

Delete `.github/workflows/template-sync.yml`. The site stops syncing. You're now on your own for keeping infra current.

## Common failures

- **Workflow lacks permission to open a PR:** Settings → Actions → General → enable "Allow GitHub Actions to create and approve pull requests."
- **Merge conflicts in tracked files:** sync uses overwrite, not merge. If you see this, you've manually edited a tracked file — see "How to diverge" above.
- **Sync stopped working after a template restructure:** read template release notes, update your `.template-sync.yml` `tracked:` paths.
