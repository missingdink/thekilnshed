# __SITE_NAME__

A Bridgetown 2.2 site, generated from [flagrant-site-template](https://github.com/beflagrant/flagrant-site-template).

## Prerequisites

- Ruby `4.0.5` (see `.ruby-version`)
- Node `26.2.0` (see `.nvmrc`)
- `libvips` (`brew install vips` on macOS) — required by `bridgetown-image-pipeline`
- `wrangler` (`npm install -g wrangler`) — only if deploying or managing the OAuth Worker
- `git-lfs` (`brew install git-lfs && git lfs install`) — optional, required only if visual regression is enabled (snapshots are tracked via LFS per `.gitattributes`). Without it, the PNG files in `test/visual/snapshots/` will appear as small text pointer files and won't open in Preview.

## Install

```sh
bundle install
npm install
```

## Develop

```sh
# Bridgetown + Decap admin (via Foreman)
bundle exec foreman start

# Or just Bridgetown
bin/bridgetown start
```

Visit:

- Site: <http://localhost:4000>
- Admin: <http://localhost:4000/admin/>

## Deploy

Pushes to `main` deploy via GitHub Actions to Cloudflare Pages. Required repo secrets:

- `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARE_ACCOUNT_ID`

See [docs/cloudflare-pages.md](docs/cloudflare-pages.md) for setup.

## Template lineage

This site syncs structural files from the upstream template weekly. See [docs/template-sync.md](docs/template-sync.md).

## Docs

- [docs/new-site.md](docs/new-site.md) — full new-site init checklist
- [docs/template-sync.md](docs/template-sync.md) — how template-sync works
- [docs/cloudflare.md](docs/cloudflare.md) — full Cloudflare runbook (tokens, subdomain, DNS, common errors)
- [docs/cloudflare-pages.md](docs/cloudflare-pages.md) — CF Pages setup, secrets, custom domain
- [docs/dns-setup.md](docs/dns-setup.md) — DNS at Cloudflare vs external provider (DNSimple, etc.)
- [docs/oauth-proxy.md](docs/oauth-proxy.md) — per-org OAuth Worker deploy + maintenance
- [docs/deps-upgrade.md](docs/deps-upgrade.md) — Bridgetown major-version playbook
- [docs/decap-recipes.md](docs/decap-recipes.md) — Decap collection snippets
- [docs/visual-regression.md](docs/visual-regression.md) — Playwright snapshot testing (opt-in)
- [docs/troubleshooting.md](docs/troubleshooting.md) — known failure modes
