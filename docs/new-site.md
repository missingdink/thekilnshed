# New Site Init Checklist

End-to-end: from "Use this template" to a live Cloudflare Pages site with working CMS.

## 1. Create repo from template

GitHub UI → click **Use this template** on `beflagrant/flagrant-site-template` → choose org/repo name.

## 2. Clone and install

```sh
git clone git@github.com:<org>/<repo>.git
cd <repo>
bundle install
npm install
```

If visual regression is enabled (snapshots tracked via Git LFS), also install + initialize LFS:

```sh
brew install git-lfs && git lfs install   # one-time per machine
git lfs pull                              # fetch the actual PNGs
```

Without LFS, `test/visual/snapshots/*.png` are pointer text files, not real images.

## 3. Run `bin/init-site`

```sh
bin/init-site
```

Prompts:

| Prompt | Example |
| --- | --- |
| Site name | `Acme Co Website` |
| Site URL | `https://www.acme.com` |
| GitHub org/repo | `acmeco/acme-website` |
| Cloudflare Pages project name | `acme-website` |
| OAuth Worker URL | `https://decap-oauth-acmeco.workers.dev` |
| GitHub org slug | `acmeco` |

Commits substitutions automatically.

## 4. Create Cloudflare Pages project

In CF dashboard → **Workers & Pages** → **Create Application** → **Pages** → **Direct Upload** (we deploy via GHA, not git integration).

- Project name: match `__CLOUDFLARE_PROJECT__` exactly.

Or via CLI:

```sh
npx wrangler pages project create <project-name> --production-branch=main
```

## 5. Set repo secrets

GitHub repo → Settings → Secrets and variables → Actions:

- `CLOUDFLARE_API_TOKEN` — Cloudflare API token with `Cloudflare Pages: Edit` permission
- `CLOUDFLARE_ACCOUNT_ID` — Cloudflare account ID (sidebar in CF dashboard)
- `PSI_API_KEY` — Google PageSpeed Insights API key (used by `perf-monitor.yml`). Get one at <https://console.cloud.google.com/apis/credentials> after enabling the PageSpeed Insights API. Free quota is 25k queries/day. Optional: workflow falls back to anonymous quota if unset, but throttles quickly.

## 6. Set up OAuth

- **If the owning org already has a deployed OAuth Worker:** edit the worker's `ALLOWED_ORIGINS` and `ALLOWED_REPOS` to include this site, then `npx wrangler deploy` from `oauth-worker/`. See `docs/oauth-proxy.md`.
- **If new org:** follow `docs/oauth-proxy.md` "First-time per-org setup".

## 7. Push to main

```sh
git push origin main
```

Deploy workflow runs. Check Actions tab. First deploy takes ~3 minutes.

## 8. Assign custom domain

CF dashboard → your Pages project → **Custom domains** → add domain. CF handles DNS if your nameservers point to CF; otherwise add the CNAME they show you.

## 9. Verify

- Visit the deployed URL → see "Hello from <site name>".
- Visit `/admin/` → click Login with GitHub → confirm you can edit + publish.
