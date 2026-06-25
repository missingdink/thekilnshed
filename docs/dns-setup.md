# DNS Setup for Cloudflare Pages

Choosing where to host DNS records for a site deployed on Cloudflare Pages. Two viable paths; this doc covers both.

## Decision: DNS at Cloudflare vs external provider

| Aspect | DNS at Cloudflare | DNS at external (DNSimple, etc.) |
| --- | --- | --- |
| Apex (`example.com`) on CF Pages | yes (CF flattens CNAME at apex) | no (CF Pages refuses apex without CF DNS) |
| `www.example.com` on CF Pages | yes | yes |
| CF Page Rules / Redirect Rules | yes | no (zone not on CF) |
| Migration cost | nameserver change at registrar | none |
| Ongoing cost | free | typically paid (DNSimple ~$5/mo) |
| Existing automations + tooling (`dnsimple` CLI, Terraform, etc.) | rebuild for CF | unchanged |
| Apex → www redirect | CF Redirect Rule (1 click) | DNSimple URL record (1 record) |

**Recommendation:** keep DNS at external provider unless you specifically need CF Page Rules or CF zone-level WAF. The CNAME-only path covers ~95% of marketing-site needs.

## Path A: DNS stays at external provider (DNSimple)

When to use:

- Existing zone in DNSimple you don't want to migrate
- Other records (mail, Heroku staging, etc.) already work
- Don't need CF zone-level features

### Steps

1. **Add CNAME for www** at DNSimple:

   ```sh
   dnsimple zones records create example.com \
     --type=CNAME --name=www \
     --content=<project>.pages.dev --ttl=3600
   ```

2. **Attach `www.example.com` to CF Pages**:

   CF dashboard → Workers & Pages → your project → Custom domains → Set up custom domain → enter `www.example.com`. CF detects the CNAME, marks status "Verifying" → "Active". SSL provisions automatically.

   CF will **not** trigger a DNS migration prompt for a www-only CNAME setup.

3. **Add apex redirect via DNSimple URL record**:

   First, remove any conflicting ALIAS/A record on the apex (DNSimple won't let URL records coexist with ALIAS on the same name):

   ```sh
   dnsimple zones records list example.com | grep -E "ALIAS|^[0-9]+\s+A\s"
   dnsimple zones records delete example.com <ID> --yes
   ```

   Then add the URL redirect:

   ```sh
   dnsimple zones records create example.com \
     --type=URL --name='' \
     --content='https://www.example.com' --ttl=3600
   ```

   DNSimple's edge servers handle the HTTP 301 from apex → www. No CF involvement for apex traffic.

4. **Verify**:

   ```sh
   dig +short www.example.com               # → CF IPs (172.66.x.x)
   curl -sI http://example.com/ | head -5   # → HTTP 301, Location: https://www.example.com/
   curl -sI https://www.example.com/        # → HTTP 200, server: cloudflare
   ```

## Path B: DNS moves to Cloudflare

When to use:

- Want apex (`example.com`) on CF Pages directly
- Want CF Page Rules or Redirect Rules at zone level
- Want CF WAF, Bot Fight Mode, etc.

### Steps

1. **Add site to CF**: dashboard → Websites → Add a Site → enter `example.com` → CF scans existing DNS → presents records for review.

2. **Verify imported records**: CF shows what it found. Confirm critical records (MX, staging CNAMEs, etc.) are present. Add anything missing manually.

3. **Get CF nameservers**: CF assigns 2 (e.g. `bjorn.ns.cloudflare.com`, `susan.ns.cloudflare.com`).

4. **Change nameservers at DNSimple** (via UI; CLI doesn't expose this):

   - DNSimple dashboard → domain → Name servers → switch from "DNSimple" to "Custom" → paste CF NS values

   CF can take up to 24h to verify, but typically completes in minutes.

5. **Attach domains to CF Pages**: dashboard → Pages project → Custom domains → add both `example.com` and `www.example.com`.

6. **Apex → www redirect**: dashboard → Rules → Redirect Rules → Create:

   - Match: `hostname equals example.com`
   - Then: 301 → `https://www.example.com${http.request.uri}`
   - Preserve query string

## Common gotchas

| Symptom | Cause | Fix |
| --- | --- | --- |
| CF says "to add this domain, transfer DNS to Cloudflare" | Trying to add apex on CF Pages while DNS is elsewhere | Add only `www.<domain>` (CNAME setup); use Path A for apex |
| `HTTP/1.1 409 Conflict` from DNSimple apex | Stale edge state during URL record propagation | Wait 60s, retry |
| DNSimple won't let URL record coexist with ALIAS | URL + ALIAS on same name not permitted | Delete ALIAS first (`--yes` flag required) |
| DNS resolves to old host | DNS cache (browser, OS, ISP) | `dig @1.1.1.1 <domain>` bypasses caches; clear browser DNS cache (chrome://net-internals) |
| CF Pages custom domain stuck "Verifying" | DNS record mismatch or slow propagation | `dig +short <domain>` to confirm record points correctly |
| SSL cert pending | Pages waiting on DNS verification | Wait; CF issues Universal SSL automatically once verified |
| Apex 200 instead of 301 | URL record not yet propagated, or ALIAS still active | Re-check DNSimple record list; ensure ALIAS removed |

## Local diagnostics

```sh
# Resolve via different resolvers (catches caching issues)
dig +short example.com @1.1.1.1   # Cloudflare resolver
dig +short example.com @8.8.8.8   # Google resolver
dig +short example.com @9.9.9.9   # Quad9 resolver

# Trace authoritative server for a name
dig +trace example.com

# Check what record type CF Pages sees
curl -sI https://www.example.com/ | grep -i "server\|cf-ray"

# DNSimple zone audit
dnsimple zones records list example.com
```

## When to migrate later

You can always migrate from Path A → Path B later. Process:

1. Export current DNSimple records (CLI or UI)
2. Add site to CF (Path B step 1-2)
3. Verify CF imported everything
4. Switch nameservers at DNSimple
5. After 24h, delete records from DNSimple (zone becomes inert but billed)
6. Optionally drop DNSimple plan for the domain

Reverse (CF → DNSimple) is the same process flipped.
