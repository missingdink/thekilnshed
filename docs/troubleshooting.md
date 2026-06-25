# Troubleshooting

Known failure modes and their fixes.

## `bin/init-site` says "already been run"

The script refuses to substitute twice. Re-run with `--force`:

```sh
bin/init-site --force
```

If you want to start over completely, `git reset --hard <commit-before-init>` then re-run `bin/init-site` clean.

## Template-sync PR overwrites a file I customized

Sync uses overwrite, not merge. To diverge:

1. Move the file path from `tracked:` to `excluded:` in `.template-sync.yml`
2. Re-apply your local changes to the file
3. Commit both

See `docs/template-sync.md` for the full options matrix.

## Cloudflare Pages deploy fails: "project not found"

The `CLOUDFLARE_PROJECT` env in `.github/workflows/deploy-site.yml` doesn't match the actual CF Pages project name.

- Check current value: `grep CLOUDFLARE_PROJECT .github/workflows/deploy-site.yml`
- Either rename the CF project to match, or run `bin/init-site --force` to set the correct name.

## OAuth login fails: "Origin not allowed"

The site URL isn't in the worker's `ALLOWED_ORIGINS`. In `oauth-worker/wrangler.toml`, append the URL, then:

```sh
cd oauth-worker
npx wrangler deploy
```

## Bridgetown major upgrade breaks build

Follow `docs/deps-upgrade.md` step-by-step. Don't merge the Dependabot PR until a manual upgrade has succeeded locally.

## `libvips` missing on dev machine

```sh
brew install vips    # macOS
sudo apt-get install libvips libvips-dev libheif-dev    # Debian/Ubuntu
```

Listed in README prerequisites — re-read it.

## Decap admin login loops

`backend.base_url` in `src/admin/config.yml` doesn't exactly match the deployed worker URL. Trailing slashes, http vs https, and subdomain typos all matter.

Verify:

```sh
grep base_url src/admin/config.yml
npx wrangler whoami  # in oauth-worker/, to confirm worker URL
```

## Template-sync workflow 403s on PR creation

GitHub repo → Settings → Actions → General → scroll to "Workflow permissions" → enable **Allow GitHub Actions to create and approve pull requests**.

## CSS missing on local dev

Known Bridgetown 2 + Tailwind 4 + esbuild interaction. Touch the jit-refresh file:

```sh
touch frontend/styles/jit-refresh.css
```

Then restart `bin/bridgetown start`.

## Visual regression workflow says "No baselines committed yet"

First-run state. Trigger `Update Visual Baselines` via Actions → `Visual Regression` → Run workflow → target: `production`. See [docs/visual-regression.md](visual-regression.md).

## Visual regression workflow says "feature flag is off"

`.template-sync.yml` has `features.visual_regression: false`. Set to `true` and commit. See [docs/visual-regression.md](visual-regression.md).

## Visual regression LFS error on clone

Contributor missing Git LFS. Install:

```sh
brew install git-lfs    # macOS
git lfs install
git lfs pull
```
