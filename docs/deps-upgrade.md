# Dependency Upgrades

Most upgrades are handled by Dependabot — review the PR, merge if CI is green. This doc covers the exceptions: majors, especially Bridgetown majors.

## Bridgetown major-version upgrade

1. **Read upstream release notes** at <https://www.bridgetownrb.com/docs/releases>.

2. **Branch in the template repo first** (so child sites pick up workflow changes via sync once stable):

   ```sh
   git checkout -b chore/bridgetown-X.Y
   ```

3. **Update the gem pin**

   In `Gemfile`:

   ```ruby
   gem "bridgetown", "~> X.Y.0"
   ```

   Then:

   ```sh
   bundle update bridgetown
   ```

4. **Run a full build locally**

   ```sh
   bin/init-site --non-interactive --defaults --force   # only in a scratch checkout
   npm run build
   ```

   Fix any errors. Common breakage:
   - Renamed Liquid/ERB filters (Bridgetown 2.x deprecates many Jekyll-isms)
   - Config DSL changes in `config/initializers.rb`
   - Plugin compat: feed/sitemap/image-pipeline may need version bumps in lockstep

5. **Update other workflows if needed** (e.g. apt packages, Ruby version pin)

6. **Document migration steps** in this file under a dated section so child sites have a checklist.

7. **Merge to template `main`.** Child sites will pick up workflow/config changes via template-sync. Each child site must merge the Bridgetown gem bump separately (Dependabot will open that PR).

## Tailwind major-version upgrade

Mostly straightforward — Tailwind 4 is the current target. Watch for:
- `@tailwindcss/postcss` plugin pinning (in `postcss.config.js`)
- CSS import syntax (`@import "tailwindcss"` vs older `@tailwind base/components/utilities`)

## Decap major-version upgrade

Decap config schema changes silently across minors. After any Decap dep bump:

```sh
npx decap-server  # in one terminal
bin/bridgetown start  # in another
```

Visit `/admin/` → log in → confirm collections render. If the admin shell errors silently, the `<script src="https://unpkg.com/decap-cms@..."` version in `src/admin/index.html` may need bumping.
