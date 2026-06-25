# ADR 0004: Marker-File Gate Pattern for Workflows in Uninitialized Template Clones

**Date:** 2026-05-25
**Status:** Accepted

## Context

The template repo (`beflagrant/flagrant-site-template`) ships workflow files (`deploy-site.yml`, `preview-deploy.yml`, `preview-cleanup.yml`, `perf-monitor.yml`, `visual-regression.yml`) with literal placeholders for site-specific values (`__SITE_URL__`, `__CLOUDFLARE_PROJECT__`). Child sites substitute these via `bin/init-site` at "Use this template" time.

But the template repo itself never runs `bin/init-site` — it owns the unsubstituted placeholders so child sites have something to substitute. That means every push to the template triggers its own workflows, which then try to deploy to a Cloudflare Pages project literally named `__CLOUDFLARE_PROJECT__`. The deploy job fails noisily, the PR-preview deploy fails noisily, perf-monitor tries to fetch metrics for `__SITE_URL__`, etc.

The fix is to gate these workflows: skip them when the placeholders haven't been substituted, run them when they have. The tricky part is how to detect the substitution state in a way that doesn't itself get rewritten by the substitution process.

We initially tried a literal string comparison in the workflow:

```yaml
if [[ "${{ env.CLOUDFLARE_PROJECT }}" == "__CLOUDFLARE_PROJECT__" ]]; then
  echo "Template not initialized; skipping deploy."
  exit 0
fi
```

This breaks on child sites because `bin/init-site` walks the working tree and substitutes the literal `__CLOUDFLARE_PROJECT__` string everywhere it finds it — including inside the workflow's gate check itself. The check on a child site becomes `if [[ "perchfall-website" == "perchfall-website" ]]; then` which is always true, so the deploy is incorrectly skipped on the very sites it's supposed to run on.

We also can't reference `env` from a job-level `if:` in GitHub Actions; that context is available at step level only. A workflow-level `if:` would have been cleaner if it had been supported.

### Options

- **Marker file.** `bin/init-site` writes `.template-initialized` (containing the ISO date) at successful completion. Every workflow has a `gate` job that checks for the file's existence and exposes the result as a job output; other jobs `needs: gate` and `if: needs.gate.outputs.initialized == 'true'`.
- **Obfuscated string comparison.** Build the placeholder string at runtime so init-site can't pattern-match it: `placeholder="__CLOUDFLARE_${PROJ}__"; PROJ="PROJECT"`. Works but is repulsive.
- **Add `.github/workflows/` to `bin/init-site` SKIP_PATHS.** Workflow files would keep literal `__CLOUDFLARE_PROJECT__` text, but then the workflow's *actual* deploy step would also have literal placeholders. Worse.
- **Live with the template's own deploys failing.** Accept red CI status on every push to the template. Rejected because (a) maintainers learn to ignore the always-red badge, then miss real deploy failures on child sites; (b) every push emails the maintainer a deploy failure, drowning real signals; (c) prospective users visiting the template repo see a red badge and reasonably question whether the template works at all.

## Decision

Use a marker file. `bin/init-site` writes `.template-initialized` at successful completion. Each workflow that should skip on the unitialized template gains a `gate` job:

```yaml
jobs:
  gate:
    runs-on: ubuntu-latest
    outputs:
      initialized: ${{ steps.check.outputs.initialized }}
    steps:
      - uses: actions/checkout@v6
      - id: check
        run: |
          if [[ -f .template-initialized ]]; then
            echo "initialized=true" >> "$GITHUB_OUTPUT"
          else
            echo "No .template-initialized marker found; skipping."
            echo "initialized=false" >> "$GITHUB_OUTPUT"
          fi
```

Downstream jobs depend on `gate` and gate on its output:

```yaml
  build:
    needs: gate
    if: needs.gate.outputs.initialized == 'true'
```

The marker file is checked into the child site's repo at init time. The template repo lacks the file (we don't commit it on `main`), so the template's own pushes correctly skip the deploys.

A `no-template-initialized-marker` job in `.github/workflows/ci.yml` actively guards against accidental commits of the marker to the template repo. If the file appears at the template's repo root, that job fails CI and the offending change can be reverted before any deploys try to run.

`ci.yml` is deliberately ungated — it has no `gate` job and runs on every push. Its work (init-script tests, template-sync tests, smoke build) doesn't require a substituted template; the smoke job runs `bin/init-site --non-interactive --defaults` in its own checkout to set up test conditions. Gating CI would defeat the point of running it on the template repo.

## Consequences

- **Positive:** No placeholder-substitution hazard. `bin/init-site` doesn't substitute anything inside `.template-initialized` because its content is just an ISO date string with no placeholders. The marker file's role is purely "does it exist", which `init-site` cannot subvert.
- **Positive:** The gate logic is identical across all five workflows that need it. Adding a sixth workflow that should gate is one copy-paste of the `gate` job and one `needs: gate` line.
- **Positive:** Operators can manually create or delete the marker to force-skip or force-run workflows during debugging without editing scripts.
- **Positive:** Tests cover the contract (`test/init_site_test.rb#test_writes_template_initialized_marker`) so regressions in the marker behavior surface in CI.
- **Neutral:** The marker is committed by `bin/init-site` indirectly — `init-site` only writes the file; the operator's subsequent `git add -A && git commit` carries it into the repo. If an operator commits selectively and forgets the marker, the deploy job will skip with a clear "No `.template-initialized` marker found" message in the log, which is the recoverable failure mode.
- **Neutral:** The `gate` job adds 5–10 seconds of runtime to each workflow (checkout + one bash check). Acceptable.
- **Negative:** The gate pattern adds one extra job per workflow. Workflow YAML grew by ~75 lines across the 5 gated workflows (15 lines per gate job × 5 workflows, plus `needs: gate` + `if:` on each downstream job). The trade is visual noise for safety.
- **Negative:** New contributors to the template may not immediately see why the gate exists. The first ADR they consult should be this one; the docs in `docs/troubleshooting.md` reference it for the "No `.template-initialized` marker found" message but the design rationale belongs here.

## References

- `bin/init-site` — writes `.template-initialized` at the end of `main()`
- `.github/workflows/deploy-site.yml` — reference gate implementation
- `test/init_site_test.rb#test_writes_template_initialized_marker` — regression test
- `docs/troubleshooting.md` — operator-facing failure mode entry
- Original (broken) implementation: substituted-string comparison, fixed in commit `559f7ad`
