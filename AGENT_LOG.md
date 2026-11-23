# TarotDesk — Agent Log

> A detailed, agent-readable log of what has been built for this project, the
> decisions behind it, the current state, and what is still open. Read this
> first before touching the repo. It is the project's memory; keep it updated
> when you land a meaningful change.
>
> Last updated: 2026-11-22 (main HEAD `026c0a6`, PR #44 merged; V2 permanent translations LIVE and verified).
> Language note: the app UI is Vietnamese-first (plus EN/ZH/KO/JA). This log
> is written in English so any agent can read it; Vietnamese proper nouns,
> user quotes and UI strings are kept verbatim.
>
> If you are an outside agent (ChatGPT, Claude, another Muse, etc.) and this
> is your first time here, start at **Section 0** below. It tells you what
> the project is, where the truth lives, and how to take over.

---

## 0. FOR A NEW AGENT — START HERE (how to take over)

Read this section first. It is the whole takeover in one page. The rest of
this file is the evidence behind it.

### 0.1 What this project is (3 sentences)

TarotDesk is a Flutter web app (Dart, `tarot_desk_flutter/`) that stores,
organises and practises with tarot decks — it is a storage/practice tool,
NOT auto-interpretation or divination, and the user still needs a physical
deck. It runs as a static site on GitHub Pages at
https://neito112.github.io/TarotDesk/ (the URL never changes), with a
Cloudflare Worker + D1 backend for Google login, per-account cloud sync,
shared decks and deck submissions. The repo is `Neito112/TarotDesk`
(public, default branch `main`); the `TarotDesk/` MAUI C#/XAML version is
old and abandoned — never touch it.

### 0.2 The single source of truth

- **This file** (`AGENT_LOG.md` at the repo root) is the source of truth
  for project status, decisions, and open work. Read it fully before
  changing anything, and update it when you land a meaningful change.
- **Main HEAD is `026c0a6`** (PR #44 merged 2026-11-22). If `main` has
  moved past that, the log is stale — re-derive the state from the PR
  history (§4) and the live preview before trusting anything else.
- **The live preview** (https://neito112.github.io/TarotDesk/) is the
  other source of truth: a claim is only "done" when it is visible there
  (see §0.6). The repo `README.md` is a product introduction for humans,
  not a status record — do not use it to judge progress.
- A separate, unrelated project (teaching slide decks for an
  interior-design class) lives in a **different side chat**, not in this
  repo. Its rules are NOT TarotDesk rules — see the separation box in §6.
  Do not import them here.

### 0.3 How to work on it

1. **Build locally first.** Work in a workspace directory (e.g.
   `~/workspace/tarotdesk-<topic>/out/`) with complete files. There is
   **no Flutter/Dart toolchain in this VM**, so pre-push verification is
   static only: `tr()` key completeness across all 5 languages (vi/en/
   zh/ko/ja), bracket balance, no leftover references to removed code.
   The GitHub Actions build is the real compile check.
2. **Push through the user's own GitHub session in Chrome.** The Muse
   GitHub App integration returns **403 on contents writes** — never use
   the GitHub MCP write tools. Code changes go via a browser task with
   `browser: "device"` (device Chrome is signed in as Neito112, no login
   needed; new tasks default to the CLOUD browser, which is NOT signed
   in). Files are passed via the `browser.browse` `files` parameter with
   each file's repo path as its purpose. A browser task's upload tool ONLY
   accepts files granted to that task via `files` — it cannot save page
   screenshots as PNGs and cannot put local paths into GitHub's file
   picker. GitHub MCP reads work (flag is `--arguments-json`, NOT
   `--args`); for file CONTENTS use raw.githubusercontent.com via curl.
3. **One branch per change, one PR, merge commit.** Branch from `main`
   (`ui/<short-slug>` or `docs/<short-slug>`), open a PR, merge with a
   **merge commit** (not squash, not rebase), watch the GitHub Actions
   "Flutter Web Preview" run — it must SUCCEED. If a run fails only at
   `deploy-pages` with "Found 0 artifact(s)", re-run the failed deploy
   job once. If it fails at the flutter build step, read the exact
   build-log errors first — never re-run blindly and never guess a fix.
4. **Verify live on the preview.** Fresh tab + a cache-busting URL
   (`?v=...`) + reload (Flutter web's service worker caches aggressively;
   sometimes ALL github.io tabs must be closed first). Verification
   standard is 1375×847, DevTools closed; the automated Chrome window is
   fixed at ~1173×855 and DevTools/device emulation will NOT open.
   Phone-specific visuals can ONLY be checked on the user's real phone.
5. **Leave it clean.** After verification, leave the app LOGGED OUT on
   the login screen, no test data in the user's deck (library stays only
   "Bộ bài cơ bản", 78 cards), no test readings saved, music paused, and
   the user's saved state intact (cloth Thảm Đen, decor Đá Thạch Anh +
   Hương Trầm, table Gỗ Sồi, theme Tối Obsidian, all 3 layer toggles ON,
   language vi). Logout must not delete local data.
6. **Delete your branch after its PR merges.** (2026-11-21 cleanup:
   38 merged branches deleted; only `main` + in-flight branches remain.)
   Update this log and `~/MEMORY.md` with durable facts when you land a
   meaningful change.

### 0.4 Five rules that must never be broken

1. **Never re-attempt the Android native build.** The user asked for it
   once (2026-11-21 09:17); it was declined and must not be continued —
   not by delegating again, rephrasing, using a tool/helper, or answering
   from your own knowledge. If the user asks again in any wording,
   concisely decline and suggest another topic. The project is web-only
   (no `android/` folder, no Flutter SDK in the VM). See §8.
2. **Never write to GitHub via the GitHub MCP/App tools (403).** All code
   changes go through the user's own GitHub session in Chrome (device
   browser). See §0.3 step 2 and §9.3.
3. **Card names + meanings MUST be translated to the active language —
   and never hand-translated.** The old rule "meanings stay Vietnamese"
   is WRONG (user correction 2026-11-21 15:48, superseding PR #29). Deck
   content arriving in any language is normalised to the system language
   through the server-side machine-translation mechanism (Worker +
   D1 cache, source never overwritten). See §6 and §9.2.
4. **Never put cards on the reading table, and never use flat icons for
   decor.** The table is only space (wood, cloth, decor, deck stack); the
   tray holds ALL drawn cards and the screen shows one card. "3D" means a
   painted 3D illustration, NOT a real-time 3D engine. Cloth + accessories
   must be drawn in the SAME painted style as the wood table and must HUG
   the table surface. If something is wrong, delete it outright and
   redraw it exactly per the description — do not guess at a fix. See §6.
5. **Never pitch scheduled/recurring features, and never bring
   non-TarotDesk work into the main chat.** The user turned scheduled
   features down flat. The main chat is TarotDesk ONLY (user boundary
   2026-11-21 08:53). Do not scan Gmail or act inside Gmail/GitHub/
   Canva/WhatsApp until the user explicitly asks.

### 0.5 Where the open work is

See **§7 Open work**. As of this writing the live items are: (1) the
decor-toggle fix (selecting incense alone does not auto-enable "Hiện đồ
decor"; deselecting all leaves it ON) — fix built locally, being pushed
in the combined PR; (2) guide slide 3 `home-crop.png` was never
uploaded — the annotated crop is built, being pushed in the same PR;
(3) this log itself was stale (PR #43–#44 + V2) — this update fixes it,
also in the same PR; (4) 11 guide screenshots still placeholders; (5)
publishing the Google OAuth app (still "Testing", 2 test users only);
(6) the Google Translate fallback key (`GOOGLE_TRANSLATE_API_KEY`) is
still not set, so m2m100 quality issues remain ("You stupid.",
"Three sticks"). The old top item — POST `/translate` hanging — is
RESOLVED (it was an ~85 s m2m100 cold start, then a Worker cache bug;
both fixed, and V2 permanent translations supersede the on-demand
path). Start there.

### 0.6 What "done" means here

A change is done only when ALL three hold: (a) merged to `main` with a
merge commit; (b) the GitHub Actions "Flutter Web Preview" run for the
merge commit SUCCEEDED; (c) verified LIVE on the preview (fresh tab +
`?v=...`) — the feature works by tapping through it, and the regression
pass (Home, reading draw, language switch, donation QR) shows no raw keys
and no breakage. A build that only passed Actions, or a file that was
only written locally, is NOT done. Say plainly what is unverified.

---

## 1. Project overview

- **Repo:** `Neito112/TarotDesk` (public, default branch `main`).
- **App:** `tarot_desk_flutter/` — Flutter/Dart web app (provider + sqflite).
  The `TarotDesk/` MAUI C#/XAML version is old/abandoned — never touch it.
- **Live preview (never changes):** https://neito112.github.io/TarotDesk/
  Built by `.github/workflows/flutter-web-preview.yml` on every push to `main`
  (`flutter build web --release --base-href /TarotDesk/`). Branch pushes do
  not rebuild it. `?v=...` suffixes are only cache-busting for verification.
- **Usage guide (live):** https://neito112.github.io/TarotDesk/guide/ —
  15-slide HyperFrames-style HTML deck (`tarot_desk_flutter/web/guide/`),
  linked from the ⓘ About screen ("Hướng dẫn chi tiết", opens in an
  external browser). See §2/§7 for its screenshot status.
- **Repo README:** `README.md` at the repo root is a Vietnamese product
  introduction (rewritten in PR #38). It is NOT a status record — this
  log is. Note: the README on main used to say card meanings stay in
  Vietnamese; that line was WRONG (user correction 2026-11-21 15:48) and
  was fixed in PR #41 (line 33 now says card names + meanings are
  translated to the active language via server-side MT, with a cache;
  the original text is never changed).
- **Purpose:** a tarot practice/storage tool (NOT auto-interpretation or
  divination). The user needs a physical deck; the app stores decks, draws
  cards, keeps reading history. Primary platform is Android phone, with iPad
  and PC in parallel; layout is mobile-first and adaptive.
- **Owner / admin:** GitHub `Neito112`; admin Google account
  `orenji11299@gmail.com` (the Neito112 GitHub account's email). The
  Google Cloud + Cloudflare account owner is a different email,
  `thewolverineking@gmail.com` — that is NOT the admin. Do not confuse
  them.

## 2. Current state (2026-11-22, main `026c0a6`)

- Main HEAD is `026c0a6` (merge of PR #44, V2 permanent translations).
  The last Actions run (#46, a fresh `workflow_dispatch` run) succeeded
  (2m1s) after run #45 failed at `deploy-pages` (first "Found 0
  artifact(s)", then "Found 2 artifact(s)" after a job re-run duplicated
  the upload — see §3.1). The live preview serves the V2 build.
- **What works:** Home (Daily Card, new reading), reading screen (painted
  3D table, flat changeable cloth, changeable decor, deck stack, stage +
  tray, draw/collect flights, smoke, mystic music incl. YouTube links),
  library / add-deck / edit-card, history, settings (theme, cloth, decor,
  language), About + donation QR + guide link, i18n UI (vi/en/zh/ko/ja),
  guest mode, **Google login (LIVE, see §5)** with per-account cloud sync
  and an admin screen.
- **Google login is LIVE.** The app opens on a login screen with
  "Đăng nhập bằng Google" + "Dùng offline" (guest). Signed-in users sync
  decks + history per account via the Worker/D1 backend; the admin
  (`orenji11299@gmail.com`) sees an admin icon (middle of the three
  Home header icons — it looks like a server, not a shield) opening
  the "Quản trị máy chủ" screen (live-verified 2026-11-22: both lists
  empty — 0 submissions, 0 shared decks). Shared decks start EMPTY in v1 (no seed from
  `server/decks/`). OAuth app is still "Testing" — only the 2 test users
  can sign in until it is published (see §7.6).
- **Data:** local sqflite (`tarot_desk.db`, version 5) is the offline
  store; signed-in users also sync to D1 via the Worker (same JSON shape,
  download imports only missing items and NEVER deletes local data).
  **Sync is AUTOMATIC and two-way, and runs ONLY on login and on page
  reload** (user decision 2026-11-21 23:53, corrected 2026-11-22 00:00);
  the manual "Đồng bộ ngay" (Sync now) button was REMOVED in PR #44
  (4 i18n keys deleted, 263 → 259 keys/language). Background translation
  (dịch ngầm) is separate and DOES run on create/edit/delete (the V2
  write-time model). Guest mode works fully offline and is NOT persisted
  across reloads.
- **Daily Card is per account (LIVE since PR #39, verified).** Seed =
  FNV-1a hash of `account:<Google sub>` (fallback email) + full date
  `yyyy-MM-dd`; guests get a persisted per-device UUID in
  SharedPreferences. Live-verified 2026-11-21: admin `orenji11299@gmail.com`
  → Bảy Cốc (Seven of Cups), `thewolverineking@gmail.com` → Ba Gậy
  (Three of Wands), guest → Chín Gậy (Nine of Wands) — all three different
  on the same day. Midnight rollover via the 1-minute timer is unchanged.
- **Card content language (on main, V2 LIVE since PR #44):** translations
  are PERMANENT DATA, not a cache (user correction 2026-11-21 23:17):
  admin translations are stored permanently in the shared data, non-admin
  translations are that account's personal data (owner = Google email),
  and approval only moves the data — never re-translates. The base deck
  is seeded in D1 `deck_translations` (key `'base'`, owner `'shared'`,
  78 cards × 4 languages = 316 rows). Language switching reads the
  stored rows and is INSTANT — live-verified 2026-11-22 02:21–02:24:
  switch to English took <1 s, no loading dialog, card names in English
  immediately, NO ` · vi` badge anywhere. The old rule "meanings stay
  Vietnamese" is WRONG — user correction 2026-11-21 15:48. Do not
  re-assert it anywhere. UI chrome is 259 keys × 5 languages after
  PR #44 (4 sync-button keys removed). **Quality caveat:** m2m100
  output is poor ("Chàng Khờ" → "You stupid.", "Ba Gậy" → "Three
  sticks"); the Google Translate fallback still needs the user's
  `GOOGLE_TRANSLATE_API_KEY` (see §7.4).
- **Guide (on main):** 15 slides live at `/guide/`, horizontal track
  navigation (translateX, no vertical motion), About link verified,
  entrance animations + parallax + `#sN` deep links (PR #39). Only
  the Home slide has a real screenshot; the other 11 slides show dashed
  placeholders. **Slide 3's `home-crop.png` was NEVER uploaded** (the
  PR #39 push missed both the file and the `index.html` reference; the
  live guide still uses the unannotated `home.png`). The annotated crop
  (1920×480, red outlines + badges 1–4) is CORRECT and built — it is
  being pushed in the combined PR (see §7.3). The Pinterest "Lưu"
  button seen in verification was the user's Chrome extension overlay,
  not in any file.
- **Table dialog (on main since PR #39, live-verified):** rebuilt inside
  `Consumer<SettingsProvider>` (chips/toggles update live); only `Gỗ Sồi`
  is offered (Stone/Universe have no painted art); `Lá Khô` is excluded
  from decor choices. **Decor max is now 4** (PR #44; was 3 — the user
  asked 2026-11-21 23:55 where the max-3 rule came from; there are 4
  usable items). **Open bug (found during that verification):**
  selecting "Hương Trầm" (incense) alone does NOT auto-enable the
  "Hiện đồ decor" toggle, and deselecting ALL decor leaves the toggle
  still ON — the fix is 1 line in `setDecorItems` (`showDecor =
  clean.isNotEmpty`), built locally, being pushed in the combined PR
  (see §7.2).
- **Library headers (on main since PR #39, live-verified):** gold
  `_SectionHeader` over "Bộ bài của tôi (n)" and "Bộ bài chung (n)".
- **Branches:** `main` is the default branch. A cleanup on 2026-11-21
  deleted 38 merged branches; `ui/v2-permanent-translations` (PR #44)
  was deleted 2026-11-22 after its merge. The holding branch
  `docs/translate-worker-source` (commit `4a080fc` — the Worker JS source
  with the `/translate` route, for copy-paste deploy) still exists; the
  translate work is now concluded (V2 live), so delete it. Delete your
  branch after its PR merges.

## 3. Infrastructure

### 3.1 GitHub Pages + Actions

- Workflow: `.github/workflows/flutter-web-preview.yml` (subosito
  flutter-action `channel: stable`, `flutter pub get`,
  `flutter build web --release --base-href /TarotDesk/`).
- If a run fails ONLY at `deploy-pages` with "Found 0 artifact(s)", re-run
  the failed deploy job once. If it fails at the flutter build step, read
  the exact build-log errors first — never re-run blindly.
- **⚠️ The deploy-artifact trap (learned 2026-11-22, run #45):** a
  "Found 0 artifact(s)" failure followed by a job re-run re-executes the
  WHOLE deploy job including `upload-pages-artifact`, creating a SECOND
  `github-pages` artifact — `deploy-pages` then fails with "Found 2
  artifact(s)". The fix is NOT another re-run: delete ALL `github-pages`
  artifacts on that run first, then re-run once (exactly 1 fresh upload).
  If the Artifacts section will not render in the UI (it stopped rendering
  on run #45 after 1 of 2 was deleted), do NOT re-run — trigger a FRESH
  run instead via `workflow_dispatch` (the workflow supports it): a new
  run starts with 0 artifacts and deploys cleanly. That is what run #46
  did (fresh run, 2m1s, green, 1 artifact). **Never re-run a deploy job
  twice in a row.**
- Flutter web's service worker caches aggressively. To verify a fresh build,
  use a new tab + a cache-busting URL (`?v=...`) + reload; sometimes ALL
  github.io tabs must be closed first.
- The workflow emits a non-blocking Node.js 20 deprecation warning.

### 3.2 Cloudflare Worker `tarotdesk-oauth` (the backend, LIVE)

- **URL:** https://tarotdesk-oauth.thewolverineking.workers.dev
- **Account:** Thewolverineking@gmail.com. **Deployed version:**
  `bc5bcac6` (version 11, via the **Cloudflare API**, 2026-11-21
  ~17:45–18:30 UTC; `has_modules: true`, `compatibility_date:
  2026-11-21`). Earlier versions: `b5ab38fd` (GitHub proxy) →
  `fa355b12` (secret added) → `a3ad970b` (Google backend) → `5b48ae07`
  (ADMIN_EMAIL change) → `507f71d3` (adds `/translate`) → `06757703`
  (cache-bug fix, see below) → `b5aae39b` (V2, version 10) →
  `bc5bcac6` (V2 + seed livelock fix, version 11, CURRENT).
- **Deploy method — API, NOT the editor.** The Cloudflare Worker editor
  (Monaco) cannot be pasted into from the user's Chrome: clipboard read
  is blocked (`ERR_BLOCKED_BY_CLIENT`-style clipboard denial; Ctrl+V is
  blocked in the browser tool and no permission prompt appears). Do NOT
  try to deploy by pasting into the editor — it fails. Deploy with the
  Cloudflare API instead: a Cloudflare API token named **"TarotDesk
  translate deploy"** was created and entered into the Secure Vault as
  `custom.cloudflare` (scope: Workers Scripts Edit on the account).
  The deploy that landed `507f71d3` used that token (PUT
  `/client/v4/accounts/{account_id}/workers/scripts/tarotdesk-oauth`,
  multipart with the 716-line JS + `metadata.json`). The Worker JS source
  is also on the holding branch `docs/translate-worker-source` (commit
  `4a080fc`, `worker/tarotdesk-oauth-with-translate.js`) — delete that
  branch once the deploy is fully verified.
- **What it does (Google backend):** app redirects same-tab to Google
  authorize (state via `Random.secure`, saved in SharedPreferences,
  verified on callback) → app POSTs `{code, redirect_uri}` to Worker
  `/google-token` → Worker exchanges the code at Google (secret from env),
  verifies the `id_token` (RS256 vs Google JWKS
  `https://www.googleapis.com/oauth2/v3/certs`, cached 1h; checks
  iss/aud/exp) → mints a 64-char hex session token (30-day expiry) stored
  in D1 `sessions` → app calls endpoints with
  `Authorization: Bearer <session_token>`.
- **Endpoints:** POST `/google-token`, GET `/me`, GET `/data`, POST
  `/data`, GET `/shared-decks` (public), POST `/submit-deck`,
  GET `/admin/submissions`, POST `/admin/approve`, POST `/admin/reject`,
  POST `/admin/delete-shared-deck`, GET `/admin/shared-decks`,
  POST `/translate` (ad-hoc, D1 `translations` cache), **POST
  `/deck/pretranslate` (V2, any logged-in user; owner decided
  server-side from the session) and GET `/deck-translations?deck_key=…
  &lang=…` (V2, reads permanent rows)**. The old
  POST `/admin/pretranslate` is REMOVED. Admin
  endpoints require session email == `orenji11299@gmail.com` (403
  otherwise). CORS restricted to https://neito112.github.io (+
  localhost:8080/3000). No secrets/tokens logged; raw Google error bodies
  never forwarded.
- **`/translate` route (DEPLOYED in v`507f71d3`; the POST "hang" was a
  cold start + a cache bug, both fixed — see below).** POST `/translate`, body
  `{"texts": [...], "target_lang": "en", "source_lang": "vi"}` (source_lang
  optional, omitted when unknown, never null/`"auto"`); success returns
  `{"translations": [{text, source_lang, translated, engine, cached}]}` —
  EXACTLY N items for N inputs. Errors are `{"error":...}` with
  400/405/413. Caps: valid Bearer session → 100 texts / 40,000 chars per
  request; anonymous (no/invalid/expired token) → 20 texts / 8,000 chars
  — anonymous requests still work, there is NO 401 anywhere in the route
  (Bearer validation is done via the Worker's existing `getSession()`
  D1 lookup; a fake Bearer with 25 texts must get 413, not 200). The
  route is registered BEFORE the session gate. Engines: Workers AI
  `@cf/meta/m2m100-1.2b` via the `AI` binding (primary); Google Cloud
  Translation ONLY if `GOOGLE_TRANSLATE_API_KEY` is set (it is NOT —
  Workers-AI-only by decision). A translation miss never 500s (per-item
  `translated: false`). Cache: D1 `translations` table, keyed by
  `(sha256(source), source_lang, target_lang)`.
- **POST `/translate` — the "hang" was a cold start + a cache bug, both
  FIXED (2026-11-21).** A POST with a 180 s timeout SUCCEEDED in
  **85.34 s** (HTTP 200, `engine: "workers-ai"`, `cached: false`) — the
  m2m100 model just takes ~85 s on first call; the earlier 30 s / 90 s
  tests timed out before it finished. Then the ROOT CAUSE of cards
  staying untranslated was found: in `handleTranslate`, the D1-cache-hit
  branch set `anyCached = true` but did NOT set `anyTranslated = true`,
  so a fully-cached text returned `translated: false, engine: 'none'`
  and the app kept showing Vietnamese + ` · vi` forever. Fix: one line
  (`anyTranslated = true;` in the cache-hit branch), deployed as
  `06757703` (2026-11-21 22:06); verified immediately — POST for
  ["Chàng Khờ","Ba Gậy"] → 200 in 0.71 s, both `translated: true,
  cached: true`. **V2 supersedes this path for decks:** deck
  translations now live permanently in `deck_translations` (see below);
  `/translate` serves only ad-hoc requests. See §7.1 (resolved).
- **V2 permanent deck translations (LIVE, Worker v10→v11, 2026-11-22).**
  New D1 table `deck_translations` (`deck_key`, `card_id`, `lang`,
  `name`, `meaning`, `owner`, `updated_at`; PK on the first three;
  `card_id` = 0-based position, `-1` = deck-name row; `owner` =
  `'shared'` or the author's Google email). `deck_key`: base deck =
  `'base'`; submitted deck = the submission id (carried through
  approval); personal deck = `'user-<google_sub>-<local deck id>'`.
  Translation runs ONCE, in the background (`ctx.waitUntil`,
  best-effort, never blocks the response) at create/edit/submit, then
  INSERTed permanently; editing one card re-translates only that card.
  **Approval = pure move:** `/admin/approve` only copies `deck_json` +
  `deck_key` verbatim from `submissions` to `shared_decks` — no MT,
  no touching `deck_translations`. **Seed livelock fix (v11):** the
  first seed run plateaued (English stuck at 13/79 rows) because
  `POST /deck/pretranslate` re-translated all 316 jobs from scratch on
  every call while each background invocation only finished ~13 rows —
  the handler now computes the missing slots first and passes them as
  `onlySlots`, so progress accumulates. **Seed DONE 2026-11-22 01:12:**
  en/zh/ko/ja each 79/79 rows (78 cards + deck-name row), owner
  `'shared'`; D1 total 316 rows. Rollback caution: rolling the Worker
  back to v10 also rolls back the skip-existing fix — re-apply it
  before any future seed re-run. The pre-V2 live Worker source is saved
  at `~/workspace/tarotdesk-pretranslate-v2/out/rollback/`.
- **Secrets (Production, never in code/chat):** `GOOGLE_CLIENT_SECRET`
  (Google OAuth client secret). The optional Google Translate fallback
  key `GOOGLE_TRANSLATE_API_KEY` is NOT set (user decision pending,
  see §7.4).
- **Free-tier limits (verified Nov 2026):** Workers 100,000 requests/day
  (Error 1027 beyond, resets 00:00 UTC), 10 ms CPU per request (waiting
  on fetch/KV/DB does NOT count), 128 MB memory. KV: 100,000 reads/day but
  only 1,000 writes/day — too tight for user data, use only for
  config/cache. D1: 5,000,000 rows read/day, 100,000 rows written/day,
  5 GB storage — the right store for per-user data. R2: 10 GB. Paid plan
  is $5/month (10M requests/month) if it ever outgrows free.
- **Capacity estimate:** at ~5 Worker requests per active user per day,
  the free tier supports ~20,000 daily active users. No payment needed now.
- **Workers do NOT sleep.** Unlike free container hosts (Render/Heroku),
  there is no deep sleep / multi-second wake-up. At most a cold start of a
  few tens of milliseconds on the first request after idle. GitHub Pages
  and D1 are also always-on.

### 3.3 D1 database `tarotdesk-data` (LIVE)

- **ID `bec4ad49-ec2c-4fa5-a273-7656fa6254c4`**, bound to Worker
  `tarotdesk-oauth` as binding **`DB`** (Production + Previews).
- **Schema (6 tables):** `sessions`, `user_data`, `shared_decks`,
  `submissions`, plus `translations` (the MT cache for ad-hoc
  `/translate`: `source_hash`, `source_lang`, `target_lang`,
  `translated_text`, `engine`, `created_at`; PK on the first three)
  and **`deck_translations`** (V2 permanent deck data — see §3.2;
  the old `translations` table now serves ONLY ad-hoc `/translate`,
  the deck path no longer reads/writes it). Migration
  `001-deck-translations.sql` (2026-11-22, 8 statements, all passed)
  also added a `deck_key` column to `submissions`/`shared_decks`.
- **AI binding:** the Worker also has a Workers AI binding named
  **`AI`** (added 2026-11-21, Worker > Settings > Variables, alongside
  the `DB` binding). Without it the `/translate` route degrades to
  untranslated text. `GOOGLE_TRANSLATE_API_KEY` is NOT set
  (Workers-AI-only by decision; see §7.1/§7.4).
- Smoke tests (2026-11-21/22): GET `/` → 401 `{"error":"unauthorized"}`
  (expected, no session); GET `/shared-decks` → 200 `[]` with
  `Access-Control-Allow-Origin: https://neito112.github.io`; GET
  `/translate` → 405 (new code live); POST `/translate` anonymous →
  200 in 0.48 s, `translated: true, cached: true` (cache-bug fix
  confirmed live); GET `/deck-translations?deck_key=base&lang=en` →
  200 with 78 cards, 0 empty name/meaning (seed verified live).

### 3.4 Google Cloud (OAuth)

- **Project:** "TarotDesk" (Project ID `tarotdesk`, number `123408820943`).
- **OAuth consent screen:** User type External, app name "TarotDesk",
  support + developer contact `thewolverineking@gmail.com`, scopes
  `openid`, `email`, `profile`.
- **OAuth client "TarotDesk Web" (Web application).**
  **Client ID (public):**
  `123408820943-7jqa6sqoncp591485d2uo9euumvnlpii.apps.googleusercontent.com`
- **Authorized redirect URIs:** `https://neito112.github.io/TarotDesk/` and
  `http://localhost:8080/`.
- **⚠️ Publishing status is "Testing".** Only listed test users can sign
  in until the app is published (or test users are added under Audience).
  **Test users (2 of 100 cap):** `orenji11299@gmail.com` (admin) and
  `thewolverineking@gmail.com`. Publishing the app so real users can sign
  in is an OPEN user decision (see §7.6).
- The client secret lives ONLY as the Worker secret `GOOGLE_CLIENT_SECRET`
  (see §3.2). Never put it in the app, the repo, or chat.

### 3.5 GitHub OAuth App (legacy, for reference only)

- App "TarotDesk", **Client ID `Ov23liWavH5gANVQIFcY`**, scopes
  `read:user gist public_repo`, NO secret. Homepage + callback URL
  `https://neito112.github.io/TarotDesk/`. Device Flow was enabled. This
  login path is ABANDONED (see §5); do not build on it.

## 4. Pull-request history (merged to main)

| PR | Merge commit | What it did |
|----|--------------|-------------|
| #1 | `b4f458d` | Responsive layout (phone <600dp, tablet 600–1024dp, desktop >1024dp; `lib/core/responsive.dart`). |
| #2 | `a781cab` | PC 4K compact table. |
| #3 | `890920d` | Painted 3D table scene. |
| #4 | `f34186b` | Flat cloth + changeable photo decor sprites. |
| #5 | `be6539f` | Big changeable cloth + 175-wide stage card + meaning panel + tap-to-collect. |
| #6 | `2b3993a` | Whole-app 5 parallel tracks. |
| #7 | `b927588` | Null-guard hotfix. |
| #8 | `216d925` | Painted cloth + decor in the table's style; deleted both "Thu xuống khay" buttons. |
| #9 | `593c10b` | Master-scene cut-outs (verification FAILED — seams). |
| #10 | `8873020` | HyperFrames layered table (bare-wood background, code trapezoid, decor sized by width only). |
| #11 | `343a43e` | Deleted the "Kiểu trải" UI from Settings + reading toolbar (the `spreadMode` field/logic was deliberately kept). |
| #12 | `40f0004` | Cloth cut-outs `Positioned.fill` + `BoxFit.cover` (pixel-registered). |
| #13 | `74377ac` | Cloth rim removed; stage lift 0.17. |
| #14 | `15ab3cb` | Directional cast shadows down-right; stage 175→150, lift 0.17→0.14; decor widths shrunk ~15%. |
| #15 | `176886d` | No-cards-on-table model (tray holds all, screen shows one); deck split (current deck view-only, library add+edit); `DatabaseHelper.insertCard`; PC compact buttons; full card art (`BoxFit.contain`); Home clean wood background. |
| #16 | `60f8e5a` | Remove-const patch for the #15 build failure. |
| #17 | `d2849d3` | Clean rebuild of `edit_card_screen.dart`. |
| #18 | `666b48c` | Selection panel grid 10→12 columns on desktop. |
| #19 | `47c55c2` | AddDeck layout redo; Settings layout redo (chips); stage→tray flight (per-card-id GlobalKeys, one easeOutCubic 500 ms tween); stage card 150→170; meaning panel 320→380; deck stack desktop 60→84. |
| #20 | `a208aa8` | Flight GlobalKey maps `Map<int, GlobalKey>` → `Map<int?, GlobalKey>` (fixes the `int` vs `int?` build failure). |
| #21 | `ba80390` | Stage card 170→190; meaning panel 380→500; smoke rewritten; `mystic_music_player.dart` (5 tracks + YouTube link input); `youtube_player_iframe: ^6.0.3`. |
| #22 | `a62d012` | youtube_player_iframe API fix (`playVideo`/`pauseVideo`, dropped `isReady`). |
| #23 | `79edaa8` | Player moved out of `Offstage` into a 1×1 SizedBox in the body Stack (Offstage broke the whole body on web); smoke puffs drawn as vertical ovals. |
| #24 | `871f10f` | Daily Card name maxLines 1→2; empty-table hint "xấp bài bên trái" → "xấp bài ở giữa". |
| #25 | `b2f98cf` | Daily Card tap → detail dialog (never starts a reading); midnight auto-change via 1-minute timer; **card conservation** (stage card never in the tray; tap stage → collect to tray; tap tray card → raise to stage). |
| #26 | `9329bb1` | Phone/tablet table background = painted art for all devices (was old photo textures + flat cloth + heavy scrim). |
| #27 | `1d618d0` | New About & Guide screen (`about_screen.dart`): storage/practice tool only, NOT divination; needs a physical deck; "Thử trước, mua sau"; 6 usage steps. |
| #28 | `e58fdeb` | Donation QR (VietQR/BIDV, TRAN VAN TIEN, account 21110001575517, BIDV – CN Hà Nội) in the About screen, tappable to enlarge. |
| #29 | `5e4ac3f` | i18n: UI in EN + ZH + KO + JA plus a language picker in Settings (181 keys). At the time, card meanings were left in Vietnamese — **that is SUPERSEDED (user correction 2026-11-21 15:48): card names + meanings MUST be translated to the active language (see §6).** |
| #30 | `8cd0abc` | GitHub login + server (Device Flow; per-account private Gist; shared decks in `server/decks/`; submissions via PR to `server/submissions/`; Neito112 = admin). **Device Flow does NOT work from the browser (no CORS) — see §5.** |
| #31 | `b9b9e6c` | Guest hotfix: "Dùng offline" button; guests keep full local use. Quirks: guest logout needs a page reload to show the login screen; guest mode is not persisted across reloads. |
| #32 | `16a2410` | Route GitHub OAuth through the Cloudflare Worker proxy (github_service.dart constants → Worker URLs). Run #33 succeeded. Verified live: login shows a real device code, no more network error. |
| #33 | `65adfe8` | This log (`AGENT_LOG.md`) added at the repo root (+497 lines). Run #34 succeeded (1m58s). |
| #34 | `f5f0b22` | **Google login replaces GitHub login entirely** (8 commits, 14 files, +1297/−1918). Worker Google backend (v`a3ad970b` at the time) + D1 `tarotdesk-data` + app (Google redirect login, Worker API, cloud sync, admin screen); 3 old GitHub files deleted (`github_service.dart`, `gist_sync_service.dart`, `server_deck_service.dart`). Run #35 succeeded (1m35s). Live verification ALL PASS (A)–(F) as admin `orenji11299@gmail.com`. |
| #35 | `6359adc` | Guest logout/link hotfix (2 commits, 2 files). Logout now pops to the first route (login screen visible); guests see a "Liên kết tài khoản Google" button in Settings (sync button hidden for guests); new key `settings.linkGoogleAccount` in 5 languages (238 keys/language). Run #36 succeeded (1m33s). Live verification ALL PASS (A)–(D). |
| #36 | `a72ed5d` | Guide deck + About link (6 files). 15-slide HyperFrames guide at `web/guide/` → `/TarotDesk/guide/`; About screen "Hướng dẫn chi tiết" section (new keys `about.guideLinkTitle/Body/Label`); `url_launcher: ^6.3.0` added to pubspec. Slide 14 corrected from GitHub login to Google login. Run #37 succeeded (1m32s). Live verification ALL PASS (A)–(D). |
| #37 | `72f944e` | Guide navigation rewritten horizontal (1 file). 15 slides in a flex `.track`, `translateX` 0.55s ease-out, no vertical motion (user: the top-to-bottom swipe + "next page" style was old-fashioned). Run #38 succeeded (1m43s). Live verification ALL PASS (A)–(C) (mid-slide frame not capturable; smoothness from code + stable vertical position). |
| #38 | `3c6a389` | README rewrite (3 files). Root `README.md` replaced (old MAUI/C# planning note → Vietnamese product introduction) + `docs/screenshots/home-desktop.png` + `docs/screenshots/home-phone.png` (2 real screenshots). Run #39 succeeded (1m54s). Live verification ALL PASS (A)–(C): README renders, both screenshots show, no MAUI/C#/XAML refs left. **Note:** the README on main said card meanings stay in Vietnamese — that line was WRONG (user correction 2026-11-21 15:48) and was fixed in PR #41 (line 33). |
| #39 | `5bdfcf3` | **Comprehensive review fixes** (3 commits, 9 files, branch `review/fixes-20261121`). (1) Guide: HyperFrames re-research — track = camera move (`transform .6s power2.inOut`); entrances fade+scale (`0.5s expo.out`, 50 ms stagger, land dead still); parallax far-plane background; dots are real keyboard-accessible `<button>`s; `#sN` deep links; `prefers-reduced-motion`; NO `translateY` anywhere; `home-crop.png` replaces the full Home screenshot on slide 3 (see the flaw note below); `CAPTURE_SPEC.md` specs all 12 image slots. (2) Daily Card per account (FNV-1a hash of `account:<Google sub>` + `yyyy-MM-dd`; guests get a persisted per-device UUID). (3) i18n mechanism: `TranslationService` (`localizeCard`, language detection, ≤800-char segmentation, in-memory cache), `translateTexts()` in `tarotdesk_api_service.dart` (POST `/translate`), warm-up in `cloud_sync_service.dart` + `add_deck_screen.dart`, Worker route snippet + README (reference only). (4) Table-dialog fixes: dialog rebuilt inside `Consumer<SettingsProvider>`; only `Gỗ Sồi` offered (`tableStyle` was a dead setting); `Lá Khô` excluded from choices (no real image; both fallbacks now render nothing); max-3 slot accounting fixed; "Xong" hardened (`scrollable: true`). (5) Library section headers: gold `_SectionHeader` over "Bộ bài của tôi (n)" (new key `library.myTitle`) and "Bộ bài chung (n)" (reused `library.sharedTitle`). (6) Assembly: Settings filters the same dead options; orphan `reading.tableNote` key removed; false `settings.tableHint` corrected in 5 languages. Net keys unchanged at 241/language. **Run #40 FAILED** on a stray bare `library;` at line 59 of `translation_service.dart` (Dart requires a library directive before all other directives) — fixed by PR #40. Live verification of PR #39+#40 (A)(B)(C)(E)(F) PASS, (D) PARTIAL: **home-crop.png is WRONG** — no red outlines/numbered badges 1–4 on the image (despite the build claiming it had them) and a stray red Pinterest "Lưu" button is baked into the corner; the other 11 guide slides still show placeholders. Per-account Daily Card verified live (admin → Bảy Cốc, 2nd test user → Ba Gậy, guest → Chín Gậy). Table-dialog fixes verified live. Library headers verified live. **New bug found during that verification (OPEN, §7.2):** selecting "Hương Trầm" alone does not auto-enable the "Hiện đồ decor" toggle; deselecting ALL decor leaves the toggle ON. |
| #40 | `c427cba` | Hotfix for the PR #39 build failure (branch `fix/translation-service-library`, 1 commit, exactly 1 line deleted: the stray `library;` at line 59 of `translation_service.dart`). Run #41 succeeded (1m58s). |
| #41 | `7893984` | **i18n display wiring** (4 commits, 10 files +335/−75, branch `ui/i18n-display-wiring`). `main.dart` gains one shared `TranslationService` (`ProxyProvider2<AuthProvider, SettingsProvider, TranslationService>`); NEW `lib/presentation/widgets/localized_card_text.dart` (`LocalizedCardName` / `LocalizedCardMeaning` — Future cached per (card id, target language), original text while loading, never blank, dim ` · vi` badge when untranslated); new_reading, home (Daily Card dialog + hero), reading_detail, deck_detail, select_deck, add_deck (draft preview) and settings screens switched to localized display; README line 33 corrected. Static verification PASS (241 keys/language, 0 missing; no screen still renders raw `Text(card.name`/`Text(card.meaning`). Run #42 succeeded (2m3s). **BUT live verification FAILED the main goal:** card names + meanings stayed Vietnamese with a ` · vi` badge everywhere checked (reading, Daily Card dialog, deck detail) even after 15 s — because the Worker `/translate` route was NEVER deployed at that time (`translateTexts()` had no endpoint). The ` · vi` badge is real code (`localized_card_text.dart` line 65). (D) switch back to Vietnamese PASS; (E) regression PASS (no crash, no raw keys; drawn card discarded unsaved); (F) app left LOGGED OUT, Vietnamese, no data deleted. Unrelated observation: the Home "Recent readings (5)" section vanished at 16:20 and History said "No readings have been saved yet" — cause unknown (possibly the user was using the app simultaneously); the admin cloth also showed "Nhung Tím" instead of the expected "Thảm Đen" when the task arrived. Do not over-claim; flag if it recurs. |
| #42 | `764233e` | **i18n thorough — translate everything** (6 commits, 16 files +709/−2703, branch `ui/i18n-thorough`). Audit found 101 display strings, 41 live (13 hardcoded Vietnamese literals + 28 stored labels shown raw). Fixed UI chrome → `tr()` keys (20 new keys → **261 keys/language**, 0 existing keys altered/removed); stored option/theme/track labels → NEW `lib/core/display_labels.dart` (`themeDisplayKey` / `tableStyleDisplayKey` / `clothDisplayKey` / `decorDisplayKey` / `trackTitleKey`) — stored ids and every `==` comparison byte-identical, only the displayed label changes; deck/reading names → MT via NEW `lib/presentation/widgets/localized_content_text.dart` (`LocalizedDeckName` / `LocalizedReadingName`, same pattern as `LocalizedCardName`); seeded base deck gets `tr('deck.baseName')`. **3 dead snapshot files DELETED** (`new_reading_screen_step410/426/454.dart` — nothing imported them). Run #43 succeeded (2m6s). Live English verification DEFERRED — blocked until POST `/translate` works (§7.1); until then MT-backed names show Vietnamese + ` · vi` badge by design. |
| #43 | `1c5e8cf` | **Loading-screen language switch** (branch `ui/lang-switch-loading`). User idea (2026-11-21 22:25): when switching language, show a modal loading dialog and translate ALL cards first, then let the user continue. `_switchLanguageWithLoading` — modal dialog (`barrierDismissible: false`, `PopScope(canPop: false)`), progress "Đang dịch sang {language}… {done}/{total} lá", translates all cards in all local decks via `warmCache` with explicit `targetLang`, THEN calls `setLanguage`. 263 keys/language. Actions green. Live verification PARTIAL: dialog appeared + switched to English; the task was then STOPPED (user pivoted to V2 pre-translation), so Daily Card/reading/library checks, switch-back to Vietnamese, and admin-settings restore were NEVER completed. **This loading approach stays on main as the FALLBACK for decks with no stored translations** (it completes instantly when translations are pre-stored, because the wiring makes `warmCache` skip already-cached strings). |
| #44 | `026c0a6` | **V2: permanent deck translations + display wiring + auto-sync + decor max 4** (6 commits, 14 files +1028/−123, branch `ui/v2-permanent-translations`). Server: migration `001-deck-translations.sql` (new D1 table `deck_translations` + `deck_key` column on `submissions`/`shared_decks`); Worker v10→v11 (new `POST /deck/pretranslate` + `GET /deck-translations`; translation runs ONCE at write time in `ctx.waitUntil`, stored permanently; approval = pure move, no MT); seed of the base deck (78 cards × 4 languages = 316 rows, owner `'shared'`) — including the seed-livelock fix (skip-existing slots, v11). App: display wiring — `warmCache()` skips already-cached strings; `preloadLocalDeck()` (base deck → fixed key `'base'`; other decks → personal key first, then read-side key); `main.dart` passes `userSub` to the shared `TranslationService` (was missing); language switch preloads every local deck into the new language in parallel before the `warmCache` loop; deck_detail / reading_detail / shared-preview dialog AWAIT the preload (bounded 8 s) before cards first render; new_reading preloads fire-and-forget. **Sync: the "Đồng bộ ngay" button REMOVED; sync is automatic two-way (download + upload) and runs ONLY on login + page reload** (user 2026-11-21 23:53, corrected 2026-11-22 00:00) — background translation is separate and DOES run on create/edit/delete. **Decor max 3 → 4** (`maxDecorItems`, user 2026-11-21 23:55). i18n keys 263 → 259 (4 button-only sync keys removed). Run #45 FAILED at `deploy-pages` ("Found 0 artifact(s)", then "Found 2 artifact(s)" after a job re-run duplicated the upload — see §3.1); run #46 (fresh `workflow_dispatch`, 2m1s) SUCCEEDED. Live verification 2026-11-22 02:21–02:24 ALL PASS: language switch <1 s, no loading dialog, English card names immediately, NO ` · vi` badge; sync button gone; all 4 decor items selectable; reload keeps login + language; state restored (vi, Thảm Đen, crystal + incense). **Caveat:** the verification ran logged in as `thewolverineking@gmail.com`, NOT admin — the admin UI was never checked under the admin account (see §7.4). Branch `ui/v2-permanent-translations` deleted 2026-11-22. |

Branch naming used: `ui/<short-slug>` or `docs/<short-slug>` (e.g.
`ui/google-login`, `docs/guide-link`). Merges use merge commits (not
squash). Every push to `main` rebuilds the preview. **Delete your branch
after its PR merges** (2026-11-21 cleanup deleted 38 merged branches).

## 5. Login — the full arc (COMPLETED: Google login is live)

- **2026-11-21 10:27 (user):** the app needs login for personalization;
  opening the app requires login; each account's data is set up
  automatically; decks saved in a server folder are visible to all users;
  other users can submit decks and wait for approval via the email linked
  to the account.
- **Design approved 10:33:** GitHub-only, no backend, no separate repo.
  Original repo = server (shared decks in `server/decks/`); ONE app for
  everyone; Neito112 = admin. Login via GitHub **Device Flow**; per-account
  data = private GitHub **Gist**; submissions = PR to `server/submissions/`.
- **PR #30 merged 12:16** — but Device Flow **does not work from a browser**:
  GitHub's OAuth endpoints return NO `Access-Control-Allow-Origin`, so the
  browser blocks the response and the app reports "Không có kết nối mạng".
- **PR #31 (guest hotfix) merged 12:35** — restores access via
  "Dùng offline" while login is broken.
- **Cloudflare Worker deployed + verified 13:16** (proxy for GitHub OAuth).
- **PR #32 merged 13:29** — app routes OAuth through the Worker. Verified:
  tapping login shows a real device code. But completing Device Flow then
  hit GitHub's **sudo-mode email verification**, and the code was rejected
  for wrong format.
- **2026-11-21 13:26 (user): "cách đăng nhập này không ổn"** — Device Flow
  is ABANDONED. The one-tap GitHub Web Flow (redirect) was started as a
  replacement and a partial build exists locally
  (`~/workspace/tarotdesk-webflow/out/`), but it is SUPERSEDED — do not push.
- **2026-11-21 13:32 (user): "phương án google đi, ít người biết dùng
  github lắm"** — **Google login is the decision.** The Google Cloud OAuth
  client was created (§3.4); the secret went into the Worker.
- **PR #34 merged 2026-11-21 14:16 (`f5f0b22`) — GOOGLE LOGIN IS LIVE.**
  Worker `tarotdesk-oauth` v`a3ad970b` (later `5b48ae07`) + D1
  `tarotdesk-data` (4 tables) + app (Google redirect login, Worker API,
  cloud sync, admin screen); 3 old GitHub files deleted. Live verification
  ALL PASS (A)–(F) 14:22 as admin `orenji11299@gmail.com` (account
  chooser, no password): login screen has the Google button, admin shield
  on Home, admin screen loads (both lists empty — correct for v1),
  Settings shows the Google account (the "Đồng bộ ngay" button was
  REMOVED in PR #44 — sync is now automatic on login + reload), regression
  pass (Daily Card XII Hanged Man, reading The Fool, EN→VI, donation QR),
  logout returns to login, guest data intact. Shared decks start EMPTY in
  v1 (no seed from `server/decks/`).
- **PR #35 merged 14:33 (`6359adc`) — guest logout/link hotfix.**
  Fixed the user-reported bug (14:25): in guest mode, logout left the
  Settings screen stuck covering the login screen, and guests had no way
  to link a Google account. Live verification ALL PASS (A)–(D).
- **ADMIN UI RULE (user 2026-11-21 11:20, email corrected 14:03):** the
  logged-in account `orenji11299@gmail.com` (the Neito112 GitHub
  account's email) gets the ADMIN / SERVER interface (manage shared decks,
  review submissions); other accounts get the regular user interface.
  `thewolverineking@gmail.com` is only the Google Cloud/Cloudflare owner
  + connected Gmail — NOT the admin.
- **Guest mode:** "Dùng offline" works fully offline (local sqflite);
  guest mode is NOT persisted across reloads (by design); guests can link
  a Google account from Settings. Known caveat: if the Google redirect
  itself fails, Settings shows no visible feedback (error surfaces on the
  login screen after logout).
- **Open decisions (user):** (a) publish the Google OAuth app so real
  users can sign in (still "Testing", 2 test users only); (b) seed the
  existing shared decks from `server/decks/` into D1, or leave the
  shared-deck store empty until submissions arrive; (c) remove the guest
  "Dùng offline" button now that real login works (restores the original
  login-required design) or keep it — do not remove it without telling the
  user.

## 6. Key design rules (from the user — do not violate)

- **Reading screen is a spiritual space, not a form.** A table in
  first-person perspective, a FLAT/smooth changeable cloth, realistic
  painted-style accessories that HUG the table surface (perspective +
  contact shadows, no floating overlays), changeable in the reading screen
  and in Settings; deck stack in one corner; smooth animations for ALL
  operations. "3D" means a painted 3D illustration ("vẽ tranh 3D"), NOT a
  real-time 3D engine. Flat Material icons for decor are explicitly
  rejected. Cloth + accessories must be drawn in the SAME painted style as
  the wood table.
- **No cards on the table.** The table is only space (wood, cloth, decor,
  deck stack). The tray holds ALL drawn cards; the screen shows a single
  card (just drawn or selected from the tray). Stage holds only one card.
- **Card conservation:** the stage card never appears in the tray; tapping
  the stage card collects it to the tray; tapping a tray card raises it to
  the stage; the tray has no selection border.
- **Card art:** keep 5:8 frames; card images `BoxFit.contain` + black
  background everywhere (art is 7:12; `BoxFit.cover` cropped ~7.1% of height
  including the title band). Tables/cloth keep `cover`.
- **i18n — card content MUST be translated (user correction 2026-11-21
  15:48, SUPERSEDES the PR #29 rule).** Card names + meanings MUST be
  translated to the active system language. The old rule "meanings stay
  Vietnamese" is WRONG — do not re-assert it in code, docs, or the README.
  Translation is done by the server-side machine-translation mechanism
  (Worker + D1 cache, source text never overwritten) — NEVER by hand
  (do not hand-translate the 78 base cards). UI chrome is translated via
  `localization.dart` (259 keys × 5 languages after PR #44). Stored
  option-value names (e.g. 'Gỗ Sồi', 'Nhung Tím' — code compares against
  them) keep their Vietnamese ids, but the DISPLAYED label is now
  translated via `display_labels.dart` (PR #42); the 5 preset track
  titles likewise show translated display names (`music.track1–5`).
  Deck/reading names go through the MT service. See §7.1/§9.2.
- **Daily Card is per account (LIVE on main since PR #39, verified).**
  Seed = FNV-1a hash of `account:<Google sub>` (fallback email) + full
  date `yyyy-MM-dd`, so each account gets a different card on the same
  day — a personal surprise — while the same account keeps the same card
  all day and it changes at midnight. Guests get a stable per-device seed
  (persisted locally). Live-verified 2026-11-21: admin → Bảy Cốc,
  2nd test user → Ba Gậy, guest → Chín Gậy.
- **Guide slides: horizontal motion only, no vertical motion.** The user
  rejected the top-to-bottom swipe + "next page" style (2026-11-21 15:07)
  and the vertical rise in entrances. Guide transitions are a horizontal
  camera move (track `translateX`, `power2.inOut`); entrances are fade +
  scale only. Screenshots in the guide must be CROPPED to the relevant UI
  element (not full-screen) and ANNOTATED (red outlines + numbered badges
  matching the step list, arrows where needed). See §7.5.
- **Platform:** Android phone is primary; iPad and PC in parallel;
  mobile-first adaptive. PC must be compact and neat at 4K — do not scale
  phone-sized elements up for desktop.
- **Working rule (user 2026-11-20):** do not guess at a fix — if something
  is wrong, delete it outright and redraw it exactly per the description.
- **Standing mode (user 2026-11-20):** keep the direct/visible flow
  continuous; the deliverable that matters is the working test screen (the
  live preview), not intermediate reports. Do not pause for per-file
  approval.
- **Replies:** lively wording, not lifeless/boring. Reply in Vietnamese.
- **Chat boundary (user 2026-11-21 08:53):** the main chat is TarotDesk
  ONLY; do not bring other work (e.g. teaching slides) here without
  permission. Do not pitch scheduled/recurring features (user turned that
  offer down flat). Do not scan Gmail or act inside Gmail/GitHub/Canva/
  WhatsApp until the user explicitly asks.
- **Saved state to preserve during verification:** cloth = Thảm Đen, decor =
  Đá Thạch Anh (crystal) + Hương Trầm (incense), table = Gỗ Sồi, theme =
  Tối Obsidian (default_dark), all 3 layer-display toggles ON, language =
  Tiếng Việt (vi). Never save test data into the user's deck (the library
  must stay only "Bộ bài cơ bản", 78 lá); never save test readings. Pause
  music before ending a verification. After a login verification, leave the
  app LOGGED OUT on the login screen; logout must not delete local data.

### 6.1 ⚠️ NOT TarotDesk — the teaching-deck rules (separate project)

The following rules belong to a **separate side chat** (teaching slide
decks for an interior-design class, AWE_ID10E_2026_09, built from Đào Thị
Thái Diễm's materials; files in Google Drive, NOT in this repo). They
are recorded here ONLY so a new agent does not confuse the two projects.
**Do NOT apply them to TarotDesk.** TarotDesk has no "no chapter labels"
rule, no "no author name" rule, and no banned-word rule of its own.

- Teaching decks (Deck 2 and Deck 3) must NOT contain the words
  Buổi/bài at all (grep = 0; "bài tập"→"Thực hành", "bài kiểm tra"→
  "Kiểm tra"). No author/teacher/class-code/school names anywhere
  (generic shared version). On VISIBLE slides, never mention "chương" or
  any ordinal/sequence number — content flows in document order without
  announcing the order.
- Teaching style is discussion-first: one big image + one short question
  (≤12 words) per slide; teaching content lives ONLY in speaker notes;
  the reveal line after discussion is labelled "GHI NHỚ". The word
  "chốt" must NEVER appear in those decks (slides, speaker notes, HTML).
- Teaching decks are HTML-only (no PPTX). If the user asks about them in
  the main chat, remember the main chat is TarotDesk-only — do not start
  slide work there without permission.

## 7. Open work (as of 2026-11-21)

### 7.1 ✅ POST `/translate` — RESOLVED (was a cold start + a cache bug; V2 supersedes it)

- **The "hang" was a slow cold start, NOT a hang.** A POST with a 180 s
  timeout SUCCEEDED in **85.34 s** (HTTP 200, `engine: "workers-ai"`,
  `cached: false`) — the m2m100 model takes ~85 s on first call; the
  earlier 30 s / 90 s tests timed out before it finished.
- **The real bug was a Worker cache bug, fixed 2026-11-21 22:06
  (deployment `06757703`).** In `handleTranslate`, the D1-cache-hit
  branch set `anyCached = true` but not `anyTranslated = true`, so a
  fully-cached text returned `translated: false, engine: 'none'` and the
  app showed Vietnamese + ` · vi` forever. Fix: one line
  (`anyTranslated = true;`). Verified: POST for ["Chàng Khờ","Ba Gậy"]
  → 200 in 0.71 s, both `translated: true, cached: true`.
- **Live verification 2026-11-21 22:07–22:14** (device Chrome, admin):
  NO ` · vi` badge anywhere; Daily Card dialog fully English; stage
  card switched VI→EN after ~6 s; deck detail only 2/78 cards after
  ~8 s (per-card, async). Session persistence verified (2 reloads,
  stayed logged in as admin).
- **V2 supersedes the on-demand path for decks** (PR #44, see §3.2):
  deck translations are permanent data in `deck_translations`, read at
  switch time. Live-verified 2026-11-22 02:21–02:24: switch <1 s, no
  loading dialog, English immediately, no ` · vi`. `/translate` now
  serves only ad-hoc requests.
- **Remaining quality issue:** m2m100 output is poor ("Chàng Khờ" →
  "You stupid.", "Ba Gậy" → "Three sticks", "Bộ bài cơ bản" → "The
  basic card."). The Google Translate fallback still needs the user's
  `GOOGLE_TRANSLATE_API_KEY` (see §7.4, item 1). The Worker tries
  Workers AI first, so the engine order may need adjusting, and bad
  cached/seeded translations would need clearing/replacing if the
  engine changes.

### 7.2 🟡 Table-dialog "Hiện đồ decor" toggle bug (fix BUILT — being pushed in the combined PR)

- PR #39's table-dialog fixes are on main and live-verified (dialog
  rebuilt in `Consumer<SettingsProvider>`, only `Gỗ Sồi` offered,
  `Lá Khô` excluded, max-4 accounting fixed (PR #44 raised the max
  from 3 to 4), "Xong" hardened). But the
  verification found a NEW bug, not yet fixed on main: selecting
  "Hương Trầm" (incense) ALONE does not auto-enable the "Hiện đồ decor"
  toggle, and deselecting ALL decor leaves the toggle still ON (must be
  turned off manually).
- **Root cause (verified in code):** `SettingsProvider.setDecorItems` —
  the single choke point for the decor list, called by BOTH UIs on both
  select and deselect paths — never touched `showDecor`; only the manual
  `toggleDecor` handler changed it.
- **Fix (built locally, `~/workspace/tarotdesk-decor-toggle/out/`):**
  1 file, `settings_provider.dart`, +7 lines — in `setDecorItems`,
  after `_userPrefs.decorItems = clean;`, added
  `_userPrefs.showDecor = clean.isNotEmpty;` + comments. Diff vs main
  exactly +7 lines; bracket balance OK; no new display strings; keys
  intact. Being pushed in the combined PR with the home-crop fix and
  this log update. Live-verify after merge: select incense alone →
  toggle ON + incense appears; deselect all → toggle OFF; same in
  Settings; restore admin state (cloth Thảm Đen, decor crystal +
  incense), save no test reading.

### 7.3 🟡 Guide slide 3 `home-crop.png` — was NEVER uploaded (fix BUILT — being pushed in the combined PR)

- The review PR claimed `home-crop.png` was a "REAL annotated crop (red
  outlines + numbered badges 1–4)". Live verification (2026-11-21)
  reported NO red outlines/badges and a stray red Pinterest "Lưu"
  button. **The truth (investigated 2026-11-21 ~18:33): the file was
  NEVER on main** — the repo's `web/guide/images/` contains only
  `home.png` and `phone-home.png` (a raw fetch of `home-crop.png`
  returns 404), and the live `index.html` references `images/home.png`.
  The coordinator's local `home-crop.png` (1920×480, sha256
  `82bd636c…`) IS correct — verified visually: red `#ff5347` outlines
  + numbered badges 1–4 exactly per CAPTURE_SPEC.md. The Pinterest
  "Lưu" button is NOT in any file — it was the Pinterest Save Button
  Chrome extension overlaying on hover during verification.
- **Fix (built locally, `~/workspace/tarotdesk-homecrop/out/`):**
  `home-crop.png` (byte-identical copy) + the live main `index.html`
  with the MINIMAL edit only (+5 lines `.shot-cap` CSS, slide 3 `<img>`
  src `home.png` → `home-crop.png`, +1 caption line linking to the full
  `home.png`) **+ the "(tối đa 3)" → "(tối đa 4)" decor-max fix** in the
  guide text (PR #44 raised the max to 4). Being pushed in the combined
  PR. Live-verify after merge on `/guide/` in a fresh tab: slide 3
  shows the cropped image with red outlines + badges 1–4; if a red
  "Lưu" appears on hover, check in Incognito to confirm it is the
  extension.

### 7.4 🟡 Decisions the user must make

1. **Google Translate fallback key (`GOOGLE_TRANSLATE_API_KEY`)** — set
   it or stay Workers-AI-only? m2m100 quality is poor ("You stupid.",
   "Three sticks", "The basic card.") and slow on cold start (~85 s).
   Google Cloud Translation is $0 to 500k chars/month, then $20/1M
   chars. Setting the key needs a Google Cloud project + billing
   enabled, and the Worker tries Workers AI first, so the engine order
   may need adjusting; bad cached/seeded translations would need
   clearing/replacing. The old `/translate` hang decision is RESOLVED
   (see §7.1).

2. **Publish the Google OAuth app** so real users can sign in (still
   "Testing", 2 test users only — §3.4).
3. **Seed shared decks** from `server/decks/` into D1, or leave the
   shared-deck store empty until submissions arrive.
4. **Guest "Dùng offline" button:** remove it now that real login works
   (restores the original login-required design) or keep it.
5. **`showTable = false` behaviour:** turning off the table surface
   leaves cloth + decor floating on black (by design — the three toggles
   are independent layers). Should `showTable` become a master switch, or
   keep the layers independent?
6. **Library empty state:** show a "Bộ bài của tôi (0)" header when there
   are 0 own decks, or keep the existing empty state?
7. **Phone variant for guide slide 3:** `phone-home.png` exists but is
   unreferenced — use it as a phone variant of slide 3 or leave it?
8. **Painted assets to re-enable hidden options:** a Stone table painting,
   a Universe table painting, and a `Lá Khô` cut-out. Until then the
   honest state is: only wood, 4 decor items. (Needs the user's
   artist/asset decision.)
9. **Admin account on the user's Chrome:** RESOLVED 2026-11-22
   ~18:40 — the app is now logged in as admin `orenji11299@gmail.com`
   on the device Chrome. Admin UI verified live: the Home header has
   3 icons (info, admin/server, settings); the middle icon opens
   "Quản trị máy chủ" with exactly 2 sections — "Bộ bài chờ duyệt"
   (0 pending) and "Kho bài chung" (0 shared decks) — both empty, as
   expected (shared decks start EMPTY, no seed). No approve/reject/
   delete buttons appear while the lists are empty. Normal app works
   as admin (library "Bộ bài cơ bản", reading screen renders). Note:
   the state found under admin before restoring was cloth "Nhung Tím"
   with NO decor selected (different from the saved Thảm Đen +
   crystal + incense) — restored to the saved state; if the user
   changed it deliberately during the day, say so and it will be
   kept as-is next time.


### 7.5 🟡 Screenshots (2 of 18 captured; 11 guide slots still placeholders; slide 3 crop built, being pushed)

- Real shots exist for `home.png` (desktop Home) and `phone-home.png`
- Real shots exist for `home.png` (desktop Home) and `phone-home.png`
  (iPhone Home) in the guide images folder. The `home-crop.png` claimed
  by PR #39 was never uploaded (see §7.3); the correct crop is built
  and being pushed in the combined PR with this log update. The other
  11 guide image slots
  (`daily`, `reading-empty`, `reading-stage`, `reading-tray`, `select`,
  `library`, `add-deck`, `history`, `settings`, `music`, `donate`) show
  dashed placeholders (now with a per-slide capture spec in
  `web/guide/CAPTURE_SPEC.md`: tight crop of the relevant element + ~24px
  margin, red `#ff5347` numbered badges, ≤3 annotations per shot).
- The remaining 16 inner screens could NOT be captured automatically (no
  deep links; VM browser blocked; device Chrome cannot save PNGs).
  Waiting on the user's choice: (a) user takes over the browser and
  captures them (Win+Shift+S), or (b) keep placeholders. When a real shot
  lands, drop the PNG into `web/guide/images/` — no HTML change needed.
- README screenshots: `docs/screenshots/home-desktop.png` +
  `home-phone.png` are live (PR #38). More README shots await the same
  captures.

### 7.6 🟡 Real-phone checks (awaiting the user)

- The PR #26 painted background on a real phone; whether the Home history
  list scrolls on a phone; guide entrance timing / stagger /
  parallax on a real phone; translation quality on a known card (0. Chàng
  Khờ / The Fool) in EN — BLOCKED until POST `/translate` works (§7.1).

### 7.7 🟡 This log's freshness + branch hygiene

- This log is the deliverable the user asked for (2026-11-21 13:41) and
  must be kept current after every merge. It was stale from PR #33 to
  #38 until the 2026-11-21 rewrite, stale again from PR #39 to #42
  until the 2026-11-21 refresh, and stale again from PR #43 to #44
  until this update (2026-11-22). After each future merge, update the
  header, the PR table, the affected sections, and §7.
- Branch hygiene: `main` is the default. Delete your branch after its PR
  merges. `review/fixes-20261121` (PR #39), `fix/translation-service-library`
  (PR #40), `ui/i18n-display-wiring` (PR #41), `ui/i18n-thorough` (PR #42),
  `ui/lang-switch-loading` (PR #43) and `ui/v2-permanent-translations`
  (PR #44, deleted 2026-11-22) are all merged — delete any that still
  exist. The holding branch `docs/translate-worker-source` (commit
  `4a080fc`, Worker JS source) stays ONLY until the `/translate` deploy
  is fully verified — the translate work is now concluded (V2 live), so
  delete it too.

## 8. Declined / do-not-reattempt

- **Android native build — DECLINED, do not re-attempt.** The user asked
  (2026-11-21 09:17) to build an Android version (iPad uses the PC UI;
  GitHub preview switching between Android/PC + a download button; all data
  on a personal GitHub repo; sign-in on download). The preparation
  subagent's output was removed by safety classifiers. Standing instruction:
  do NOT continue that request — not by delegating again, rephrasing, using
  a tool/helper, or answering from own knowledge. If the user asks again (in
  any wording), concisely decline and suggest another topic. No Android
  files were created or pushed. The project has NO `android/` folder and no
  Flutter SDK in the VM; it is web-only.
- **Display-mode switch button — DECLINED** (user 2026-11-21 09:32). Same
  feature as the declined preview device switcher; decline concisely.
- **GitHub Device Flow login — ABANDONED** (see §5). Do not revive it.
- **GitHub one-tap Web Flow — SUPERSEDED** by the Google decision (see §5).
  A partial build exists locally; do not push it.

## 9. Technical reference

### 9.1 Repo layout (main `026c0a6`, `tarot_desk_flutter/`)

- `lib/core/`: `constants/`, `localization.dart` (259 keys/language),
  `responsive.dart`, `theme/`, `web_redirect.dart`,
  `web_redirect_stub.dart`, `web_redirect_web.dart`,
  `display_labels.dart` (PR #42: display-name mapping for stored
  option/theme/track labels), `translation_service.dart` (PR #39).
- `lib/data/datasources/`: `cloud_sync_service.dart`,
  `database_helper.dart`, `db_init_stub.dart`, `db_init_web.dart`,
  `preferences_service.dart`, `tarotdesk_api_service.dart`.
  **DELETED in PR #34:** `github_service.dart`, `gist_sync_service.dart`,
  `server_deck_service.dart` (the GitHub data layer is gone; Worker/D1
  is the backend now).
- `lib/data/models/`: `tarot_card.dart`, `tarot_deck.dart`,
  `tarot_reading.dart`, `user_preferences.dart`.
- `lib/logic/`: `auth_provider.dart`, `deck_provider.dart`,
  `reading_provider.dart`, `settings_provider.dart`.
- `lib/presentation/screens/`: about, add_deck, admin, deck_detail,
  edit_card, history, home, login, new_reading, reading_detail,
  select_deck, settings. (The 3 dead snapshot files
  `new_reading_screen_step410/426/454.dart` were DELETED in PR #42 —
  nothing imported them.)
- `lib/presentation/widgets/`: `glass_panel.dart`,
  `localized_card_text.dart` (PR #41: `LocalizedCardName` /
  `LocalizedCardMeaning`), `localized_content_text.dart` (PR #42:
  `LocalizedDeckName` / `LocalizedReadingName`),
  `mystic_music_player.dart`, `smoke_particle_effect.dart`,
  `tarot_card_image.dart`, `twinkling_title.dart`.
- `web/guide/`: `index.html` (15-slide guide deck), `images/` (`home.png`,
  `phone-home.png`, `home-crop.png` — the last is WRONG, see §7.3),
  `CAPTURE_SPEC.md` (PR #39).
- Repo root: `README.md` (product introduction, PR #38),
  `AGENT_LOG.md` (this file), `docs/screenshots/` (`home-desktop.png`,
  `home-phone.png`).
- `pubspec.yaml` dependencies: flutter, cupertino_icons ^1.0.6, provider
  ^6.1.1, sqflite ^2.3.0, sqflite_common_ffi ^2.3.0,
  sqflite_common_ffi_web ^1.1.2, path ^1.8.3, shared_preferences ^2.2.2,
  image_picker ^1.0.7, google_fonts ^6.1.0, youtube_player_iframe ^6.0.3,
  http ^1.2.0, **url_launcher ^6.3.0** (added PR #36 for the guide link).
  Assets: the whole `assets/images/` folder.

### 9.2 Key constants and facts

- **Responsive** (`lib/core/responsive.dart`): `AppBreakpoint`
  phone/tablet/desktop; `phoneMaxWidth = 600`, `tabletMaxWidth = 1024`;
  `maxContentWidth` 480/720/1080; `gridColumns` 2/3/4; `cardWidth`
  160/200/220. Layout auto-switches by screen width; no toggle.
- **Cards:** 78 real card images, 350×600 JPG (7:12). `TarotCardModel`
  fields: `id` (int?), `deckId`, `name`, `meaning` (String), `imagePath`.
  The base deck's `meaning` is plain readable text containing the sections
  (TỪ KHÓA XUÔI/NGƯỢC, Ý NGHĨA CHIỀU XUÔI, TỔNG QUAN, TÌNH CẢM) — NOT raw
  JSON. `TarotCardMeaningExtension` getters parse it when it is detailed.
- **Database:** sqflite, file `tarot_desk.db`, version 5; web uses
  sqflite_common_ffi_web via conditional import. Seeds the base deck
  "Bộ bài cơ bản" + 78 cards from
  `lib/core/constants/tarot_card_meanings.dart` on create.
- **Preferences:** `UserPreferencesModel` stored as one JSON string in
  SharedPreferences under `tarotdesk_user_preferences`. Canonical lists
  (tableStyles, clothStyles, decorOptions, maxDecorItems = 3) live on it;
  the in-reading dialog and Settings must share them (no hard-coded
  duplicates). Language code default `vi`; `languageCodes`
  `['vi','en','zh','ko','ja']`.
- **i18n** (`lib/core/localization.dart`): `AppLanguage` vi/en/zh/ko/ja;
  `AppStrings.of(lang, key)` falls back to Vietnamese, then to the key.
  **259 keys/language** (181 at PR #29 → 239 at PR #30 → 241 at PR #31 →
  238 at PR #35 → 241 at PR #36 → 241 at PR #39 → 261 at PR #42 → 263
  at PR #43 → 259 at PR #44: −4 sync-button keys; +20 at PR #42 —
  `theme.*` (4), `table.oak`, `cloth.*` (3), `decor.*` (4),
  `music.track1–5`, `deck.baseName`, `app.title`,
  `addDeck.noMeaningDefault`). UI chrome only.
  **Card/deck content is NOT in `localization.dart`.** Card names +
  meanings MUST be translated to the active language (user correction
  2026-11-21 15:48) via the server-side MT mechanism (§7.1), never by
  hand. Stored option-value ids stay Vietnamese (code compares against
  them), but their DISPLAYED labels are translated via
  `display_labels.dart` (PR #42); the 5 preset track titles likewise
  show translated display names. Deliberately untranslated by design:
  code comments/debug strings; `settings.tableHint` EN still contains
  the stored id `Gỗ Sồi` (pre-existing, deliberate).
- **Translation mechanism (ON main since PR #39; display wiring PR #41;
  thorough pass PR #42):**
  `lib/core/translation_service.dart` (`TranslationService`,
  `localizeCard`, `detectLanguage`/`detectDeckLanguage` script heuristic,
  `segmentText` ≤800-char segments, `warmCache`, `LocalizedCard`,
  `kBaseDeckSourceLanguage = 'vi'`); `translateTexts()` in
  `tarotdesk_api_service.dart` (POST `/translate`, optional session
  token); warm-up in `cloud_sync_service.dart` (`targetLanguageCode`
  resolver) + `add_deck_screen.dart` (fire-and-forget after save). Worker
  route DEPLOYED (v`507f71d3`, cache-bug fix `06757703`, now V2
  `bc5bcac6`) — the POST "hang" was an ~85 s m2m100 cold start (see
  §3.2/§7.1, resolved).
  Graceful fallback everywhere: engine down / unconfigured / quota spent
  → original text shown, marked with its source language (` · vi`
  badge); the app never crashes and never shows an empty card because of
  translation. Note: `CloudSyncService.syncAfterLogin()` has NO callers,
  so the download warm-up never runs — the display-path `localizeCard()`
  is what delivers translations on first view.
- **Music:** 5 built-in tracks in `kMysticTracks`
  (`mystic_music_player.dart`): 'Thiền The Fool — 432Hz (30 phút)'
  `Beht63_bFHw`; 'Vòng Lặp Vô Tận — nhạc Tarot' `HlnHn2i_5ks`;
  'Bùa Chú Bóng Đêm — Dark Ambient' `XWqgeFawCqc`;
  'Trống Hang & Sáo — nhạc huyền bí' `DcCWB9sX-SM`;
  'Nghỉ Ngơi — Ethereal Ambient (8 giờ)' `yzSqgYS-WI0`.
  `extractYoutubeVideoId` accepts bare ID, watch?v=, youtu.be/, /shorts/,
  /embed/, /live/, music.youtube.com. youtube_player_iframe 6.x API:
  `playVideo()`/`pauseVideo()`/`loadVideoById`/`cueVideoById`/`setVolume(int)`/`close()`;
  NO `isReady`, NO `play()`/`pause()`. The player widget lives in a 1×1
  box in the body Stack — NEVER inside `Offstage` (that breaks the whole
  body on Flutter web).
- **Smoke** (`smoke_particle_effect.dart`): 32 lifecycle puffs, vertical
  ovals (~1.8× stretch), lavender RGB 228/232/248, `RadialGradient`, no
  `MaskFilter.blur`. Used full-screen (home/history/select_deck/new_reading)
  and as small incense smoke.
- **Donation QR:** VietQR/BIDV, TRAN VAN TIEN, account 21110001575517,
  BIDV – CN Hà Nội. Asset `assets/images/donate_qr.png` (900×1020).
- **Daily Card (per account, LIVE since PR #39, verified):**
  `cards[_fnv1a32("$seed|$dateKey") % cards.length]`, `dateKey` = local
  date `yyyy-MM-dd`, seed = `account:<Google sub>` (fallback email);
  guests get a persisted per-device UUID
  (`tarotdesk_guest_device_seed` in SharedPreferences). Live-verified
  2026-11-21: admin → Bảy Cốc, 2nd test user → Ba Gậy, guest → Chín Gậy.
  Refreshes at midnight via a 1-minute timer. Tapping it opens a detail
  dialog (big image + name + meaning, "Đóng"), never starts a reading.
  The old same-card-for-everyone rule (`dayOfYear % 78`) is gone.
- **Home header:** custom Row (not AppBar): "TarotDesk" title
  (TwinklingTitle if enabled) left; info IconButton → AboutScreen and
  settings IconButton → SettingsScreen on the right; admin button
  (middle icon, looks like a server) visible only when `isAdmin`.
- **Admin rule:** the logged-in Google account `orenji11299@gmail.com`
  is the admin (see §5). Admin manages shared decks and reviews
  submissions in the admin screen (`lib/presentation/screens/admin/`).
- **Cloud sync (live):** `cloud_sync_service.dart` replaces the old Gist
  sync; same data JSON shape
  (`{"version":1,"exportedAt":...,"decks":[...],"cards":[...],"readings":[...]}`);
  same policy — local has only seed deck → download; cloud empty + local
  has user data → upload; sync is automatic two-way on login + page
  reload only (PR #44 removed the "Đồng bộ ngay" button);
  download imports only missing items, NEVER deletes local data.
  `AuthProvider` holds the session token in SharedPreferences;
  `startGoogleLogin()` is public `Future<void>` and never throws (errors
  land in `lastAuthErrorCode`).
- **Table dialog (on main since PR #39, live-verified):** the dialog is
  rebuilt inside `Consumer<SettingsProvider>` (chips/toggles update live);
  only `Gỗ Sồi` is offered as a table surface (Stone/Universe have no
  painted art — `tableStyle` was a dead setting); `Lá Khô` is excluded
  from decor choices (no real image); max-4 accounting sanitises
  asset-less saved items; "Xong" uses `scrollable: true`. **Open bug
  (§7.2):** selecting "Hương Trầm" alone does not auto-enable the
  "Hiện đồ decor" toggle, and deselecting all decor leaves the toggle ON.
- **Library (on main since PR #39, live-verified):** gold `_SectionHeader`
  over "Bộ bài của tôi (n)" (`library.myTitle`) and "Bộ bài chung (n)"
  (`library.sharedTitle`). Only two groups exist in the data (my decks /
  shared decks) — no invented categories, no filter chips.
- **Guide (on main):** 15 slides, horizontal `.track` (`translateX`
  0.55s ease-out), prev/next + dots + counter + keyboard + swipe. PR #39
  changes (ON main): track = camera move (`transform .6s power2.inOut`),
  entrances fade+scale (`0.5s expo.out`, 50 ms stagger, land dead still),
  parallax far-plane background, dots are real `<button>`s (visible on
  phones), `#sN` deep links, `prefers-reduced-motion`, NO `translateY`
  anywhere. Slide 3 uses `home-crop.png` — which is WRONG (no red
  outlines/badges, stray Pinterest button; see §7.3).

### 9.3 Write path (critical)

- The Muse GitHub App integration returns **403 on contents writes**. All
  code changes go through the user's own GitHub session in Chrome (a
  browser task with `browser: "device"` — device Chrome is signed in as
  Neito112 and needs no login; new tasks default to the CLOUD browser,
  which is NOT signed in). Files are passed via the `browser.browse`
  `files` parameter with each file's repo path as its purpose.
- A browser task's upload tool ONLY accepts files granted to that task via
  the `files` parameter. It cannot save page screenshots as PNG files and
  cannot put local paths into GitHub's file picker. (2026-11-21 lesson: a
  task that mistypes a file's grant code cannot upload that file — the
  main agent cannot see or re-issue the grant string; the recovery is to
  close that task and start a fresh one with the file granted again.)
- GitHub MCP reads work (flag is `--arguments-json`, NOT `--args`); for file
  CONTENTS use raw.githubusercontent.com via curl (the MCP tool returns
  only a confirmation for contents).
- **VM browser is blocked:** the VM's egress proxy is
  `hatch-egress-proxy:3128` (curl works through it), but Chromium in the VM
  cannot reach the internet (`ERR_NO_SUPPORTED_PROXIES` /
  `ERR_TUNNEL_CONNECTION_FAILED`). VM-side screenshots and VM-side browser
  interaction with the live app are BLOCKED. Screenshots must come from the
  device browser or the user. The automated Chrome window is fixed at
  ~1173×855 (cannot be resized to the 1375×847 verification standard);
  DevTools/device emulation will NOT open.
- Verification standard: 1375×847, DevTools closed. The verifying browser
  cannot hear audio — only player state/UI can be confirmed.
- **GitHub API unauthenticated rate limit (60/hour) is easily hit** from
  this VM (shared egress IP) — the branches endpoint may still answer
  when commits are rate-limited. Do not depend on the API for state;
  use the repo pages in the device browser instead.

### 9.4 Known quirks and leftovers

- 'Lá Khô' decor still has no real image. PR #39 removed it from
  choices and renders nothing for it. A painted cut-out asset is still
  needed to re-add it.
- Stone (`Đá Cổ`) / Universe (`Vũ Trụ`) table styles have no painted art;
  `tableStyle` was a dead setting (all devices silently showed painted
  wood). PR #39 hides them from the dialog + Settings.
- First-open image loading is slow (~30 s white screen = Flutter web
  bootstrap, not fixable in Dart).
- Old unused assets remain in the repo (e.g. `table_3d_painted.png`,
  `table_3d_flat.png`, old photo decor PNGs, `cloth_*_painted.png`; after
  PR #26 the now-unreferenced `table_wood_texture.jpg` /
  `table_stone_texture.jpg` / `tarot_main_background.jpg` — the last is
  still used by the Home background on non-desktop).
- The 3 dead `new_reading_screen_step410/426/454.dart` snapshot files were
  DELETED in PR #42 (nothing imported them).
- No mid-flight frame of the stage→tray flight has ever been captured
  (animation faster than the screenshot rate); flight is supported by
  landing-state evidence. Same for the guide's 0.55s slide transition.
- Guest mode is NOT persisted across reloads (by design from PR #31).
- Google login redirect-failure feedback in Settings is minimal (error
  surfaces on the login screen after logout).
- Shared decks in D1 are EMPTY (v1). OAuth app in Testing (2 test users
  only).
- The reading screen's table-settings dialog used to capture `settings`
  from the outer scope, so it wouldn't live-rebuild if the language was
  changed while that dialog was open — fixed in PR #39 by the `Consumer`
  rebuild.
- On main, a toast sometimes shows the previous cloth's name after
  switching (reported, not reproduced in code — no cloth toast exists;
  the 400 ms cross-fade is the likely source).
- Deck stack back colour changed between readings (bright yellow → dark
  olive) after a Settings cloth change — unexplained, cosmetic; the back
  colour comes only from `theme.primaryColor`, no cloth path exists.
- `showTable = false` leaves cloth + decor floating on black (by design —
  the three toggles are independent layers; open question, §7.4).

### 9.5 Scalability (answered to the user 2026-11-21)

- No user limit, no server to congest: static hosting on GitHub Pages
  (CDN) + Cloudflare Worker + D1. Practical limits: GitHub Pages
  bandwidth 100 GB/month (soft). The only bottleneck is the user
  hand-approving deck submissions (by design).
- If the app gets hot and hits the Pages limit, do NOT buy a GitHub plan:
  GitHub Pro/Team does NOT raise the Pages bandwidth limit (100 GB/month
  applies to free and paid alike). Move hosting to Netlify / Vercel /
  Cloudflare Pages (free, more bandwidth) — the app is static so the move
  is easy and the URL can stay the same.
- Cloudflare free tier supports ~20,000 daily active users (see §3.2).
  Translation (Workers AI m2m100, 10,000 Neurons/day free) covers the
  whole app at any realistic size; one 78-card deck translation into one
  language is ~1,400 Neurons (~$0.01 at list price) and the D1 cache
  means it is paid once, not per user (estimate from seeded text size,
  not measured — verify on first real run).

## 10. Local working files (this machine)

- `~/workspace/AGENT_LOG.md` — this file (local source; push it to the
  repo root when it changes — it is a real deliverable, not an afterthought).
- `~/workspace/tarotdesk-review/out/` — the 6-item review-fixes build
  (12 app/guide files + Worker snippet) + `REPORT.md` (49 KB, the full
  write-up: HyperFrames re-research, Daily Card per-account, i18n
  mechanism, table-dialog audit, library headers). Base main `72f944e`.
  MERGED as PR #39 (hotfix PR #40).
- `~/workspace/tarotdesk-i18n-display/out/` — the i18n display-wiring
  build. MERGED as PR #41.
- `~/workspace/tarotdesk-i18n-thorough/out/` — the thorough-translation
  build (16 files + `REPORT.md`) + `~/workspace/tarotdesk-i18n-thorough/audit/`
  (FINDINGS.md, VERIFICATION.md, KEYS_NEEDED_A/B.md, KEYS_ADDED_C.md).
  MERGED as PR #42.
- `~/workspace/tarotdesk-lang-loading/out/` — the PR #43 loading-screen
  language switch build. MERGED as PR #43.
- `~/workspace/tarotdesk-pretranslate/out/` — the V1 pre-translation
  package (SUPERSEDED by V2 — do not deploy).
- `~/workspace/tarotdesk-pretranslate-v2/out/` — the V2 permanent-data
  package (DEPLOYED): Worker `tarotdesk-oauth-with-deck-translations.js`
  (1,371 lines, live v11), migration `001-deck-translations.sql` +
  runner, seed script `seed_base_deck_v2.py` (316 rows stored), 14 app
  Dart files (MERGED as PR #44), `REPORT.md` (552 lines), `WIRING.md`
  (256 lines), `SYNC.md` (107 lines), `DEPLOY.md` (118 lines),
  `rollback/` (the pre-V2 live Worker source).
- `~/workspace/tarotdesk-decor-toggle/out/` — the decor-toggle fix
  (`settings_provider.dart` +7 lines + `REPORT.md`). Being pushed in the
  combined PR with the home-crop fix + this log update.
- `~/workspace/tarotdesk-homecrop/out/` — the guide slide-3 fix
  (`home-crop.png` + minimally-edited `index.html` + `REPORT.md`).
  Being pushed in the combined PR.
- `~/workspace/tarotdesk-translate-deploy/out/` — the `/translate` deploy
  package: `worker/tarotdesk-oauth-with-translate.js` (716 lines, 25,695
  bytes — the live 419-line Google backend + 297 added lines),
  `worker/d1-translations-migration.sql`, `worker/DEPLOY_STEPS.md`,
  `REPORT.md`. DEPLOYED via the Cloudflare API (deployment `507f71d3`); the POST
  "hang" was a cold start + cache bug, both fixed (see §3.2/§7.1). The same JS is on the holding
  branch `docs/translate-worker-source` (commit `4a080fc`).
- `~/workspace/tarotdesk-guide-pr/out/` — PR #36/#37 guide build outputs
  (about_screen + localization + pubspec + guide index.html + images).
- `~/workspace/tarotdesk-guide/` — guide deck `index.html` (15 slides) +
  `images/` (`home.png` + `phone-home.png` are real; `home-crop.png` is
  the annotated crop from the review PR).
- `~/workspace/tarotdesk-readme/` — PR #38 README build (README.md +
  `docs/screenshots/home-desktop.png` + `home-phone.png`).
- `~/workspace/tarotdesk-google/out/` — PR #34 Google login build
  (`worker/tarotdesk-google-backend.js`, 419 lines, ADMIN_EMAIL already
  `orenji11299@gmail.com`; `worker/schema.sql`, 55 lines; `app/lib/`
  12 files) + `~/workspace/tarotdesk-google/REPORT.md`.
- `~/workspace/tarotdesk-google-hotfix/out/app/lib/` — PR #35 hotfix
  (settings_screen.dart + localization.dart).
- `~/workspace/tarotdesk-login/out/` — PR #30 login/server build (14 files).
- `~/workspace/tarotdesk-login-hotfix/out/` — PR #31 guest hotfix (4 files)
  + `tarotdesk-oauth-worker.js` (the OLD GitHub proxy Worker source —
  superseded by the Google backend).
- `~/workspace/tarotdesk-login-worker/out/` — PR #32 proxy fix
  (github_service.dart).
- `~/workspace/tarotdesk-webflow/out/` — PARTIAL GitHub Web Flow build
  (SUPERSEDED — do not push).
- `~/workspace/tarotdesk-i18n/out/` — PR #29 i18n build outputs.
- `~/workspace/tarotdesk-pr16/` — older staged files (STALE — predates
  i18n/login; its `about_screen.dart` must NOT be pushed as-is),
  `donate_qr.png` (900×1020, 706KB).
- `~/workspace/research_notes/hyperframes-smooth-card-animation-20261120-1501/report.md`
  — HyperFrames motion principles (one move = one tween; animate transform
  + opacity only; arrivals on long-tail ease-outs; exits 40–50% shorter;
  landed elements dead still; measure rects once before a flight).
- Local clone `~/workspace/tarotdesk-repo` is old (PR #13) — reading only.

## 11. How to work on this repo (for the next agent)

1. Read this file first (start at §0), then check `main` HEAD and the live
   preview. If the log's HEAD is behind `main`, re-derive the state from
   the PR history (§4) and the preview before trusting it.
2. Build in a workspace directory (e.g. `~/workspace/tarotdesk-<topic>/out/`)
   with complete files; verify statically (tr() key completeness across all
   5 languages, bracket balance, no leftover references to removed code).
   There is no Flutter/Dart toolchain in the VM — the GitHub Actions build
   is the real compile check.
3. Push via a device-Chrome browser task (see §9.3): branch from `main`,
   one PR, merge commit, watch Actions, then verify on the live preview
   (fresh tab + `?v=...`). Leave the app clean (§0.3 step 5).
4. **Delete your branch after its PR merges.** Verify the branch list
   afterwards (only `main` + in-flight branches should remain).
5. Update this log (header, PR table, affected sections, §7 open work)
   when you land a meaningful change, and update `~/MEMORY.md` with
   durable facts. If the user corrects a rule (as with the 2026-11-21
   15:48 i18n correction), update the rule everywhere it appears — code,
   docs, README — and mark the old rule SUPERSEDED, do not silently
   leave the wrong version standing.

## 12. Guide replaced with scene-based animation (2026-11-23)

- Replaced `tarot_desk_flutter/web/guide/index.html` with a new scene-based HTML guide animation (15 scenes, verified content).
- Added `tarot_desk_flutter/web/guide/assets/` (gsap.min.js + 12 screenshots: qr-card, home-top, add-deck, daily, history, library, music, reading-empty, reading-stage, select, settings). `reading-tray.png` was NOT uploaded: its granted file ID was rejected by the upload tool, so the scene that references it may show a broken image until it is re-uploaded.
- Deleted the stale `tarot_desk_flutter/web/guide/images/` folder (home.png, home-crop.png, phone-home.png).
- Committed directly to main, no branch/PR, per the user's instruction: `b94f108` (index.html), `2e74f27` (assets), `a869c53` / `fc24a91` / `2a543c1` (image deletions). The flutter-web-preview run and live guide check followed the push; results were reported back to the user.

## 13. Pop-up hướng dẫn khi đăng nhập/tải lại (2026-11-23)

- Hiển thị hướng dẫn dạng pop-up (Dialog) ngay khi HomeScreen mount lần đầu sau khi đăng nhập hoặc tải lại trang, cho cả người dùng đăng nhập Google và khách (guest).
- Thêm cài đặt showGuidePopup (mặc định true) vào UserPreferences, lưu cùng các cài đặt khác qua SettingsProvider.
- Dialog nhúng guide HTML (tarot_desk_flutter/web/guide/) bằng iframe trên web (guide_view_web.dart, qua guide_view.dart / guide_view_stub.dart); trên native mở liên kết ngoài.
- Chân dialog có checkbox "don't show again": tích và đóng là lưu ngay (showGuidePopup = false), tải lại app không hiện pop-up nữa.
- Màn hình Settings có công tắc bật lại hướng dẫn; bật rồi tải lại thì pop-up hiện lại.
- Màn hình About: liên kết "Hướng dẫn chi tiết" dùng chung hằng số URL trong guide_url.dart.
- Files changed: lib/data/models/user_preferences.dart, lib/logic/settings_provider.dart, lib/core/localization.dart, lib/core/guide_url.dart (mới), lib/core/guide_view.dart (mới), lib/core/guide_view_web.dart (mới), lib/core/guide_view_stub.dart (mới), lib/presentation/screens/home_screen.dart, lib/presentation/screens/settings_screen.dart, lib/presentation/screens/about_screen.dart, tarot_desk_flutter/pubspec.yaml.
- Committed directly to main, no branch/PR: 17256d7, e07fe0f, 0efa1da, 7ca35cc, f46da68 (các file trên) + commit này (AGENT_LOG.md §13).
## §14 — 23/11/2026 — Hoàn tất push pop-up hướng dẫn (thiết kế đã sửa, thay thế các bản cũ)

- Đẩy lại TOÀN BỘ file của tính năng pop-up hướng dẫn lên `main`, thay thế các bản cũ từ lần push trước bị dừng giữa chừng: `c530b56` (user_preferences.dart), `4aa4a2d` (settings_provider.dart), `fcf0943` (localization.dart + guide_url.dart, guide_view.dart, guide_view_web.dart, guide_view_stub.dart, guide_dialog.dart mới), `36486ef` (home_screen.dart, settings_screen.dart, about_screen.dart), `853a6ed` (pubspec.yaml), `41264d3` (web/guide/index.html).
- Thiết kế đã sửa: hộp thoại hướng dẫn 15 chương hiển thị TRONG app (web: nhúng HTML guide trong iframe; nền tảng khác: nút mở bằng trình duyệt). Nút ⓘ trên màn hình Home mở thẳng hộp thoại hướng dẫn, không mở màn hình About, không nhảy ra liên kết ngoài.
- Checkbox "không hiện lại" trong hộp thoại chỉ tắt pop-up TỰ ĐỘNG khi đăng nhập/tải lại; mở hướng dẫn bằng tay (nút ⓘ, liên kết trong màn hình About) luôn hoạt động.
- Màn hình About chuyển vào Cài đặt qua hàng "Giới thiệu"; liên kết hướng dẫn trong màn hình About mở hộp thoại trong app (không mở tab ngoài). Cài đặt có công tắc bật lại pop-up tự động.
- Guide `web/guide/index.html` đã thay mới: gỡ bỏ "Bản nháp" ở tiêu đề/thanh trên, và thêm bản sửa ẩn thanh checkbox của chính guide khi được nhúng trong iframe của app (trong pop-up chỉ còn MỘT checkbox "không hiện lại" của hộp thoại).
- §13 ở trên do lần push trước (bị dừng giữa chừng) ghi lại; mục này ghi nhận lần push hoàn tất với thiết kế đã sửa.

## §15 — 23/11/2026 — Kho bộ bài: bộ cơ bản là bộ chung, đổi thứ tự mục

- Sửa kho bộ bài ("Danh Sách Bộ Bài Tarot"): trước đây mục "Bộ bài của tôi (1)" ở trên chứa "Bộ bài cơ bản", còn "Bộ bài chung (0)" ở dưới trống — ngược với thiết kế. Bộ bài cơ bản (id=1, deck_key 'base', bản dịch owner 'shared') LÀ bộ bài chung, nên nay hiện trong mục chung (đầu mục, từ dữ liệu local) cùng các bộ chung từ server; mục "Bộ bài của tôi" chỉ gồm các bộ do người dùng tạo/sao chép nên mặc định TRỐNG.
- Thứ tự mục đảo lại: "Bộ bài chung" Ở TRÊN, "Bộ bài của tôi" Ở DƯỚI.
- Mục chung: nạp bộ cơ bản local riêng (_loadBasicDeck, không chờ mạng) rồi hiện thành một hàng ListTile (tên + số lá + nút "Xem"); số lượng trong tiêu đề = 1 (bộ cơ bản) + số bộ từ server; dòng "Chưa có bộ bài chung nào." chỉ hiện khi cả hai đều trống.
- Hộp xem trước của bộ cơ bản: nạp bản dịch đã lưu theo deck_key 'base' (preloadDeckTranslations deckKey=kBaseDeckKey); nút hành động là "Chọn" thay vì "Sao chép" (đã có sẵn trong kho), và bị vô hiệu hoá với nhãn "Đang chọn" khi đã đang chọn; bấm "Chọn" chỉ chọn bộ đó, không tạo bản sao.
- Mục "Bộ bài của tôi" lọc bỏ bộ cơ bản (id=1); khi trống hiện dòng mới "Bạn chưa có bộ bài nào." (khóa library.myEmpty, đủ 5 ngôn ngữ).
- Files changed: lib/presentation/screens/select_deck_screen.dart, lib/core/localization.dart (+ AGENT_LOG.md §15).
- Committed directly to main, no branch/PR.

## §16 — 23/11/2026 — Kho bộ bài: bộ cơ bản hiển thị Y NHƯ THẺ CŨ (sửa lại §15)

- §15 đổi bộ cơ bản thành hàng chữ ListTile trong mục chung — SAI: mất cách hiển thị thẻ lớn (ảnh bìa The Fool + ngày tạo + "Đang chọn") và mất đường bấm vào chi tiết để sửa nội dung lá. Người dùng yêu cầu: vẫn hiển thị bộ bài như cũ, chỉ đổi tên mỗi cái đầu mục.
- Sửa lại: bộ cơ bản hiện trong mục "Bộ bài chung" (trên) BẰNG ĐÚNG thẻ _DeckCard cũ (lưới, ảnh bìa, ngày tạo, "Đang chọn"), bấm vào mở DeckDetailScreen (quản lý) để sửa nội dung lá như trước. Chỉ khác: ẩn nút gửi lên server + nút xoá (tham số mới _DeckCard.showManageActions = false — bộ chung có sẵn, không gửi cũng không xoá); khi chưa chọn thì chỉ còn nút "Chọn".
- Bỏ hẳn đường hộp xem trước cho bộ cơ bản (_openBasicDeck, alreadyLocal trong _showSharedDeckDialog, _basicCards) — bộ cơ bản không cần "Xem"/"Sao chép" nữa; hộp xem trước chỉ còn cho các bộ chung từ server (sao chép về kho).
- Mục "Bộ bài của tôi" vẫn ở dưới, trống mặc định (library.myEmpty).
- Files changed: lib/presentation/screens/select_deck_screen.dart (+ AGENT_LOG.md §16).
- Committed directly to main, no branch/PR.
## §17 — 23/11/2026 — Phím tắt: ESC thoát từng lớp, Back/Forward chuột gaming

- ESC thoát từng lớp giao diện: hộp thoại / bottom-sheet đang mở thì đóng nó (ESC có sẵn); khay chọn bài trong màn trải bài thì đóng khay (_buildSelectionPanelWithEsc); còn không thì ESC quay lại màn hình trước (Focus gốc ở main.dart + _RouteStackObserver, bỏ qua khi route trên cùng là PopupRoute để không pop đúp).
- Nút Back/Forward của chuột gaming = Back/Forward của trình duyệt: mỗi màn hình có tên route riêng (RouteSettings trên 14 điểm Navigator.push: /reading/new, /admin, /settings, /library, /library/add, /deck/detail, /history, /history/detail, /deck/edit-card, /settings/about) nên địa chỉ trang đổi theo từng màn hình và lịch sử trình duyệt có từng mục riêng; _RouteStackObserver ghi nhớ route trang vừa pop (builder + settings) và dựng lại khi didPushRoute (Forward) gọi đúng URL của nó; đẩy route mới thì xoá "forward" đã nhớ, giống trình duyệt.
- ESC trong iframe hướng dẫn: trang hướng dẫn (web/guide/index.html) gửi message 'tarotdesk-guide-escape' về cửa sổ cha khi nhúng (TOC đang mở thì ESC đóng TOC trước); guide_view_web.dart lắng nghe và gọi onEscape để đóng hộp thoại (guide_dialog.dart truyền onEscape: Navigator.pop). Trang độc lập không bị ảnh hưởng.
- Files changed: lib/main.dart, lib/presentation/screens/home_screen.dart, lib/presentation/screens/history_screen.dart, lib/presentation/screens/deck_detail_screen.dart, lib/presentation/screens/settings_screen.dart, lib/presentation/screens/select_deck_screen.dart, lib/presentation/screens/new_reading_screen.dart, lib/core/guide_view_web.dart, lib/core/guide_view_stub.dart, lib/core/guide_view.dart, lib/core/guide_dialog.dart, tarot_desk_flutter/web/guide/index.html (+ AGENT_LOG.md §16).
- Committed directly to main, no branch/PR.
- Lưu ý: Forward cần kiểm chứng live (Back đã chạy; Forward là giới hạn của Flutter web Navigator 1.0 — bản sửa dùng didPushRoute + route đã nhớ; nếu live test cho thấy Forward vẫn không chạy thì cần refactor sang Router/onGenerateRoute với ID trong URL).

## §18 — 23/11/2026 — Phím tắt: sửa Forward bằng onGenerateRoute (Router)

- §17 (observer ghi nhớ route vừa pop + didPushRoute) KHÔNG sửa được Forward — kiểm chứng live 23/11: sau Back về Library, Forward vẫn đứng yên. Nguyên nhân: Navigator 1.0 + RouteSettings(name) không dựng lại được trang từ tên (trang cần cả object deck/reading/card).
- §18 chuyển sang onGenerateRoute (main.dart): mọi màn hình có dữ liệu mã hoá ID vào URL, onGenerateRoute dựng lại trang bằng cách nạp dữ liệu theo ID (các _DeckDetailRoute / _ReadingDetailRoute / _EditCardRoute bọc ngoài, hiện vòng xoay trong lúc nạp; không tìm thấy thì thông báo + nút quay lại). onUnknownRoute về màn gốc.
- URL: /reading/new, /admin, /settings, /settings/about, /library, /library/add, /history, /history/detail/<readingId>, /deck/detail/<deckId>, /deck/detail/<deckId>/view (chỉ xem), /deck/edit-card/<deckId> (thêm lá), /deck/edit-card/<deckId>/<cardId> (sửa lá). Cả 15 điểm Navigator.push chuyển sang pushNamed với URL có ID; các import màn hình thừa (không còn dùng) đã xoá.
- Observer _RouteStackObserver chỉ còn giữ stack để ESC biết hộp thoại đang mở (topIsPopup); bỏ hẳn didPushRoute / _poppedPages / _isForwardPush và WidgetsBindingObserver.
- ESC (dialog/panel/màn hình) và Back giữ nguyên, không đổi.
- Files changed: lib/main.dart, lib/presentation/screens/home_screen.dart, history_screen.dart, deck_detail_screen.dart, select_deck_screen.dart, settings_screen.dart (+ AGENT_LOG.md §18).
- Committed directly to main, no branch/PR.
