# ADR 0002: One OAuth Worker Deployment Per GitHub Organization

**Date:** 2026-05-24
**Status:** Accepted

## Context

Decap CMS uses GitHub OAuth to authorize content editors. The OAuth dance requires a server-side proxy that holds a GitHub OAuth App's client secret, because the secret can't be shipped in the browser. We chose Cloudflare Workers for this proxy (see [ADR 0001](0001-cloudflare-pages-as-deploy-target.md)).

How that proxy maps to GitHub organizations is the question this ADR answers. Flagrant's client base spans multiple GitHub orgs: the agency's own `beflagrant` org owns the agency website and template, and individual clients may host their site repos under their own orgs (`acmeco`, etc.). Each org wants its own OAuth App so the consent screen says "Sign in to Acme Co's CMS", and so the GitHub audit log attributes editor actions to the right org's OAuth App.

The OAuth proxy code is small (~147 LOC) and stateless. The deployment unit isn't constrained by code size or CF Worker request quotas. It's constrained by the question: *whose GitHub OAuth App's secrets does it hold?*

### Options

- **One worker per GitHub organization.** A separate worker deployment for each org. Each carries that org's OAuth App credentials. Worker names follow `decap-oauth-<github-org-slug>`. Allowlists (origins, repos) are per-org. Adding a new client to an existing org means appending to two env vars and redeploying that org's worker.
- **One worker, multi-tenant.** A single worker handles all orgs, looking up credentials at request time by `site_id` or hostname. Credentials stored in CF KV.
- **One worker per client site.** Maximum isolation, but multiplies deploys and credential rotation work by the number of sites.
- **Cloudflare Workers for Platforms** (dispatch worker routing by hostname to per-org workers). Provides isolation plus a single entry URL. Overkill for ≤5 orgs.

## Decision

Deploy one Cloudflare Worker per GitHub organization that owns Decap-managed repos. Worker name: `decap-oauth-<github-org-slug>` (e.g. `decap-oauth-beflagrant`). Each worker holds its org's GitHub OAuth App secrets and validates incoming requests against per-deploy `ALLOWED_ORIGINS` and `ALLOWED_REPOS` env vars.

Concrete shape:

- The OAuth worker source lives in `oauth-worker/` inside the template repo. It is the same code for every org.
- `bin/oauth-worker-deploy` is a Ruby script that substitutes `__GITHUB_ORG_SLUG__` into `wrangler.toml.template`, writes `wrangler.toml` (gitignored), and prompts for the allowlist values. Operators then run `wrangler secret put` three times and `wrangler deploy`.
- Adding a client site to an existing org requires editing `ALLOWED_ORIGINS` and `ALLOWED_REPOS` in `wrangler.toml`, then `wrangler deploy`. No new OAuth App, no new secrets.
- Adding a new org requires a fresh GitHub OAuth App, a fresh worker deploy (different `__GITHUB_ORG_SLUG__`), and three fresh secrets.

## Consequences

- **Positive:** Each org's credentials live entirely under that org's control. Compromise of one org's GitHub OAuth Client Secret affects only that org's sites. The GitHub audit log under each org's OAuth App accurately attributes editor actions.
- **Positive:** Worker code stays trivially auditable — no credential lookup logic, no multi-tenant routing, no KV reads in the hot path. The HMAC state-cookie verification + token exchange is the entire request flow.
- **Positive:** Adding a new client site to an existing org takes ~30 seconds: two env-var edits and a redeploy. No secret rotation, no OAuth App churn, no documentation drift.
- **Positive:** The `decap-oauth-<org>` naming convention makes "which worker handles whose login" greppable in the CF dashboard.
- **Neutral:** Each org's worker URL is different (`decap-oauth-beflagrant.<sub>.workers.dev`, `decap-oauth-acmeco.<sub>.workers.dev`). Decap's `backend.base_url` must be set per site to the right org's worker URL. This is encoded as the `__OAUTH_WORKER_URL__` placeholder substituted by `bin/init-site`.
- **Neutral:** The Cloudflare Workers subdomain (`<sub>.workers.dev`) is shared across all org worker deploys in the same CF account. Multiple Flagrant CF accounts (one per highly-isolated client) would each get their own subdomain. We don't currently expect this case but the design accommodates it without changes.
- **Negative:** N orgs means N deploys to keep current. When the worker source changes (e.g. the Decap handshake fix in `e83250e`), every org's worker must be redeployed. We track this manually today. If we ever need a worker change deployed across all orgs on the same day — a security fix, an upstream-breaking Decap API change — we'd build a scripted multi-org deploy. That trigger is currently hypothetical; routine source changes can land org-by-org at the pace of redeploys. Tracked indirectly by issue [#11](https://github.com/beflagrant/flagrant-site-template/issues/11) (extract oauth-worker to standalone repo, where automated multi-deploy makes more sense).
- **Negative:** Operators must understand the distinction between "site setup" and "org setup". Setting up a fresh org is heavier (GitHub OAuth App + worker deploy + secrets); setting up a fresh site in an existing org is light. The docs in `docs/oauth-proxy.md` cover both paths but the difference is non-obvious at first read.

## References

- [ADR 0001](0001-cloudflare-pages-as-deploy-target.md) — Cloudflare Pages choice that made Workers a natural OAuth host
- `oauth-worker/src/worker.js` — the deployed code
- `bin/oauth-worker-deploy` — per-org deploy helper
- `docs/oauth-proxy.md` — operator runbook
- Issue #11 — extract oauth-worker to standalone repo
