# Load testing with k6

A k6 reference for load testing this site. k6 is Grafana's open-source load
generator — write a JS script, it spins up virtual users (VUs) against your URLs,
and reports latency/throughput/error metrics. Run it free on your laptop for
script development and smoke tests, then promote the same script to
[Grafana Cloud k6](https://grafana.com/products/cloud/k6/) for distributed,
high-VU runs with hosted dashboards.

> **This is a static site.** Bridgetown builds static HTML/CSS/JS, deployed to
> Cloudflare Pages and served from CF's global edge cache. There is no origin
> app server, no database, no per-request rendering. "Load testing" here means
> confirming the edge holds up (cache hits, TTFB, throughput) — not finding the
> breaking point of a server that doesn't exist.

> **⚠️ You can trip Cloudflare's own defenses.** Hammering your own CF Pages site
> can look like an attack to Cloudflare. It may start returning **429** or a
> **challenge page** (JS challenge / managed challenge) instead of your content.
> That is CF defending the edge — *not* your site failing under load. If error
> rates spike and you see 429s or HTML challenge bodies, you've hit a rate limit,
> not a capacity ceiling. Throttle your VUs, test from a known IP, or coordinate
> with Cloudflare before large runs.

## Install

macOS:

```sh
brew install k6
```

Verify:

```sh
k6 version
```

For Grafana Cloud runs, log in once (opens a browser for auth):

```sh
k6 cloud login
```

## Smoke test (constant VUs)

Start here. One GET against the homepage, a status check, 10 VUs for 30s.
Trivially runnable, confirms the script and target work before you scale up.

`test/load/smoke.js`:

```js
import http from "k6/http";
import { check } from "k6";

export const options = {
  vus: 10,
  duration: "30s",
  thresholds: {
    http_req_duration: ["p(95)<500"], // 95% of requests under 500ms
    http_req_failed: ["rate<0.01"], // under 1% errors
    checks: ["rate>0.99"], // over 99% of checks pass
  },
};

const BASE_URL = __ENV.BASE_URL;

export default function () {
  const res = http.get(BASE_URL);
  check(res, {
    "status is 200": (r) => r.status === 200,
  });
}
```

Run it (no hardcoded host — pass the target in):

```sh
k6 run -e BASE_URL=https://<project>.pages.dev test/load/smoke.js
```

`<project>.pages.dev` is your Cloudflare Pages URL (see
[cloudflare-pages.md](cloudflare-pages.md)). Point `BASE_URL` at a custom domain
once you have one.

## Browse flow (ramped stages)

A more representative test: a virtual user lands on the homepage, then clicks
through a couple of pages with think-time between, the way a real visitor moves.
Uses `stages` to ramp load up and down instead of a constant level.

`test/load/browse.js`:

```js
import http from "k6/http";
import { check, sleep } from "k6";

export const options = {
  stages: [
    { duration: "30s", target: 50 }, // ramp up to 50 VUs
    { duration: "1m", target: 50 }, // hold at 50 VUs
    { duration: "30s", target: 0 }, // ramp back down
  ],
  thresholds: {
    http_req_duration: ["p(95)<500"],
    http_req_failed: ["rate<0.01"],
    checks: ["rate>0.99"],
  },
};

const BASE_URL = __ENV.BASE_URL;

// Swap these for real paths on your site.
const PAGES = ["/", "/about", "/contact"];

export default function () {
  for (const path of PAGES) {
    const res = http.get(`${BASE_URL}${path}`);
    check(res, {
      "status is 200": (r) => r.status === 200,
      "body not a challenge": (r) => !r.body.includes("Just a moment"), // CF challenge tell
    });
    sleep(Math.random() * 3 + 1); // 1–4s think-time between pages
  }
}
```

Run:

```sh
k6 run -e BASE_URL=https://<project>.pages.dev test/load/browse.js
```

> k6 fetches only the URLs you request — it does **not** auto-load a page's CSS,
> JS, or images the way a browser does. The bytes that actually move on this
> site live in the esbuild + Tailwind asset bundles. If you want to model real
> transfer weight, add explicit `http.get()` calls for those assets, or use
> `http.batch()` to fetch them in parallel per iteration. Most reference runs
> don't need this — the page GETs are enough to exercise the edge.

## Thresholds

The `thresholds` block is k6's main value: it turns metrics into pass/fail. A run
that crosses a threshold exits non-zero, so it works in CI or a gate check.

| Threshold | Meaning | Why this default |
| --- | --- | --- |
| `http_req_duration: p(95)<500` | 95th-percentile request time under 500ms | CF edge cache hits should land well under this; a miss flags a cold cache or origin fetch |
| `http_req_failed: rate<0.01` | Fewer than 1% of requests error | Tolerates rare blips; catches real breakage (and CF 429s) |
| `checks: rate>0.99` | Over 99% of `check()` assertions pass | Catches wrong-status / challenge-page responses the failed-rate alone might miss |

These are a **starting baseline** — tune them to your site and the load you
actually expect. A campaign spike wants different numbers than a steady trickle.

## Scaling up: Grafana Cloud k6

When your laptop's uplink becomes the bottleneck (you'll see throughput plateau
while CPU/site are idle — that's *your* bandwidth, not the site), promote the
same script to Grafana Cloud. It runs distributed load from real geographic
regions and gives you hosted dashboards.

```sh
k6 cloud login                                          # once, see Install
k6 cloud run -e BASE_URL=https://<project>.pages.dev test/load/browse.js
```

The script is identical — only the runner changes. Results stream to your
Grafana Cloud account instead of the terminal. Mind the free-tier VU/test limits;
large distributed runs cost money and are far more likely to trip Cloudflare's
rate limiting (see the warning up top).

## Failure modes

| Symptom | Cause | Fix |
| --- | --- | --- |
| Errors spike, bodies contain "Just a moment" or "Attention Required" | Cloudflare challenge / rate limit, not site failure | Lower VUs, slow the ramp, test from an allowlisted IP, or coordinate with CF before big runs |
| HTTP 429 responses | CF (or an upstream proxy) rate-limiting your test IP | Same as above — back off VUs; 429 ≠ capacity ceiling |
| Throughput plateaus while site/CPU idle | Your local uplink is saturated, not the site | Move to Grafana Cloud k6 for distributed load |
| `dial tcp: i/o timeout` / `connection reset` | Too many VUs for one machine's sockets/file descriptors | Reduce VUs, raise `ulimit -n`, or run distributed |
| `k6 run` exits non-zero, "thresholds have failed" | A threshold was crossed (this is intended) | Read which metric failed; tune the threshold or fix the regression |
| `BASE_URL is undefined` / requests to `undefined/...` | Forgot `-e BASE_URL=...` | Pass the env var on the command line |
| Grafana Cloud run rejected / capped | Free-tier VU or test-duration limit hit | Reduce VUs/duration or upgrade the Grafana Cloud plan |

## See also

- [cloudflare-pages.md](cloudflare-pages.md) — where `<project>.pages.dev` comes from.
- [cloudflare.md](cloudflare.md) — CF edge behavior, the 522/timeout boundary on the OAuth worker.
- [visual-regression.md](visual-regression.md) — the other testing runbook in this repo.
