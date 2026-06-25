# Visual Regression Testing

Playwright snapshot tests run against Cloudflare Pages preview URLs on every PR and against the production URL after every deploy. Snapshots are stored in Git LFS at `test/visual/snapshots/`.

## How it works

`/.github/workflows/visual-regression.yml` defines three jobs:

- `visual-regression-pull-request` — runs on `pull_request`, polls the CF preview URL, captures snapshots, diffs against committed baselines, blocks merge on regression
- `visual-regression-production` — runs on completion of `Deploy Site to Cloudflare Pages`, captures from production URL, diffs against baselines, opens a non-blocking GitHub issue on regression (dedups against existing open issue)
- `visual-regression-update-baselines` — manual `workflow_dispatch`, regenerates baselines from CI runner (matches CI environment exactly), commits them back to the branch

`playwright.config.ts` defines three browser projects (Chromium, Firefox, WebKit) with `maxDiffPixelRatio: 0.01`, animations disabled, caret hidden, fullPage screenshots.

`test/visual/site.spec.ts` parameterises over pages × viewports:

- Pages: `/`, `/404.html`
- Viewports: desktop (1280×800), mobile (375×667)
- Total: 2 × 2 × 3 browsers = **12 baselines** per site

## First-time setup (opt in)

1. **Enable the feature flag** in `.template-sync.yml`:

   ```yaml
   features:
     visual_regression: true
   ```

2. **Push to GitHub.** PR/production jobs will skip (no baselines yet).

3. **Trigger Update Visual Baselines** workflow from the Actions tab:

   - Workflow: `Visual Regression`
   - Run workflow → branch: `main` → target: `production`

   The workflow installs Playwright, hits your production URL, captures 12 baselines, commits them to `main` via the bot identity.

4. **Subsequent runs** compare against these committed baselines.

## Baseline storage (Git LFS)

`test/visual/snapshots/**/*.png` is tracked via Git LFS (rule in `.gitattributes`). Reasons:

- Cleaner git history (binary diffs don't bloat objects)
- Free tier limits: 1 GB storage + 1 GB/month bandwidth (12 PNGs × ~50 KB ≈ 600 KB total — well under)
- CF Pages build uses `cloudflare/wrangler-action@v3` against built `output/` (doesn't fetch LFS)
- CI uses `actions/checkout@v6` with `lfs: true` to fetch baselines for diff

Contributors need Git LFS installed locally to clone snapshots. macOS:

```sh
brew install git-lfs
git lfs install
```

## Updating baselines

After an intentional UI change, baselines must be regenerated. Always do this in CI (not locally) — font rendering differs between OS/architecture and would cause spurious diffs.

### From a PR (preview environment)

1. Push your changes; preview deploy lands at `pr-<N>.<project>.pages.dev`
2. Actions tab → `Visual Regression` → `Run workflow`:
   - Branch: your PR branch
   - Target: `preview`
   - PR number: `<N>`
3. Workflow updates baselines on your branch; PR re-runs visual regression and passes
4. Merge

### From production (after merge)

1. Actions tab → `Visual Regression` → `Run workflow`:
   - Branch: `main`
   - Target: `production`
2. Bot commits new baselines to `main`
3. Production regression issue (if open) can be closed manually

## Interpreting failures

### PR job failed

PR comment links to a workflow artifact named `visual-regression-diffs-pr-<N>` containing:

- `expected-*.png` — the committed baseline
- `actual-*.png` — what Playwright saw
- `diff-*.png` — visual diff (red overlay where pixels changed)

Download the artifact ZIP and inspect the diff PNGs. If the change is intentional, update baselines (see above). If unintentional, fix the code.

### Production issue opened

Same artifact, retention 30 days. Issue body links to it and to commit SHA. Resolve by either updating baselines (intentional change) or reverting/fixing (regression).

## Failure modes

| Symptom | Cause | Fix |
| --- | --- | --- |
| Workflow logs "No baselines committed yet" | First-run state | Trigger `workflow_dispatch` with target: `production` |
| Workflow logs "feature flag is off" | `.template-sync.yml` has `visual_regression: false` (default) | Flip to `true` and commit |
| Workflow times out on "Wait for preview" | CF Pages preview deploy failed or slow | Check `preview-deploy.yml` run; CF preview must serve HTTP 200 within 10 min |
| Snapshots flaky on font edges only | Anti-aliasing variance | `maxDiffPixelRatio: 0.01` should cover this; widen to `0.02` in `playwright.config.ts` if persistent |
| Regression on every deploy, no real change | Browser version drift (Playwright auto-updated) | Pin `@playwright/test` to exact version in `package.json`; regenerate baselines once |
| LFS clone error | Contributor missing Git LFS | `brew install git-lfs && git lfs install && git lfs pull` |

## Disabling

Set `features.visual_regression: false` in `.template-sync.yml`. Workflow becomes no-op. Files stay (no rot — workflow exits cleanly).

To fully remove: delete `test/visual/`, `playwright.config.ts`, `.gitattributes` LFS rule, remove `@playwright/test` from `package.json`, drop `visual-regression.yml`. None are required by other parts of the template.
