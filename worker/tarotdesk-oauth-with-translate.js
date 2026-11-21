// TarotDesk Google-login backend — Cloudflare Worker (free tier) + D1.
//
// Replaces the old GitHub OAuth proxy. Google login flow:
//   1. App redirects the user to accounts.google.com (Web Application Flow).
//   2. Google redirects back to the app with ?code=.
//   3. App POSTs {code, redirect_uri} to this Worker at /google-token.
//   4. Worker exchanges the code for tokens server-side (the client
//      secret never leaves the Worker), verifies the id_token signature
//      against Google's JWKS, mints a session token, stores it in D1.
//   5. App calls the other endpoints with Authorization: Bearer <token>.
//
// Storage: D1 database "tarotdesk-data", binding "DB" (see schema.sql).
// No KV — KV writes are capped at 1,000/day on the free tier.
// Admin = orenji11299@gmail.com (checked by email, not by sub).
//
// SECURITY NOTES
// - The client secret lives only as the Worker secret GOOGLE_CLIENT_SECRET
//   (env.GOOGLE_CLIENT_SECRET). It is never written as a literal here,
//   never logged, never returned to any caller.
// - No console.log of tokens, codes, secrets, or user data anywhere.
// - CORS is restricted to the TarotDesk origins below.
// - Error responses use short readable codes; raw Google error bodies
//   are never forwarded to the client.

const CLIENT_ID =
  '123408820943-7jqa6sqoncp591485d2uo9euumvnlpii.apps.googleusercontent.com';
const ADMIN_EMAIL = 'orenji11299@gmail.com';
const SESSION_TTL_MS = 30 * 24 * 60 * 60 * 1000; // 30 days

const ALLOWED_ORIGINS = [
  'https://neito112.github.io',
  'http://localhost:8080',
  'http://localhost:3000',
];

const TOKEN_URL = 'https://oauth2.googleapis.com/token';
const JWKS_URL = 'https://www.googleapis.com/oauth2/v3/certs';

// JWKS cache (module-level; survives warm invocations).
let cachedJwks = null;
let cachedJwksAt = 0;
const JWKS_TTL_MS = 60 * 60 * 1000; // 1 hour

function corsHeaders(origin) {
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Access-Control-Max-Age': '86400',
    Vary: 'Origin',
  };
}

function json(origin, status, obj) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) },
  });
}

function randomId(bytes = 32) {
  // crypto.getRandomValues, hex-encoded (64 chars for 32 bytes).
  const arr = new Uint8Array(bytes);
  crypto.getRandomValues(arr);
  return [...arr].map((b) => b.toString(16).padStart(2, '0')).join('');
}

function b64urlDecode(str) {
  // Base64url -> Uint8Array (no padding in JWT segments).
  const b64 = str.replace(/-/g, '+').replace(/_/g, '/');
  const padded = b64 + '='.repeat((4 - (b64.length % 4)) % 4);
  const bin = atob(padded);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

function b64urlDecodeJson(str) {
  return JSON.parse(new TextDecoder().decode(b64urlDecode(str)));
}

async function getJwks() {
  const now = Date.now();
  if (cachedJwks && now - cachedJwksAt < JWKS_TTL_MS) return cachedJwks;
  const res = await fetch(JWKS_URL);
  if (!res.ok) throw new Error('jwks_fetch_failed');
  cachedJwks = await res.json();
  cachedJwksAt = now;
  return cachedJwks;
}

// Verify a Google id_token (RS256) and return its payload, or throw.
async function verifyIdToken(idToken) {
  const parts = idToken.split('.');
  if (parts.length !== 3) throw new Error('bad_id_token');
  const header = b64urlDecodeJson(parts[0]);
  const payload = b64urlDecodeJson(parts[1]);
  const signature = b64urlDecode(parts[2]);

  const jwks = await getJwks();
  const jwk = (jwks.keys || []).find((k) => k.kid === header.kid);
  if (!jwk) throw new Error('unknown_key');

  const key = await crypto.subtle.importKey(
    'jwk',
    jwk,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['verify'],
  );
  const data = new TextEncoder().encode(parts[0] + '.' + parts[1]);
  const ok = await crypto.subtle.verify('RSASSA-PKCS1-v1_5', key, signature, data);
  if (!ok) throw new Error('bad_signature');

  // Claims checks.
  if (payload.iss !== 'https://accounts.google.com' && payload.iss !== 'accounts.google.com') {
    throw new Error('bad_issuer');
  }
  if (payload.aud !== CLIENT_ID) throw new Error('bad_audience');
  if (typeof payload.exp !== 'number' || payload.exp * 1000 <= Date.now()) {
    throw new Error('token_expired');
  }
  if (!payload.sub || !payload.email) throw new Error('missing_claims');
  return payload;
}

// Auth helper: Bearer session token -> session row, or null.
async function getSession(env, request) {
  const auth = request.headers.get('Authorization') || '';
  const m = auth.match(/^Bearer\s+(.+)$/i);
  if (!m) return null;
  const row = await env.DB.prepare(
    'SELECT token, google_sub, email, name, picture, expires_at, created_at FROM sessions WHERE token = ? AND expires_at > ?',
  )
    .bind(m[1], Date.now())
    .first();
  return row || null;
}

async function readJsonBody(request) {
  try {
    return await request.json();
  } catch {
    return null;
  }
}

// Parse a stored shared_decks / submissions deck_json ({"deck":...,"cards":...})
// into the public entry shape {id, name, deck, cards, ...extra}.
function deckEntry(row, extra = {}) {
  let parsed = {};
  try {
    parsed = JSON.parse(row.deck_json);
  } catch {
    parsed = {};
  }
  return {
    id: row.id,
    name: row.name || (parsed.deck && parsed.deck.name) || '',
    deck: parsed.deck || {},
    cards: parsed.cards || [],
    ...extra,
  };
}

// =====================================================================
// POST /translate — translated deck/card content (names + meanings).
// Merged from translate-route.js into this Worker. Engines, in order:
//   1. Workers AI `@cf/meta/m2m100-1.2b` (env.AI binding) — primary.
//   2. Google Cloud Translation v2 — fallback only, key read from the
//      Worker secret env.GOOGLE_TRANSLATE_API_KEY (not set for this
//      deploy, so Workers-AI-only); unset means the fallback is skipped.
//   3. Neither available -> the original text is returned with
//      `translated: false`. Nothing ever 500s for a translation miss.
// Cache: D1 table `translations`, keyed by (sha256(source text),
// source_lang, target_lang). One translation serves every user.
// Caps: signed-in (valid Bearer session) 100 texts / 40,000 chars;
// anonymous 20 texts / 8,000 chars per request.
// =====================================================================

const MODEL = '@cf/meta/m2m100-1.2b';
const MAX_SEGMENT_CHARS = 800;

// Per-request caps. A 78-card base deck is ~60k chars per
// language, but it is never sent in one request: the client
// warms it in batches of 20 strings.
const LIMITS = {
  authed: { texts: 100, chars: 40000 },
  anon: { texts: 20, chars: 8000 },
};

async function sha256Hex(text) {
  const data = new TextEncoder().encode(text);
  const hash = await crypto.subtle.digest('SHA-256', data);
  return [...new Uint8Array(hash)]
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

function segmentText(text) {
  const segments = [];
  for (const paragraph of text.split('\n')) {
    const trimmed = paragraph.trim();
    if (!trimmed) {
      segments.push('');
      continue;
    }
    if (trimmed.length <= MAX_SEGMENT_CHARS) {
      segments.push(trimmed);
      continue;
    }
    const sentences = trimmed.split(/(?<=[.!?…])\s+/);
    let current = '';
    for (const sentence of sentences) {
      if (!current) current = sentence;
      else if (current.length + 1 + sentence.length <= MAX_SEGMENT_CHARS) {
        current += ' ' + sentence;
      } else {
        segments.push(current);
        current = sentence;
      }
    }
    if (current) segments.push(current);
  }
  while (segments.length > 1 && segments[segments.length - 1] === '') {
    segments.pop();
  }
  return segments.length ? segments : [text];
}

async function translateWithWorkersAI(env, text, sourceLang, targetLang) {
  if (!env.AI) return null; // AI binding not configured.
  const res = await env.AI.run(MODEL, {
    text,
    source_lang: sourceLang,
    target_lang: targetLang,
  });
  const out = res && res.translated_text ? String(res.translated_text).trim() : '';
  return out || null; // Empty output counts as a miss, not a translation.
}

// Google Cloud Translation v2. `texts` is an array of segments;
// `sourceLang` may be null (Google auto-detects, and the
// response reports the detected language per segment).
// Returns [{ text, detectedSource }] or null on any failure.
// The API key comes ONLY from the Worker secret env var.
async function translateWithGoogle(env, texts, sourceLang, targetLang) {
  const key = env.GOOGLE_TRANSLATE_API_KEY;
  if (!key) return null; // Fallback not configured — not an error.
  const body = { q: texts, target: targetLang, format: 'text' };
  if (sourceLang) body.source = sourceLang;
  const res = await fetch(
    `https://translation.googleapis.com/language/translate/v2?key=${encodeURIComponent(key)}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    },
  );
  if (!res.ok) return null;
  const json = await res.json();
  const list = json && json.data && json.data.translations;
  if (!Array.isArray(list) || list.length !== texts.length) return null;
  return list.map((t) => ({
    text: t.translatedText || '',
    detectedSource: t.detectedSourceLanguage || sourceLang || '',
  }));
}

async function handleTranslate(request, env, allowedOrigin) {
  if (request.method !== 'POST') {
    return json(allowedOrigin, 405, { error: 'Method not allowed.' });
  }

  let body;
  try {
    body = await request.json();
  } catch {
    return json(allowedOrigin, 400, { error: 'Invalid JSON body.' });
  }

  const texts = Array.isArray(body.texts)
    ? body.texts.filter((t) => typeof t === 'string')
    : [];
  const targetLang = typeof body.target_lang === 'string'
    ? body.target_lang.toLowerCase()
    : '';
  const sourceHint = typeof body.source_lang === 'string'
    ? body.source_lang.toLowerCase()
    : null;

  if (!texts.length) {
    return json(allowedOrigin, 400, { error: '`texts` must be a non-empty array.' });
  }
  if (!/^[a-z]{2,3}(-[a-z]{2,4})?$/.test(targetLang)) {
    return json(allowedOrigin, 400, { error: '`target_lang` must be a language code.' });
  }

  // Validate the Bearer session token against the `sessions`
  // table with the Worker's existing lookup (the one `/me`
  // uses). Anonymous callers (no token, or an invalid/expired
  // token) still work, at the lower anonymous cap.
  const session = await getSession(env, request);
  const authed = !!session;
  const limit = authed ? LIMITS.authed : LIMITS.anon;

  const totalChars = texts.reduce((n, t) => n + t.length, 0);
  if (texts.length > limit.texts || totalChars > limit.chars) {
    return json(allowedOrigin, 413, {
      error: `Too many texts: max ${limit.texts} texts / ${limit.chars} chars per request.`,
    });
  }
  if (sourceHint && sourceHint === targetLang) {
    // Nothing to translate — echo the originals.
    return json(allowedOrigin, 200, {
      translations: texts.map((t) => ({
        text: t,
        source_lang: sourceHint,
        translated: false,
        engine: 'none',
        cached: false,
      })),
    });
  }

  const results = [];
  // Per-text work list: each input text expands to segments.
  // Segments are cached individually in D1, so a long meaning
  // that shares a sentence with another card is translated once.
  for (const text of texts) {
    const segments = segmentText(text);
    const outSegments = [];
    let detectedSource = sourceHint || '';
    let anyTranslated = false;
    let anyCached = false;
    let engineUsed = 'none';

    for (const segment of segments) {
      if (!segment) {
        outSegments.push('');
        continue;
      }
      const sourceForModel = sourceHint || 'en'; // m2m100 default.
      const hash = await sha256Hex(segment);

      // 1. D1 cache (shared across all users).
      // NOTE: when the client sent no source hint, the cache key
      // uses 'en' (m2m100's default) — a text first translated
      // without a hint will not be found later under an explicit
      // source code, and vice versa. The client normally sends
      // its deck-level vote, so this only affects single
      // ambiguous strings; fixing it needs a real detector on
      // the Worker (see REPORT.md, open items).
      let cachedRow = null;
      if (env.DB) {
        try {
          cachedRow = await env.DB.prepare(
            'SELECT translated_text, engine FROM translations ' +
              'WHERE source_hash = ?1 AND source_lang = ?2 AND target_lang = ?3',
          )
            .bind(hash, sourceForModel, targetLang)
            .first();
        } catch {
          cachedRow = null; // Cache miss on error — translate anyway.
        }
      }
      if (cachedRow && cachedRow.translated_text) {
        outSegments.push(cachedRow.translated_text);
        anyCached = true;
        engineUsed = cachedRow.engine || 'cache';
        if (!detectedSource) detectedSource = sourceForModel;
        continue;
      }

      // 2. Workers AI (primary).
      let translated = null;
      let engine = 'none';
      try {
        translated = await translateWithWorkersAI(
          env,
          segment,
          sourceForModel,
          targetLang,
        );
        if (translated) engine = 'workers-ai';
      } catch {
        translated = null;
      }

      // 3. Google fallback (only when Workers AI missed AND the
      //    secret is configured). Sent as a 1-segment batch so
      //    its auto-detection applies to this segment.
      let googleDetected = '';
      if (!translated) {
        try {
          const google = await translateWithGoogle(
            env,
            [segment],
            sourceHint,
            targetLang,
          );
          if (google && google[0].text) {
            translated = google[0].text;
            googleDetected = google[0].detectedSource;
            engine = 'google';
          }
        } catch {
          translated = null;
        }
      }

      if (translated) {
        anyTranslated = true;
        engineUsed = engine;
        if (googleDetected) detectedSource = googleDetected;
        else if (!detectedSource) detectedSource = sourceForModel;
        outSegments.push(translated);
        // Store in the shared D1 cache (best-effort).
        if (env.DB) {
          try {
            await env.DB.prepare(
              'INSERT OR REPLACE INTO translations ' +
                '(source_hash, source_lang, target_lang, translated_text, engine, created_at) ' +
                'VALUES (?1, ?2, ?3, ?4, ?5, ?6)',
            )
              .bind(
                hash,
                sourceForModel,
                targetLang,
                translated,
                engine,
                new Date().toISOString(),
              )
              .run();
          } catch {
            // Cache write failure must not fail the translation.
          }
        }
      } else {
        // 4. No engine available: return the original segment.
        outSegments.push(segment);
      }
    }

    results.push({
      text: outSegments.join('\n'),
      source_lang: detectedSource,
      translated: anyTranslated,
      engine: anyTranslated ? engineUsed : 'none',
      cached: anyCached,
    });
  }

  return json(allowedOrigin, 200, { translations: results });
}

export default {
  async fetch(request, env, ctx) {
    const origin = request.headers.get('Origin') || '';
    const allowedOrigin = ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0];

    // Preflight.
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders(allowedOrigin) });
    }

    const url = new URL(request.url);
    const path = url.pathname;
    const method = request.method;
    const now = Date.now();

    // --- POST /google-token (public: code exchange + session mint) ---
    if (path === '/google-token' && method === 'POST') {
      const body = await readJsonBody(request);
      if (!body || typeof body.code !== 'string' || !body.code || typeof body.redirect_uri !== 'string' || !body.redirect_uri) {
        return json(allowedOrigin, 400, { error: 'invalid_request' });
      }

      // Exchange the authorization code for tokens (server-to-server).
      let tokenRes;
      try {
        tokenRes = await fetch(TOKEN_URL, {
          method: 'POST',
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          body: new URLSearchParams({
            client_id: CLIENT_ID,
            client_secret: env.GOOGLE_CLIENT_SECRET,
            code: body.code,
            redirect_uri: body.redirect_uri,
            grant_type: 'authorization_code',
          }).toString(),
        });
      } catch {
        return json(allowedOrigin, 502, { error: 'google_unreachable' });
      }
      const tokenData = await tokenRes.json().catch(() => null);
      if (!tokenRes.ok || !tokenData || !tokenData.id_token) {
        // invalid_grant (bad/expired/reused code) -> 400; anything else -> 502.
        // Never forward Google's raw error body.
        const code = tokenData && tokenData.error === 'invalid_grant' ? 'invalid_code' : 'token_exchange_failed';
        const status = tokenData && tokenData.error === 'invalid_grant' ? 400 : 502;
        return json(allowedOrigin, status, { error: code });
      }

      // Verify the id_token signature + claims.
      let payload;
      try {
        payload = await verifyIdToken(tokenData.id_token);
      } catch {
        return json(allowedOrigin, 401, { error: 'invalid_id_token' });
      }

      // Mint a session token and store it in D1.
      const sessionToken = randomId(32);
      const expiresAt = now + SESSION_TTL_MS;
      try {
        await env.DB.prepare(
          'INSERT INTO sessions (token, google_sub, email, name, picture, expires_at, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
        )
          .bind(sessionToken, payload.sub, payload.email, payload.name || null, payload.picture || null, expiresAt, now)
          .run();
      } catch {
        return json(allowedOrigin, 502, { error: 'session_store_failed' });
      }

      return json(allowedOrigin, 200, {
        session_token: sessionToken,
        user: {
          sub: payload.sub,
          email: payload.email,
          name: payload.name || '',
          picture: payload.picture || '',
        },
      });
    }

    // --- GET /shared-decks (public: no auth) ---
    if (path === '/shared-decks' && method === 'GET') {
      const { results } = await env.DB.prepare(
        'SELECT id, name, deck_json, created_by, created_at FROM shared_decks ORDER BY created_at DESC',
      ).all();
      return json(allowedOrigin, 200, (results || []).map((row) => deckEntry(row)));
    }

    // --- /translate (public: anonymous allowed at the lower cap; a valid
    // session raises the cap. handleTranslate returns 405 for non-POST.) ---
    if (path === '/translate') {
      return handleTranslate(request, env, allowedOrigin);
    }

    // --- All remaining endpoints require a valid session. ---
    const session = await getSession(env, request);
    if (!session) {
      return json(allowedOrigin, 401, { error: 'unauthorized' });
    }
    const isAdmin = session.email === ADMIN_EMAIL;

    // --- GET /me ---
    if (path === '/me' && method === 'GET') {
      return json(allowedOrigin, 200, {
        sub: session.google_sub,
        email: session.email,
        name: session.name || '',
        picture: session.picture || '',
        is_admin: isAdmin,
      });
    }

    // --- GET /data ---
    if (path === '/data' && method === 'GET') {
      const row = await env.DB.prepare('SELECT data_json FROM user_data WHERE google_sub = ?')
        .bind(session.google_sub)
        .first();
      if (!row) return json(allowedOrigin, 200, {});
      try {
        return json(allowedOrigin, 200, JSON.parse(row.data_json));
      } catch {
        return json(allowedOrigin, 200, {});
      }
    }

    // --- POST /data ---
    if (path === '/data' && method === 'POST') {
      const body = await readJsonBody(request);
      if (!body || typeof body !== 'object' || Array.isArray(body)) {
        return json(allowedOrigin, 400, { error: 'invalid_data' });
      }
      await env.DB.prepare(
        'INSERT INTO user_data (google_sub, email, data_json, updated_at) VALUES (?, ?, ?, ?) ' +
          'ON CONFLICT(google_sub) DO UPDATE SET email = excluded.email, data_json = excluded.data_json, updated_at = excluded.updated_at',
      )
        .bind(session.google_sub, session.email, JSON.stringify(body), now)
        .run();
      return json(allowedOrigin, 200, { ok: true });
    }

    // --- POST /submit-deck ---
    if (path === '/submit-deck' && method === 'POST') {
      const body = await readJsonBody(request);
      if (!body || typeof body.deck !== 'object' || !Array.isArray(body.cards)) {
        return json(allowedOrigin, 400, { error: 'invalid_deck' });
      }
      const id = randomId(16);
      await env.DB.prepare(
        'INSERT INTO submissions (id, google_sub, email, deck_json, status, created_at) VALUES (?, ?, ?, ?, ?, ?)',
      )
        .bind(id, session.google_sub, session.email, JSON.stringify({ deck: body.deck, cards: body.cards }), 'pending', now)
        .run();
      return json(allowedOrigin, 200, { id });
    }

    // --- Admin endpoints (admin email only) ---
    if (path.startsWith('/admin/')) {
      if (!isAdmin) {
        return json(allowedOrigin, 403, { error: 'forbidden' });
      }

      // GET /admin/submissions — pending first.
      if (path === '/admin/submissions' && method === 'GET') {
        const { results } = await env.DB.prepare(
          "SELECT id, google_sub, email, deck_json, status, created_at FROM submissions ORDER BY CASE WHEN status = 'pending' THEN 0 ELSE 1 END, created_at DESC",
        ).all();
        return json(
          allowedOrigin,
          200,
          (results || []).map((row) => ({
            ...deckEntry(row),
            google_sub: row.google_sub,
            email: row.email,
            status: row.status,
            created_at: row.created_at,
          })),
        );
      }

      // POST /admin/approve {id} — approve + publish to shared_decks.
      if (path === '/admin/approve' && method === 'POST') {
        const body = await readJsonBody(request);
        if (!body || typeof body.id !== 'string' || !body.id) {
          return json(allowedOrigin, 400, { error: 'invalid_request' });
        }
        const sub = await env.DB.prepare(
          'SELECT id, google_sub, email, deck_json, status, created_at FROM submissions WHERE id = ?',
        )
          .bind(body.id)
          .first();
        if (!sub) return json(allowedOrigin, 404, { error: 'not_found' });
        let parsed = {};
        try {
          parsed = JSON.parse(sub.deck_json);
        } catch {
          parsed = {};
        }
        const sharedId = randomId(16);
        await env.DB.prepare(
          'INSERT INTO shared_decks (id, name, deck_json, created_by, created_at) VALUES (?, ?, ?, ?, ?)',
        )
          .bind(sharedId, (parsed.deck && parsed.deck.name) || '', sub.deck_json, sub.email, now)
          .run();
        await env.DB.prepare("UPDATE submissions SET status = 'approved' WHERE id = ?")
          .bind(body.id)
          .run();
        return json(allowedOrigin, 200, { ok: true });
      }

      // POST /admin/reject {id}
      if (path === '/admin/reject' && method === 'POST') {
        const body = await readJsonBody(request);
        if (!body || typeof body.id !== 'string' || !body.id) {
          return json(allowedOrigin, 400, { error: 'invalid_request' });
        }
        const res = await env.DB.prepare("UPDATE submissions SET status = 'rejected' WHERE id = ?")
          .bind(body.id)
          .run();
        if (!res.meta || res.meta.changes === 0) {
          return json(allowedOrigin, 404, { error: 'not_found' });
        }
        return json(allowedOrigin, 200, { ok: true });
      }

      // POST /admin/delete-shared-deck {id}
      if (path === '/admin/delete-shared-deck' && method === 'POST') {
        const body = await readJsonBody(request);
        if (!body || typeof body.id !== 'string' || !body.id) {
          return json(allowedOrigin, 400, { error: 'invalid_request' });
        }
        const res = await env.DB.prepare('DELETE FROM shared_decks WHERE id = ?')
          .bind(body.id)
          .run();
        if (!res.meta || res.meta.changes === 0) {
          return json(allowedOrigin, 404, { error: 'not_found' });
        }
        return json(allowedOrigin, 200, { ok: true });
      }

      // GET /admin/shared-decks
      if (path === '/admin/shared-decks' && method === 'GET') {
        const { results } = await env.DB.prepare(
          'SELECT id, name, deck_json, created_by, created_at FROM shared_decks ORDER BY created_at DESC',
        ).all();
        return json(
          allowedOrigin,
          200,
          (results || []).map((row) => ({
            ...deckEntry(row),
            created_by: row.created_by || '',
            created_at: row.created_at,
          })),
        );
      }
    }

    // --- Unknown path/method ---
    return json(allowedOrigin, 404, { error: 'not_found' });
  },
};
