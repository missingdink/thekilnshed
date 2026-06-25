# Decap OAuth Worker

A Cloudflare Worker that handles the GitHub OAuth handshake for Decap CMS. One deploy per GitHub org.

**See also:** [cloudflare.md](cloudflare.md) — the full Cloudflare runbook (token scoping, subdomain quirks, common errors). This file covers the OAuth worker specifically.

## Architecture

- `oauth-worker/src/worker.js` — stateless Worker, two routes (`/auth`, `/callback`).
- `oauth-worker/wrangler.toml.template` — committed; substituted to `wrangler.toml` (gitignored) per-org by `bin/oauth-worker-deploy`.
- Per-org secrets via `wrangler secret put`.

## Finding your Cloudflare Workers subdomain

Every Cloudflare account has a Workers subdomain like `<subdomain>.workers.dev`. You'll need it for the OAuth App callback URL and the site's Decap `base_url`. Three ways to find it:

- **CF dashboard**: Workers & Pages → top-right corner shows `<subdomain>.workers.dev`
- **`wrangler whoami`** (after `wrangler login`)
- **`bin/cloudflare-verify`** — prints account name, subdomain, existing workers, and Pages projects. Requires `CLOUDFLARE_API_TOKEN` + `CLOUDFLARE_ACCOUNT_ID` env vars (token needs `Account Settings: Read` at minimum)

Example: Flagrant's account uses `raddichio.workers.dev`, and the owning GitHub org is `beflagrant`, so the worker URL is `https://decap-oauth-beflagrant.raddichio.workers.dev`. Replace `beflagrant` with your GitHub org slug and `raddichio` with your Cloudflare Workers subdomain in all examples below.

**Two different orgs in play, don't confuse them:**

- `__GITHUB_ORG_SLUG__` (e.g. `beflagrant`) — the GitHub org that owns the site repos. Names the worker (`decap-oauth-<github-org-slug>`).
- Cloudflare Workers subdomain (e.g. `raddichio`) — set once at the Cloudflare account level; suffix for all your workers (`<worker-name>.<cf-subdomain>.workers.dev`).

## First-time per-org setup

1. **Create a GitHub OAuth App** in the org

   GitHub org → Settings → Developer settings → OAuth Apps → New OAuth App:
   - Application name: e.g. `<Org> Decap CMS`
   - Homepage URL: any (use the org's main site)
   - Authorization callback URL: `https://decap-oauth-<github-org-slug>.<your-cf-subdomain>.workers.dev/callback`
     (e.g. `https://decap-oauth-flagrant.raddichio.workers.dev/callback`)

   Save the **Client ID** and generate a **Client Secret**.

2. **Generate a Worker secret** for state cookie HMAC

   Any random 32+ char string (e.g. `openssl rand -hex 32`). Save it.

3. **Run the deploy helper**

   ```sh
   bin/oauth-worker-deploy
   ```

   Prompts for GitHub org slug, allowed origins (comma-separated site URLs), allowed repos (comma-separated `org/repo`). Writes `oauth-worker/wrangler.toml`.

4. **Set secrets and deploy**

   ```sh
   cd oauth-worker
   npx wrangler secret put OAUTH_GITHUB_CLIENT_ID
   npx wrangler secret put OAUTH_GITHUB_CLIENT_SECRET
   npx wrangler secret put WORKER_SECRET
   npx wrangler deploy
   ```

5. **Point each site at the worker**

   In each site's `src/admin/config.yml`:

   ```yaml
   backend:
     name: github
     branch: main
     repo: <org>/<repo>
     base_url: https://decap-oauth-<github-org-slug>.<your-cf-subdomain>.workers.dev
     # e.g. base_url: https://decap-oauth-beflagrant.raddichio.workers.dev
     auth_endpoint: auth
   ```

## Adding a new site to an existing org

1. Edit `oauth-worker/wrangler.toml`:
   - Append the new site URL to `ALLOWED_ORIGINS`
   - Append the new repo to `ALLOWED_REPOS`
2. `cd oauth-worker && npx wrangler deploy`

That's it. No secret changes, no GitHub OAuth App changes.

## Rotating secrets

1. Generate a new value
2. `npx wrangler secret put <SECRET_NAME>` → paste new value
3. `npx wrangler deploy`

Old token cookies in flight will fail validation; users re-login. No coordinated rollover needed.

## Common failures

| Failure | Fix |
| --- | --- |
| Browser console: `Origin not allowed` | The site's origin isn't in `ALLOWED_ORIGINS`. Add it, redeploy worker. |
| Decap login loops back to login | `base_url` in site's `config.yml` doesn't match worker URL (often trailing slash). |
| `GitHub did not return a token` | Client ID/secret wrong, or callback URL in GitHub OAuth App doesn't match worker URL. |
| `ALLOWED_REPOS not configured` | Set the env var in `wrangler.toml` and redeploy. |
