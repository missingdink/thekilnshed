// Decap CMS GitHub OAuth proxy for Cloudflare Workers.
// Two routes: /auth (start OAuth dance), /callback (exchange code, postMessage token).

const STATE_COOKIE = "decap_oauth_state";
const STATE_TTL_SECONDS = 600;

async function hmac(secret, message) {
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    enc.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign", "verify"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, enc.encode(message));
  return Array.from(new Uint8Array(sig))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

function csvList(v) {
  return (v || "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
}

function originAllowed(origin, allowed) {
  if (!origin) return false;
  return allowed.some((entry) => entry === origin);
}

function repoAllowed(repo, allowed) {
  if (!repo) return false;
  return allowed.includes(repo);
}

function setStateCookie(state) {
  return `${STATE_COOKIE}=${state}; Path=/; HttpOnly; Secure; SameSite=Lax; Max-Age=${STATE_TTL_SECONDS}`;
}

function readStateCookie(req) {
  const cookie = req.headers.get("Cookie") || "";
  const match = cookie.match(new RegExp(`${STATE_COOKIE}=([^;]+)`));
  return match ? match[1] : null;
}

function responsePage(message) {
  // Decap's OAuth handshake:
  //   1. Popup posts 'authorizing:github' to opener
  //   2. Opener replies with same string (echoing its origin in the message event)
  //   3. Popup posts 'authorization:github:success:<json>' targeting that origin
  return new Response(
    `<!doctype html><html><body><script>
       (function(){
         var msg = ${JSON.stringify(message)};
         function receiveMessage(e) {
           if (!window.opener) return;
           window.opener.postMessage(
             'authorization:github:success:' + JSON.stringify(msg),
             e.origin
           );
           window.removeEventListener('message', receiveMessage, false);
           setTimeout(function(){ window.close(); }, 100);
         }
         window.addEventListener('message', receiveMessage, false);
         if (window.opener) {
           window.opener.postMessage('authorizing:github', '*');
         }
       })();
     </script></body></html>`,
    { headers: { "content-type": "text/html; charset=utf-8" } },
  );
}

function errorPage(msg) {
  return new Response(
    `<!doctype html><html><body><pre>${msg}</pre></body></html>`,
    { status: 400, headers: { "content-type": "text/html; charset=utf-8" } },
  );
}

export default {
  async fetch(req, env) {
    const url = new URL(req.url);
    const allowedOrigins = csvList(env.ALLOWED_ORIGINS);
    const allowedRepos = csvList(env.ALLOWED_REPOS);

    if (url.pathname === "/auth") {
      const origin = req.headers.get("Origin") || req.headers.get("Referer");
      const originHost = origin ? new URL(origin).origin : null;
      if (!originAllowed(originHost, allowedOrigins)) {
        return errorPage(`Origin not allowed: ${originHost || "(none)"}`);
      }
      const nonce = crypto.randomUUID();
      const sig = await hmac(env.WORKER_SECRET, nonce);
      const state = `${nonce}.${sig}`;
      const ghUrl = new URL("https://github.com/login/oauth/authorize");
      ghUrl.searchParams.set("client_id", env.OAUTH_GITHUB_CLIENT_ID);
      ghUrl.searchParams.set("scope", "repo,user");
      ghUrl.searchParams.set("state", state);
      ghUrl.searchParams.set("redirect_uri", `${url.origin}/callback`);
      return new Response(null, {
        status: 302,
        headers: {
          Location: ghUrl.toString(),
          "Set-Cookie": setStateCookie(state),
        },
      });
    }

    if (url.pathname === "/callback") {
      const code = url.searchParams.get("code");
      const state = url.searchParams.get("state");
      const cookieState = readStateCookie(req);
      if (!code || !state || state !== cookieState) {
        return errorPage("Invalid OAuth state.");
      }
      const [nonce, sig] = state.split(".");
      const expected = await hmac(env.WORKER_SECRET, nonce);
      if (expected !== sig) return errorPage("State signature mismatch.");

      const tokenRes = await fetch("https://github.com/login/oauth/access_token", {
        method: "POST",
        headers: { "content-type": "application/json", accept: "application/json" },
        body: JSON.stringify({
          client_id: env.OAUTH_GITHUB_CLIENT_ID,
          client_secret: env.OAUTH_GITHUB_CLIENT_SECRET,
          code,
        }),
      });
      const tokenJson = await tokenRes.json();
      if (!tokenJson.access_token) {
        return errorPage(`GitHub did not return a token: ${JSON.stringify(tokenJson)}`);
      }

      if (allowedRepos.length === 0) {
        return errorPage("ALLOWED_REPOS not configured.");
      }

      return responsePage({ provider: "github", token: tokenJson.access_token });
    }

    return new Response("Not found", { status: 404 });
  },
};
