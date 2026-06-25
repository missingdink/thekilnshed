# ADR 0001: Cloudflare Pages as Deploy Target

**Date:** 2026-05-24
**Status:** Accepted

## Context

When designing the template that bootstraps Flagrant client sites, we needed a hosting platform that satisfied several constraints at once. Sites built from the template are static output from Bridgetown, so any static host could serve them. The platform choice nonetheless cascaded through every workflow: build pipelines, preview deploys, custom domains, secret naming, and the OAuth worker that backs Decap CMS all live downstream of this decision.

The shape of what we needed:

- Static hosting with a free tier (most client sites are small marketing sites)
- Per-PR preview deployments
- Edge-cached delivery for performance
- Custom-domain attachment without per-domain billing
- A scriptable deploy interface compatible with GitHub Actions
- Self-hosted OAuth proxy support. The CMS authorization flow must run on infrastructure we control, not on a hosted OAuth-as-a-service offering. Vendors that lock OAuth behind their own platform (Netlify's git-gateway, etc.) leave us at the mercy of their pricing decisions — including unit-of-billing changes from per-account to per-seat or per-user, the most common monetization shift in this category

The team already had an existing site (`beflagrant/flagrant-website`) on GitHub Pages, which proved insufficient: GitHub Pages doesn't support PR previews natively, custom domain TLS provisioning is slow, and there's no compute primitive for OAuth.

### Options

- **Cloudflare Pages + Workers.** Static + edge compute on one vendor. Free tier covers expected traffic. Native PR previews. Wrangler CLI scriptable from GHA. Workers next door for the OAuth proxy.
- **Netlify.** Existing first-party Decap integration via git-gateway and Netlify Identity. Free tier capped at 100 GB bandwidth/month vs CF's unmetered. Rejected primarily because Netlify Identity / git-gateway is a managed OAuth dependency — Netlify can re-price or sunset that surface unilaterally, and the per-user pricing tier above the free plan is exactly the cost-control failure mode we're avoiding.
- **Vercel.** Excellent DX, fast builds, generous free tier. No first-party serverless platform suitable for an OAuth proxy at the same price point; we'd have to point Decap at a Netlify-hosted proxy anyway.
- **Render / Fly.io / S3+CloudFront.** Possible but adds vendor management or infrastructure work not justified by the workload.

## Decision

Use Cloudflare Pages as the deploy target for sites generated from this template, and deploy from GitHub Actions using `cloudflare/wrangler-action@v3`. Use Cloudflare Workers (next to Pages) for the Decap CMS OAuth proxy, deployed once per GitHub org.

Concrete shape:

- `deploy-site.yml` builds the Bridgetown output and pushes to Cloudflare Pages via wrangler-action.
- `preview-deploy.yml` deploys PR branches to `pr-<N>.<project>.pages.dev`.
- `preview-cleanup.yml` deletes preview deployments via the CF API when PRs close.
- Secrets are named with the `CLOUDFLARE_` prefix to match Cloudflare's documentation: `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`.

## Consequences

- **Positive:** One vendor for both static hosting and the OAuth proxy. The team learns one set of CLI tools (wrangler), one dashboard, one set of API tokens. Onboarding a new client site uses one CF account dashboard.
- **Positive:** PR previews come effectively free — wrangler-action takes a `--branch=pr-N` flag and CF generates a unique URL per branch. The preview URL is predictable, so we can poll for it in the visual regression workflow.
- **Positive:** Cloudflare's free tier covers expected traffic for Flagrant's client base. Bandwidth is unlimited; build minutes (500/month) is the active constraint and we're well under.
- **Positive:** Worker subdomain (`<slug>.workers.dev`) is set once per CF account and shared across all org worker deploys, simplifying the "add a new client" workflow.
- **Neutral:** Cloudflare's API token model surfaces complexity for teams: Pages-Edit-only tokens can't deploy workers and vice versa. We document the two-token pattern in `docs/oauth-proxy.md`. New team members need to understand the distinction.
- **Negative:** Cloudflare Pages requires DNS at Cloudflare to attach apex domains (`example.com`). Sites that want to keep DNS at DNSimple or another registrar must use the CNAME-only path with `www.` and a separate apex-redirect mechanism. Documented in `docs/dns-setup.md` as Path A.
- **Negative:** `wrangler pages project create` has been observed to silently fail without creating the project, returning exit 0 with no error output. We fall back to direct CF API calls in those cases. See issue [#16](https://github.com/beflagrant/flagrant-site-template/issues/16).
- **Negative:** CF's API tokens are personal by default. Team-shareable account tokens require a paid plan; OIDC integration is the future-proof answer but adds setup complexity. Tracked in issue [#15](https://github.com/beflagrant/flagrant-site-template/issues/15).

## References

- `docs/cloudflare-pages.md` — operational runbook
- `docs/dns-setup.md` — DNS configuration paths
- `docs/oauth-proxy.md` — OAuth worker setup that depends on this decision
- Issue #15 — team-shareable Cloudflare API tokens
- Issue #16 — wrangler CLI silent failure on `pages project create`
