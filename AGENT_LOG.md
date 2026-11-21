# TarotDesk — Agent Log

> A detailed, agent-readable log of what has been built for this project, the
> decisions behind it, the current state, and what is still open. Read this
> first before touching the repo. It is the project's memory; keep it updated
> when you land a meaningful change.
>
> Last updated: 2026-11-21 (main HEAD `16a2410`, PR #32 merged).
> Language note: the app UI is Vietnamese-first (plus EN/ZH/KO/JA). This log
> is written in English so any agent can read it; Vietnamese proper nouns,
> user quotes and UI strings are kept verbatim.

---

## 1. Project overview

- **Repo:** `Neito112/TarotDesk` (public, branch `main`).
- **App:** `tarot_desk_flutter/` — Flutter/Dart web app (provider + sqflite).
  The `TarotDesk/` MAUI C#/XAML version is old/abandoned — never touch it.
- **Live preview (never changes):** https://neito112.github.io/TarotDesk/
  Built by `.github/workflows/flutter-web-preview.yml` on every push to `main`
  (`flutter build web --release --base-href /TarotDesk/`). Branch pushes do
  not rebuild it. `?v=...` suffixes are only cache-busting for verification.
- **Purpose:** a tarot practice/storage tool (NOT auto-interpretation or
  divination). The user needs a physical deck; the app stores decks, draws
  cards, keeps reading history. Primary platform is Android phone, with iPad
  and PC in parallel; layout is mobile-first and adaptive.
- **Owner / admin:** GitHub `Neito112`; Google account
  `thewolverineking@gmail.com` (Cloudflare + Google Cloud owner).

## 2. Current state (2026-11-21, main `16a2410`)

- Main HEAD is `16a2410` (merge of PR #32). The last Actions run (#33)
  succeeded (1m50s). The live preview serves that build.
- **What works:** Home (Daily Card, new reading), reading screen (painted
  3D table, flat changeable cloth, changeable decor, deck stack, stage +
  tray, draw/collect flights, smoke, mystic music incl. YouTube links),
  library / add-deck / edit-card, history, settings (theme, cloth, decor,
  language), About + donation QR, i18n (vi/en/zh/ko/ja), guest mode.
- **Login is in transition (see §5).** The app currently opens on a login
  screen with "Đăng nhập bằng GitHub" (Device Flow — BROKEN by design, see
  §5) and a "Dùng offline" guest button. Guest mode works fully offline
  (local sqflite). GitHub login is ABANDONED; Google login is the chosen
  replacement and is NOT built yet.
- **Data is local-only right now.** Decks + history live in sqflite
  (`tarot_desk.db`, version 5). No cloud sync is live.

## 3. Infrastructure

### 3.1 GitHub Pages + Actions

- Workflow: `.github/workflows/flutter-web-preview.yml` (subosito
  flutter-action `channel: stable`, `flutter pub get`,
  `flutter build web --release --base-href /TarotDesk/`).
- If a run fails ONLY at `deploy-pages` with "Found 0 artifact(s)", re-run
  the failed deploy job once. If it fails at the flutter build step, read
  the exact build-log errors first — never re-run blindly.
- Flutter web's service worker caches aggressively. To verify a fresh build,
  use a new tab + a cache-busting URL (`?v=...`) + reload; sometimes ALL
  github.io tabs must be closed first.

### 3.2 Cloudflare Worker `tarotdesk-oauth` (the backend)

- **URL:** https://tarotdesk-oauth.thewolverineking.workers.dev
- **Account:** Thewolverineking@gmail.com. **Source:**
  `~/workspace/tarotdesk-login-hotfix/tarotdesk-oauth-worker.js` (local copy;
  the deployed code is the same).
- **History:** created to proxy GitHub's OAuth endpoints, which return NO
  CORS headers (a browser app cannot call them directly). Deployed
  2026-11-21, version `b5ab38fd`, verified live (GET returns the proxy
  banner; POST `/device-code` returned a real GitHub device code + CORS
  headers for `https://neito112.github.io`).
- **Current endpoints:** `POST /device-code` and `POST /access-token`
  (forward the form body to `github.com/login/device/code` and
  `github.com/login/oauth/access_token`, with `Accept: application/json`
  upstream). CORS restricted to `https://neito112.github.io` (+ localhost).
- **Secrets (Production, never in code/chat):** `GOOGLE_CLIENT_SECRET` was
  added 2026-11-21 (Worker redeployed `fa355b12`, "100% Ready"). It holds
  the Google OAuth client secret.
- **Free-tier limits (verified Nov 2026):** Workers 100,000 requests/day
  (Error 1027 beyond, resets 00:00 UTC), 10 ms CPU per request (waiting on
  fetch/KV/DB does NOT count), 128 MB memory. KV: 100,000 reads/day but only
  1,000 writes/day — too tight for user data, use only for config/cache.
  D1: 5,000,000 rows read/day, 100,000 rows written/day, 5 GB storage —
  the right store for per-user data. R2: 10 GB. Paid plan is $5/month
  (10M requests/month) if it ever outgrows free.
- **Capacity estimate:** at ~5 Worker requests per active user per day,
  the free tier supports ~20,000 daily active users. No payment needed now.
- **Workers do NOT sleep.** Unlike free container hosts (Render/Heroku),
  there is no deep sleep / multi-second wake-up. At most a cold start of a
  few tens of milliseconds on the first request after idle. GitHub Pages
  and D1 are also always-on.

### 3.3 Google Cloud (OAuth for the future Google login)

- **Project:** "TarotDesk" (Project ID `tarotdesk`, number `123408820943`).
- **OAuth consent screen:** User type External, app name "TarotDesk",
  support + developer contact `thewolverineking@gmail.com`, scopes
  `openid`, `email`, `profile`.
- **OAuth client "TarotDesk Web" (Web application).**
  **Client ID (public):**
  `123408820943-7jqa6sqoncp591485d2uo9euumvnlpii.apps.googleusercontent.com`
- **Authorized redirect URIs:** `https://neito112.github.io/TarotDesk/` and
  `http://localhost:8080/`.
- **⚠️ Publishing status is "Testing".** Only listed test users can sign in
  until the app is published (or test users are added under Audience). This
  must be resolved before real users can log in.
- The client secret lives ONLY as the Worker secret `GOOGLE_CLIENT_SECRET`
  (see §3.2). Never put it in the app, the repo, or chat.

### 3.4 GitHub OAuth App (legacy, for reference only)

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
| #29 | `5e4ac3f` | i18n: UI in EN + ZH + KO + JA plus a language picker in Settings (181 keys). Card meanings stay Vietnamese. |
| #30 | `8cd0abc` | GitHub login + server (Device Flow; per-account private Gist; shared decks in `server/decks/`; submissions via PR to `server/submissions/`; Neito112 = admin). **Device Flow does NOT work from the browser (no CORS) — see §5.** |
| #31 | `b9b9e6c` | Guest hotfix: "Dùng offline" button; guests keep full local use. Quirks: guest logout needs a page reload to show the login screen; guest mode is not persisted across reloads. |
| #32 | `16a2410` | Route GitHub OAuth through the Cloudflare Worker proxy (github_service.dart constants → Worker URLs). Run #33 succeeded. Verified live: login shows a real device code, no more network error. |

Branch naming used: `ui/<short-slug>` (e.g. `ui/login-oauth-proxy`). Merges use
merge commits (not squash). Every push to `main` rebuilds the preview.

## 5. Login — the full arc and the current decision

- **2026-11-21 10:27 (user):** the app needs login for personalization; the
  current app becomes the server version; opening the app requires GitHub
  login; each account's data is set up automatically; decks saved in a
  server folder of the original repo are visible to all users; other users
  can submit decks and wait for approval via the email linked to GitHub.
- **Design approved 10:33:** GitHub-only, no backend, no separate repo.
  Original repo = server (shared decks in `server/decks/`); ONE app for
  everyone; Neito112 = admin. Login via GitHub **Device Flow**; per-account
  data = private GitHub **Gist**; submissions = PR to `server/submissions/`.
- **PR #30 merged 12:16** — but Device Flow **does not work from a browser**:
  GitHub's OAuth endpoints return NO `Access-Control-Allow-Origin`, so the
  browser blocks the response and the app reports "Không có kết nối mạng".
  A proxy is required. This is a design flaw of Device-Flow-from-browser,
  not a code bug.
- **PR #31 (guest hotfix) merged 12:35** — restores access via
  "Dùng offline" while login is broken.
- **Cloudflare Worker deployed + verified 13:16** (see §3.2).
- **PR #32 merged 13:29** — app routes OAuth through the Worker. Verified:
  tapping login shows a real device code (no network error). But completing
  Device Flow then hit GitHub's **sudo-mode email verification** on
  `github.com/login/device/authorize`, and the code the user entered was
  rejected for wrong format.
- **2026-11-21 13:26 (user): "cách đăng nhập này không ổn"** — Device Flow
  is ABANDONED. The one-tap GitHub Web Flow (redirect) was started as a
  replacement and a coordinator completed a partial build
  (`~/workspace/tarotdesk-webflow/out/`), but it is SUPERSEDED — do not push.
- **2026-11-21 13:32 (user): "phương án google đi, ít người biết dùng
  github lắm"** — **Google login is the decision.** Few users know GitHub,
  so login must be Google. The Google Cloud OAuth client is created (see
  §3.3); the secret is in the Worker. **Google login itself is NOT built
  yet** — that is the main open work (§7).
- **Planned Google architecture:** app redirects to Google → code back →
  Worker exchanges the code for tokens (stored secret) → Worker verifies
  the Google ID token → per-user data in **D1** (database `tarotdesk-data`,
  binding `DB`, to be created + bound to the Worker) keyed by Google sub;
  email used for notifications; shared decks + submissions via Worker/D1;
  admin = Google email `thewolverineking@gmail.com`. The Gist/PR storage
  model is replaced by Worker + D1.
- **Open decision:** after login works, decide whether to remove the guest
  "Dùng offline" button to restore the original "login required" design.
  The user originally wanted login required; do not remove the guest button
  without telling them.

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
  permission.
- **Saved state to preserve during verification:** cloth = Thảm Đen, decor =
  Đá Thạch Anh (crystal) + Hương Trầm (incense), table = Gỗ Sồi, theme =
  Tối Obsidian (default_dark), all 3 layer-display toggles ON, language =
  Tiếng Việt (vi). Never save test data into the user's deck (the library
  must stay only "Bộ bài cơ bản", 78 lá); never save test readings. Pause
  music before ending a verification. After a login verification, leave the
  app LOGGED OUT on the login screen; logout must not delete local data.

## 7. Open work (as of 2026-11-21)

1. **Google login (main open work).** Build the Worker backend + D1 +
   app changes (see §5 planned architecture). Prerequisites done: Google
   OAuth client created, secret in Worker. Still needed: (a) resolve the
   OAuth "Testing" status (add test users under Audience, or publish the
   app) so real users can sign in; (b) create the D1 database
   `tarotdesk-data` and bind it to the Worker as `DB`; (c) build + deploy
   the Worker backend (Google token exchange, ID-token verification,
   session, D1 data/submissions/shared-decks/admin endpoints); (d) rewrite
   the app auth (Google redirect login, callback handling, session) and
   replace the GitHub data layer (Gist/PR) with Worker/D1 calls; (e) push,
   merge, verify end-to-end as the admin (Google login → admin UI → logout).
2. **Screenshots (2 of 18 captured).** Real shots exist for
   `home.png` (desktop Home) and `phone-home.png` (iPhone Home) in the
   guide images folder. The other 16 inner screens could NOT be captured
   automatically (no deep links; VM browser blocked; device Chrome cannot
   save PNGs). Waiting on the user's choice: (a) user takes over the browser
   and captures them (Win+Shift+S), or (b) build the guide + README now
   with the 2 real shots + app artwork for inner slides, replacing later.
   Needed: daily, reading-empty, reading-stage, reading-tray, select,
   library, add-deck, history, settings, music, about, donate (desktop) +
   phone-reading, phone-library, phone-settings, phone-about.
3. **Guide HTML deck + About link.** A 15-slide HyperFrames-style HTML guide
   is built (`~/workspace/tarotdesk-guide/index.html`) and will live at
   `tarot_desk_flutter/web/guide/index.html` → `/TarotDesk/guide/`. The
   About-screen guide link is staged but STALE (must be re-applied onto the
   current `about_screen.dart` with new localization keys, and
   `url_launcher` added to the current pubspec). Blocked on screenshots (§7.2).
4. **README rewrite.** The repo-root `README.md` is outdated (an old MAUI
   planning note). Rewrite it as a proper product introduction with real
   screenshots. Blocked on screenshots (§7.2). Branch
   `docs/readme-screenshots` exists (level with an old main, no commits).
5. **Guest-button decision** (see §5): keep or remove "Dùng offline" once
   real login works.
6. **Real-phone checks (awaiting the user):** the PR #26 painted background
   on a real phone; whether the Home history list scrolls on a phone.

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

### 9.1 Repo layout (main, `tarot_desk_flutter/`)

- `lib/core/`: `constants/`, `localization.dart`, `responsive.dart`,
  `theme/`.
- `lib/data/datasources/`: `database_helper.dart`, `db_init_stub.dart`,
  `db_init_web.dart`, `gist_sync_service.dart`, `github_service.dart`,
  `preferences_service.dart`, `server_deck_service.dart`.
  (The GitHub data layer — `gist_sync_service`, `github_service`,
  `server_deck_service` — is being replaced by the Worker/D1 layer for
  Google login; see §5/§7.1.)
- `lib/data/models/`: `tarot_card.dart`, `tarot_deck.dart`,
  `tarot_reading.dart`, `user_preferences.dart`.
- `lib/logic/`: `auth_provider.dart`, `deck_provider.dart`,
  `reading_provider.dart`, `settings_provider.dart`.
- `lib/presentation/screens/`: about, add_deck, admin, deck_detail,
  edit_card, history, home, login, new_reading, reading_detail,
  select_deck, settings (+ 3 dead snapshot files
  `new_reading_screen_step410/426/454.dart` — never deleted).
- `lib/presentation/widgets/`: `glass_panel.dart`,
  `mystic_music_player.dart`, `smoke_particle_effect.dart`,
  `tarot_card_image.dart`, `twinkling_title.dart`.
- `pubspec.yaml` dependencies: flutter, cupertino_icons ^1.0.6, provider
  ^6.1.1, sqflite ^2.3.0, sqflite_common_ffi ^2.3.0,
  sqflite_common_ffi_web ^1.1.2, path ^1.8.3, shared_preferences ^2.2.2,
  image_picker ^1.0.7, google_fonts ^6.1.0, youtube_player_iframe ^6.0.3,
  http ^1.2.0. Assets: the whole `assets/images/` folder. NO url_launcher
  on main yet (the guide PR will add it).

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
  181 keys at PR #29, 239 after PR #30, 241 after PR #31. Deliberately
  untranslated: card/deck content, stored option-value names (e.g. 'Gỗ
  Sồi', 'Nhung Tím' — code compares against them), the 5 preset track
  titles, code comments/debug strings.
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
- **Daily Card:** `cards[_dayIndex(DateTime.now()) % cards.length]`,
  `_dayIndex(d) = d.difference(DateTime(d.year, 1, 1)).inDays`; refreshes
  at midnight via a 1-minute timer. Tapping it opens a detail dialog (big
  image + name + meaning, "Đóng"), never starts a reading.
- **Home header:** custom Row (not AppBar): "TarotDesk" title
  (TwinklingTitle if enabled) left; info IconButton → AboutScreen and
  settings IconButton → SettingsScreen on the right; admin button visible
  only when admin.
- **Admin rule:** the logged-in account `Neito112` (GitHub) is the admin;
  with Google login this becomes the Google email
  `thewolverineking@gmail.com`. Admin manages shared decks in
  `server/decks/` and reviews submissions. (Storage is moving to Worker/D1;
  see §5.)
- **GitHub data (legacy, being replaced):** per-account private Gist
  (`TarotDesk — dữ liệu của <login>`, file `tarotdesk-data.json`,
  `{"version":1,"exportedAt":...,"decks":[...],"cards":[...],"readings":[...]}`);
  shared decks in `server/decks/`; submissions via PR to
  `server/submissions/`. Sync policy: local has only the seed deck + no user
  data → download; Gist empty + local has user data → upload; "Đồng bộ
  ngay" uploads last-write-wins; download imports only missing items and
  NEVER deletes local data.

### 9.3 Write path (critical)

- The Muse GitHub App integration returns **403 on contents writes**. All
  code changes go through the user's own GitHub session in Chrome (a
  browser task with `browser: "device"` — device Chrome is signed in as
  Neito112 and needs no login; new tasks default to the CLOUD browser,
  which is NOT signed in). Files are passed via the `browser.browse`
  `files` parameter with each file's repo path as its purpose.
- A browser task's upload tool ONLY accepts files granted to that task via
  the `files` parameter. It cannot save page screenshots as PNG files and
  cannot put local paths into GitHub's file picker.
- GitHub MCP reads work (flag is `--arguments-json`, NOT `--args`); for file
  CONTENTS the MCP tool returns only a confirmation — use
  raw.githubusercontent.com via curl instead.
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

### 9.4 Known quirks and leftovers

- 'Lá Khô' decor still has no real image (flat icon fallback).
- First-open image loading is slow (~30 s white screen = Flutter web
  bootstrap, not fixable in Dart).
- Old unused assets remain in the repo (e.g. `table_3d_painted.png`,
  `table_3d_flat.png`, old photo decor PNGs, `cloth_*_painted.png`; after
  PR #26 the now-unreferenced `table_wood_texture.jpg` /
  `table_stone_texture.jpg` / `tarot_main_background.jpg` — the last is
  still used by the Home background on non-desktop).
- The workflow emits a non-blocking Node.js 20 deprecation warning.
- Deck stack back colour changed between readings (bright yellow → dark
  olive) after a Settings cloth change — unexplained, cosmetic.
- No mid-flight frame of the stage→tray flight has ever been captured
  (animation faster than the screenshot rate); flight is supported by
  landing-state evidence.
- The reading screen's table-settings dialog captures `settings` from the
  outer scope, so it won't live-rebuild if the language is changed while
  that dialog is open (updates on reopen).
- Guest-mode quirks (PR #31): logout in guest mode takes effect only after
  a page reload; guest mode is not persisted across reloads.
- A toast sometimes shows the previous cloth's name after switching.

### 9.5 Scalability (answered to the user 2026-11-21)

- No user limit, no server to congest: static hosting on GitHub Pages
  (CDN) + GitHub API + per-user private Gists; no custom server. Practical
  limits: GitHub Pages bandwidth 100 GB/month (soft); GitHub API 5,000
  requests/hour per logged-in user (60/hour unauthenticated). The only
  bottleneck is the user hand-approving deck PRs (by design).
- If the app gets hot and hits the Pages limit, do NOT buy a GitHub plan:
  GitHub Pro/Team does NOT raise the Pages bandwidth limit (100 GB/month
  applies to free and paid alike). Move hosting to Netlify / Vercel /
  Cloudflare Pages (free, more bandwidth) — the app is static so the move
  is easy and the URL can stay the same.
- With the Google login + Worker + D1 backend (§5), the Cloudflare free
  tier supports ~20,000 daily active users (see §3.2).

## 10. Local working files (this machine)

- `~/workspace/tarotdesk-login/out/` — PR #30 login/server build (14 files).
- `~/workspace/tarotdesk-login-hotfix/out/` — PR #31 guest hotfix (4 files).
- `~/workspace/tarotdesk-login-hotfix/tarotdesk-oauth-worker.js` — the
  deployed Cloudflare Worker source.
- `~/workspace/tarotdesk-login-worker/out/` — PR #32 proxy fix
  (github_service.dart with Worker URLs).
- `~/workspace/tarotdesk-webflow/out/` — PARTIAL one-tap GitHub Web Flow
  build (superseded by the Google decision; do not push).
- `~/workspace/tarotdesk-i18n/out/` — PR #29 i18n build outputs.
- `~/workspace/tarotdesk-guide/` — guide deck `index.html` (15 slides) +
  `images/` (`home.png` + `phone-home.png` are real; the rest are
  placeholders).
- `~/workspace/tarotdesk-pr16/` — older staged files (STALE; the
  `about_screen.dart` there predates i18n/login and must NOT be pushed as-is).
- `~/workspace/research_notes/hyperframes-smooth-card-animation-20261120-1501/report.md`
  — HyperFrames motion principles (one move = one tween; animate transform
  + opacity only; arrivals on long-tail ease-outs; exits 40–50% shorter;
  landed elements dead still; measure rects once before a flight).
- Local clone `~/workspace/tarotdesk-repo` is old (PR #13) — reading only.

## 11. How to work on this repo (for the next agent)

1. Read this file first, then check `main` HEAD and the live preview.
2. Build in a workspace directory (e.g. `~/workspace/tarotdesk-<topic>/out/`)
   with complete files; verify statically (tr() key completeness across all
   5 languages, bracket balance, no leftover references to removed code).
   There is no Flutter/Dart toolchain in the VM — the GitHub Actions build
   is the real compile check.
3. Push via a device-Chrome browser task (see §9.3): branch
   `ui/<short-slug>` from `main`, one PR, merge commit, watch Actions,
   then verify on the live preview (fresh tab + `?v=...`).
4. Verify end-to-end for the feature, then leave the app in a clean state
   (logged out on the login screen; no test data in the user's deck; music
   paused; saved state per §6).
5. Update this log (current state, PR table, decisions, open work) when you
   land a meaningful change, and update `~/MEMORY.md` with durable facts.
