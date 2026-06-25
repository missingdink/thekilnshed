# ADR 0003: Template Sync via Manifest, Not Fork-Merge

**Date:** 2026-05-24
**Status:** Accepted

## Context

The template-repository pattern in GitHub creates a new repo whose files are copies of the template at the moment of "Use this template". After creation, the child site is structurally independent of the template — no fork relationship, no upstream remote, no automatic sync. When the template improves (new workflow, better build config, security fix in the OAuth worker), child sites get nothing automatically.

Static-site templates that ship workflows and operational scripts have a long shelf life — sometimes years per site. Without a sync mechanism, the template ages well in isolation but every child site rots. We wanted child sites to receive improvements from upstream automatically while still being able to diverge intentionally on per-site content.

The decisions split along two axes:

1. **What** carries forward from template to sites (shared infrastructure) versus what each site owns (content, deps, per-site config).
2. **How** the carrying-forward happens mechanically (fork relationship, branch tracking, file-level overlay, external tool).

### Options

- **Manifest-driven file overlay.** Each child site carries a `.template-sync.yml` listing tracked files (overwritten on sync) and excluded files (never touched). A scheduled workflow shallow-clones the template, diffs tracked paths, and opens a PR with deltas.
- **Tracked branch + merge.** Each child site keeps a `template-upstream` branch tracking the template's main. Sync = `git merge template-upstream --no-commit`, opening a PR with conflicts marked.
- **External tool (cruft, `andrewthetechie/gha-template-sync`).** Battle-tested community tools that solve the same problem.
- **Manual diff/copy.** Operators occasionally `diff -r` between template and a child site and copy improvements. The status quo before this template existed.

## Decision

Use a manifest-driven file overlay. Child sites carry `.template-sync.yml` listing exact `tracked:` paths. A scheduled GitHub Actions workflow (`template-sync.yml`) runs every Monday at 10:00 UTC (cron `0 10 * * 1`): it shallow-clones the upstream template, copies tracked files into a `template-sync/<sha>` branch, and opens a PR for human review.

Concrete shape:

- `bin/template-sync` is a Ruby script that performs the diff and copy. It honors the `tracked:` / `excluded:` lists in the local manifest.
- The manifest is also self-tracking — the `template-sync.yml` workflow file and `bin/template-sync` itself appear in `tracked:`, so improvements to the sync mechanism propagate.
- Site-owned files (content under `src/`, `frontend/`, `Gemfile`, `package.json`, `README.md`, `oauth-worker/**`) are in `excluded:` and never touched.
- Conflict resolution is by exclusion: if a site needs to diverge from the template on a tracked file, the operator moves the path from `tracked:` to `excluded:` in their manifest. There is no in-band merge.

## Consequences

- **Positive:** The contract is explicit and greppable. A reader of `.template-sync.yml` knows at a glance which files belong to the template and which to the site. No magic.
- **Positive:** Sync PRs are reviewable as ordinary PRs with file-by-file diffs. No git merge conflicts to resolve — either the site accepted the template's version (already overwritten) or the site has moved the file to `excluded:` (untouched).
- **Positive:** Improvements to the sync script itself propagate via the same mechanism, so fixing `bin/template-sync` once on the template benefits all child sites at the next sync.
- **Positive:** New shared infrastructure (a new workflow, a new helper script) only requires adding the path to the template's `.template-sync.yml.example`. The next sync run picks it up on child sites.
- **Neutral:** Sync uses overwrite, not merge. A site that customizes a tracked file silently loses customizations on next sync. Operators must know to move customized files to `excluded:` before they diverge. v1 documents this in `docs/template-sync.md`; v1.x commits to adding a preview-before-overwrite mechanism (sync PR comment listing the diff between the site's current tracked file and the upstream version, so reviewers see what's about to be lost).
- **Negative:** Adopting the template post-hoc on an existing site requires manual scaffolding: the site needs `.template-sync.yml`, the workflow file, and the `bin/template-sync` script before it can sync at all. The "from scratch" path via `bin/init-site` handles this automatically, but retrofitting is out of scope.
- **Negative:** The manifest must be kept in agreement with reality. If the template adds a new path to its `tracked:` list and a child site's manifest is stale (missing that path), the new file never lands. Sync currently doesn't fall back to "follow the template's manifest" — it follows the site's manifest. This is a deliberate choice for safety but means manifest drift is possible.
- **Negative:** External tools (`cruft`, `andrewthetechie/gha-template-sync`) are maintained by others and could have solved this with less custom code. We chose home-grown for greppability and zero added dependencies; that's a debt if maintenance of `bin/template-sync` outpaces upstream improvements in those tools.
- **Negative:** Sites track the template's `main` branch (`upstream.ref: main` in the manifest). A force-push to template `main`, or a compromise of a maintainer's GitHub account, would propagate to every child site within 7 days. Pinning each site's manifest to an immutable tag (e.g. `v1.0.1`) would block this — at the cost of requiring an explicit per-site manifest bump for every template release. We deliberately track `main` today because team size is small (2FA + branch protection covers the realistic threats) and site count is low (the per-site bump overhead would dominate). Revisit when site count exceeds 3 or when an external maintainer is added to the template repo.

## References

- `bin/template-sync` — the sync implementation
- `.github/workflows/template-sync.yml` — the scheduled workflow
- `.template-sync.yml.example` — canonical manifest shape
- `docs/template-sync.md` — operator runbook
- `test/template_sync_test.rb` — behavior contract
