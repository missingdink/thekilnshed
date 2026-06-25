# Cloudflare Pages

**See also:** [cloudflare.md](cloudflare.md) — the full Cloudflare runbook (token scoping, subdomain quirks, DNS, common errors). This file covers Pages deploy specifics only.

> **Tip:** Run `bin/cloudflare-verify` (requires `CLOUDFLARE_API_TOKEN` + `CLOUDFLARE_ACCOUNT_ID` env vars) to dump account name, Workers subdomain, existing workers, and existing Pages projects in one shot. Helpful for picking unique project names and confirming your token has the right scope.

## Initial setup (one-time, per site)

1. **Create the Pages project**

   In CF dashboard → Workers & Pages → Create → Pages → "Direct Upload" path. Set:
   - Project name: match `__CLOUDFLARE_PROJECT__` from `bin/init-site` answers (search `deploy-site.yml` to confirm).
   - Production branch: `main`.

   Or via direct API call (preferred over CLI — see warning below):

   ```sh
   curl -s -X POST \
     -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"name":"<project-name>","production_branch":"main"}' \
     "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/pages/projects"
   ```

   Verify creation:

   ```sh
   curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
     "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/pages/projects" \
     | jq '.result[].name'
   ```

   > **Warning — avoid `npx wrangler pages project create`.** Observed silent failure (2026-05-25): exit 0, no error output, but project was never created. Suspected wrangler v3/v4 version drift. Always verify with the list call above if you use the CLI form. See issue #16.

2. **Generate an API token**

   CF dashboard → My Profile → API Tokens → Create Token → custom token with:
   - Permissions: `Account: Cloudflare Pages: Edit`
   - Account resources: `Include: <your account>`

3. **Add repo secrets**

   GitHub repo → Settings → Secrets and variables → Actions → New repository secret:
   - `CLOUDFLARE_API_TOKEN` = the token from step 2
   - `CLOUDFLARE_ACCOUNT_ID` = your CF account ID (sidebar in the CF dashboard)

4. **Custom domain**

   See [docs/dns-setup.md](dns-setup.md) for the full flow (covers both "DNS at Cloudflare" and "DNS at DNSimple / external provider" paths).

## How deploys happen

- `deploy-site.yml` runs on push to `main`, daily cron (11:00 UTC), and manual dispatch.
- `preview-deploy.yml` runs on PR open/sync/reopen, deploys to `pr-<N>` branch on CF Pages, comments preview URL on PR.
- `preview-cleanup.yml` runs on PR close, deletes the preview deployment via CF API.

## Common failures

| Failure | Fix |
| --- | --- |
| `project not found` | CF project name in workflow `env.CLOUDFLARE_PROJECT` doesn't match the actual CF project. Re-run `bin/init-site --force` with the correct name, or rename CF project. Also possible: `wrangler pages project create` silently no-op'd — verify via API list call above (issue #16). |
| `Unauthorized` from wrangler | `CLOUDFLARE_API_TOKEN` missing or lacks `Cloudflare Pages: Edit` permission. |
| Build job passes but no deploy | Look at the deploy job logs — usually a missing artifact upload. |
| Custom domain stuck on "verifying" | Check DNS propagation: `dig <domain> CNAME +short`. |
