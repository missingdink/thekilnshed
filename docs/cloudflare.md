# Cloudflare runbook

The "explain everything once" reference for Cloudflare interactions across this template — Pages, Workers, tokens, DNS, and the gotchas that bit us during v1. Specific concerns live in [cloudflare-pages.md](cloudflare-pages.md) (deploys) and [oauth-proxy.md](oauth-proxy.md) (worker). This file is the index and the trivia.

## Secrets and naming

Repo secrets must be named:

- `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARE_ACCOUNT_ID`

These match the [cloudflare/wrangler-action](https://github.com/cloudflare/wrangler-action) convention. `CF_*` is internal-only shorthand — don't use it for the actual secret names or `wrangler-action` won't pick them up.

The two are not interchangeable:

| Name | What it is | Sensitivity |
| --- | --- | --- |
| `CLOUDFLARE_API_TOKEN` | Per-token credential. Multiple per account. Scoped. | High — full secret. |
| `CLOUDFLARE_ACCOUNT_ID` | One value per CF account. Identifies the account. | Medium — semi-secret. Lets an attacker target your account. Don't paste publicly. |

Find your account ID in the CF dashboard sidebar (right column on any Workers & Pages page).

## API token scoping (least privilege per workload)

Don't reuse one token across workloads. Pages-only tokens can't read Worker subdomain → API returns `null`, which looks like a misconfigured account instead of a missing scope.

### Pages deploy token (used by GitHub Actions)

- `Account → Cloudflare Pages: Edit`

### Workers deploy token (used by `bin/oauth-worker-deploy`)

- `Account → Workers Scripts: Edit`
- `Account → Workers Routes: Edit`
- `Account → Account Settings: Read` (subdomain lookup)
- `User → User Details: Read` (`wrangler whoami`)
- `Zone → Workers Routes: Edit` (only if binding to a custom zone)

### Verification token (used by `bin/cloudflare-verify`)

- `Account → Account Settings: Read`
- Plus whichever read scopes match what you want to list (Pages, Workers).

## Workers subdomain

Every CF account has one `<subdomain>.workers.dev`. Set once per account.

- API returns `null` until set.
- Set via dashboard: Workers & Pages → "Set up your subdomain" banner on first visit.
- Verify:

  ```sh
  curl -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
    "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/workers/subdomain" \
    | jq .result
  ```

Two different "orgs" in play around the worker — don't confuse them:

- `__GITHUB_ORG_SLUG__` (e.g. `beflagrant`) — the GitHub org that owns the site repos. Names the worker (`decap-oauth-<github-org-slug>`).
- Cloudflare Workers subdomain (e.g. `raddichio`) — set once at the CF account level. Suffix for every worker URL (`<worker-name>.<cf-subdomain>.workers.dev`).

## Pages project creation

Project name must match `__CF_PROJECT__` placeholder substituted into `deploy-site.yml` env by `bin/init-site`.

"Direct Upload" path matters — this template deploys via GitHub Actions + wrangler-action, **not** via CF's git integration. Don't connect the project to GitHub in the CF dashboard.

Create via direct API (preferred — wrangler CLI silently no-ops, see [#16](https://github.com/beflagrant/flagrant-site-template/issues/16)):

```sh
curl -s -X POST \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"<project-name>","production_branch":"main"}' \
  "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/pages/projects"
```

Full setup walkthrough: [cloudflare-pages.md](cloudflare-pages.md).

## Custom domains

DNS for apex domains (e.g. `nodega.com`) needs CNAME flattening or an ALIAS record (plain `CNAME` is illegal at the apex).

| DNS provider | Setup |
| --- | --- |
| **Not Cloudflare** | Add `CNAME <subdomain> → <project>.pages.dev` (or A records that CF dashboard shows for the apex). |
| **Cloudflare** | Orange-cloud the CNAME. CF handles edge routing automatically. |

Stuck on "verifying" in the CF dashboard? Check propagation:

```sh
dig <domain> CNAME +short
```

Full DNS walkthrough: [dns-setup.md](dns-setup.md).

## Deployment workflow gotchas

- **Template's own workflows fire on every push** but try to deploy to literal `__CF_PROJECT__` (because the template repo itself never runs `bin/init-site`). Solution: a `gate` job pattern guards the deploy. See `deploy-site.yml` on `main`.
- **`if:` at job level can't read `secrets`** — only step-level `if:` can. Workarounds: dedicated gate job that exposes `needs.gate.outputs.*`, or move the check into a step.
- **`if:` at job level can't read `env`** either. Same workaround.

## Token rotation

1. Generate the new token in the CF dashboard (same scope as the old one).
2. Update the GitHub repo secret per affected site:

   ```sh
   gh secret set CLOUDFLARE_API_TOKEN -R <org>/<repo>
   ```

3. For oauth-worker, rotate any worker secrets at the same time:

   ```sh
   cd oauth-worker
   npx wrangler secret put OAUTH_GITHUB_CLIENT_SECRET
   ```

4. Revoke the old token in the CF dashboard.

## Common errors decoder

| Error | Likely cause |
| --- | --- |
| `project not found` | `CLOUDFLARE_PROJECT` in workflow doesn't match the actual CF project name. Or: `wrangler pages project create` silently no-op'd ([#16](https://github.com/beflagrant/flagrant-site-template/issues/16)) — verify project exists via API list. |
| `Unauthorized` from wrangler | Token missing or scope is wrong for the workload. |
| API returns `null` for `workers/subdomain` | Subdomain not set on the account, **or** token lacks `Account Settings: Read`. |
| OAuth callback `Origin not allowed` | Site URL not in worker's `ALLOWED_ORIGINS` env var. Edit `oauth-worker/wrangler.toml`, redeploy. |
| Decap admin login loops | `base_url` in `src/admin/config.yml` doesn't match worker URL exactly (trailing slash is the usual culprit). |
| Workers Routes 522 | Worker timed out at CF edge (>30s on free tier). Optimize or move to paid plan. |
| `GitHub did not return a token` | OAuth client ID/secret wrong, or GitHub OAuth App callback URL doesn't match worker URL. |
| `ALLOWED_REPOS not configured` | Env var missing in `wrangler.toml`. Set and redeploy. |

## Things to never leak

- **API tokens.** Pass via env var, `read -s`, or password manager. Never paste into chat, logs, or commits.
- **Account ID.** Less sensitive than a token, but treat as semi-secret. It lets an attacker target your specific account.

## See also

- [cloudflare-pages.md](cloudflare-pages.md) — Pages deploy specifics, preview environments, workflow details.
- [oauth-proxy.md](oauth-proxy.md) — Decap OAuth worker setup and per-org deploy.
- [dns-setup.md](dns-setup.md) — DNS setup for custom domains across providers.
