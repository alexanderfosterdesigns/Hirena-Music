# Hirena Music — In-Depth Build Plan

> **Status:** Authoritative build plan for the next engineering agent.
> **Target:** A Windows desktop music-streaming application built with Flutter,
> using a **Deezer ARL** purely as a streaming key, wrapped in a **Netflix-style
> design language**, with a **local, self-learning recommendation engine** modeled
> on Spotify's and YouTube's mathematics, plus **Automix / Smart Shuffle / true
> shuffle**.
>
> **Read this document top-to-bottom once before writing code.** It contains the
> decisions, the research, the math, the file layout, and the exact build order.

---

## Table of Contents

1. [How to use this plan](#1-how-to-use-this-plan)
2. [Executive summary](#2-executive-summary)
3. [Vision & scope](#3-vision--scope)
4. [Hard requirements](#4-hard-requirements)
5. [Research that drives the design](#5-research-that-drives-the-design)
6. [System architecture](#6-system-architecture)
7. [Repository structure](#7-repository-structure)
8. [Tech stack & dependencies](#8-tech-stack--dependencies)
9. [Design system (Netflix language)](#9-design-system-netflix-language)
10. [Deezer integration (the gateway)](#10-deezer-integration-the-gateway)
11. [Audio engine](#11-audio-engine)
12. [Recommendation engine](#12-recommendation-engine)
13. [Smart Shuffle, Automix & shuffle family](#13-smart-shuffle-automix--shuffle-family)
14. [Performance engineering](#14-performance-engineering)
15. [Persistence & caching](#15-persistence--caching)
16. [Security & privacy](#16-security--privacy)
17. [Legal & ToS notes](#17-legal--tos-notes)
18. [Testing strategy](#18-testing-strategy)
19. [Build & release](#19-build--release)
20. [Milestone roadmap](#20-milestone-roadmap)
21. [Definition of done](#21-definition-of-done)
22. [Risks & mitigations](#22-risks--mitigations)
23. [Open questions & decision log](#23-open-questions--decision-log)
24. [Quickstart for the next agent](#24-quickstart-for-the-next-agent)
25. [References](#25-references)

---

## 1. How to use this plan

- **Decisions are already made.** Where multiple options exist, this plan picks
  one and says why, so the next agent does not burn cycles re-litigating choices.
- **"MUST / SHOULD / MAY"** are used in the RFC sense. "MUST" is a hard
  requirement; treat violating it as a bug.
- **Every phase ends in a runnable milestone.** Do not move to the next phase
  until the previous milestone passes its acceptance criteria.
- **Keep a `DECISIONS.md`** for anything you change. The "decision log" section
  (§23) is the seed.

---

## 2. Executive summary

Hirena Music is a **Windows desktop** streaming client. It logs into the user's
Deezer account via an **ARL token** (a 192-character session cookie the user
extracts from their own browser), uses that token **only** to resolve streaming
URLs and catalog metadata, and plays the audio through a high-performance local
audio engine. The ARL is **never** used to fetch or display the user's profile,
favorites, history, friends, or any personal data — it is strictly a streaming
key.

The app looks and feels like Netflix: cinematic dark canvas, bold poster-driven
rows, a hero "billboard", restrained use of a single red accent, and a custom
typographic scale. On top of that it layers a **local recommendation brain**
that learns from the user's own listening behavior (plays, skips, completion
ratios, saves) and predicts what they want next, using the same mathematics
families that Spotify and YouTube use:

- **Spotify-style**: implicit-feedback collaborative filtering, matrix
  factorization, playlist co-occurrence embeddings (word2vec), a
  candidate-generation → ranking → re-ranking funnel, and a 30-second skip
  signal.
- **YouTube-style**: two-stage deep model (candidate generation via extreme
  multiclass classification + negative sampling + approximate-nearest-neighbor
  lookup; ranking via **weighted logistic regression** that predicts expected
  engagement rather than click probability), plus "example age" freshness.

Playback ships with the full shuffle family (uniform **true shuffle**,
constraint-aware **standard shuffle**, and **Smart Shuffle** that injects
bandit-selected recommendations) and an **Automix** engine (BPM/key-aware
beat-matched crossfades) on top of **gapless** playback.

The product goals are, in priority order: **correct streaming, low-latency
gapless playback, a beautiful Netflix-grade UI, and an adaptive recommendation
engine** — all while being fast to launch and light on memory.

---

## 3. Vision & scope

### 3.1 What this is

- A **streaming** client (not a downloader). Audio is played over the network;
  it is decrypted on the fly and buffered. No permanent local music library of
  DRM-bypassed files is a product goal.
- A **catalog browser**: search, charts, albums, artists, playlists, genres —
  all sourced from Deezer.
- A **personal DJ**: home screen rows ("Because you listened to X", "More like
  Y", "Fresh for you", "Made for you" mixes), infinite radio, and Smart Shuffle.

### 3.2 Platform scope (MUST)

| Item | Decision |
| --- | --- |
| First target | **Windows x64 desktop** (Flutter Windows embedder) |
| Min OS | Windows 10 21H2+ (WinRT Media APIs / SMTC require modern Windows) |
| Later targets | macOS > Linux > Android/iOS (architecture is kept portable; do not optimize for them now, but do not hard-code Windows) |
| Web | Explicitly out of scope for playback (audio plugins + decryption don't run on web). Web may be used **only** as a UI mock/preview |

> **Terminology note:** the brief says "streamless fast streaming". We interpret
> this as **seamless** (gapless, prefetched, sub-second starts). If the intent
> was "stream without downloading", that is exactly what the architecture does —
> see §11.

### 3.3 Non-goals (explicitly out)

- Downloading/DRM-stripping tracks to disk as a product feature.
- Fetching or displaying **any** Deezer user profile data via the ARL (§16).
- Sharing the ARL, any multi-user sync, or cloud backends.
- Copying Netflix's actual logo, "N" ribbon, "Netflix" wordmark, or shipping
  "Netflix Sans" (trademark/copyright — see §17). We reproduce the *design
  language* with lookalike open fonts and tokens.

---

## 4. Hard requirements

### 4.1 Functional (MUST)

- **F1.** User pastes an ARL once; app validates it and extracts only the tokens
  needed to stream (§16.2). Show "valid" without displaying any account data.
- **F2.** Stream tracks with **gapless** transitions; start playback of a new
  track in **< 500 ms** on a normal connection, with the *next* track prefetched
  before the current one ends.
- **F3.** Browse/search: track, album, artist, playlist, genre, chart. Artist
  pages show discography + top tracks; album/playlist pages show full tracklists
  with artwork.
- **F4.** Playback controls: play/pause, seek, next/prev, repeat
  (off/all/one), volume, quality selector (MP3_128 / MP3_320 / FLAC depending
  on what the ARL's tier permits), queue view + reorder.
- **F5.** Four shuffle modes: **True Shuffle** (uniform random, no repeats
  until exhaustion), **Standard Shuffle** (Fisher–Yates with recency/artist
  constraints), **Smart Shuffle** (queue + injected recommendations), and
  **Sequential** (off).
- **F6.** **Automix** toggle: BPM/key-aware, beat-aligned crossfades with
  adjustable intensity; gracefully falls back to a plain crossfade or gapless
  when the two tracks are incompatible.
- **F7.** **Recommendation surfaces**: Home "For You" rows, track/artist/album
  radio, "Make a Mix" from a seed, and a **Flow-style infinite queue**.
- **F8.** OS integration: media keys, System Media Transport Controls (SMTC)
  thumbnail/artist/title/buttons, taskbar presence.
- **F9.** Local "library" of what the user has **played/saved in Hirena itself**
  (never Deezer favorites via ARL). This local history feeds the recommender.

### 4.2 Non-functional (MUST)

- **N1. Fast launch:** cold start to interactive home < 2 s (release build, warm
  cache); render first screen < 500 ms.
- **N2. Smooth UI:** 60 fps scrolling on 4K windows; 120 fps where the display
  allows. No jank during artwork loading or queue reordering.
- **N3. Memory:** < 300 MB steady-state with a 1,000-track queue; audio buffers
  capped and configurable.
- **N4. Offline-resilient:** metadata and artwork cached; the app degrades
  gracefully when Deezer is unreachable (show cached home, clear errors).
- **N5. Deterministic crypto:** the decrypting stream source is covered by
  golden tests against a reference implementation (§10.6).
- **N6. Privacy:** ARL stored encrypted at rest (§16); no telemetry leaves the
  device; all recommendation data is local.

---

## 5. Research that drives the design

This section distills the external research the architecture is based on. Full
citations are in [§25](#25-references).

### 5.1 Deezer internals (the "QBDLX/deemix" foundation)

The brief references **QBDLX** (QobuzDownloaderX). That project targets **Qobuz**
with a session-token model, and its relevant "foundation" is architectural:
a native client authenticates with a service token, queries the service's
**internal** API for catalog data, resolves **CDN stream URLs**, and plays
locally. We apply that exact pattern to **Deezer**, because the brief specifies
a **Deezer ARL**. The Deezer-specific implementation is the **deemix /
deezer-py** foundation:

- Auth: the **`arl` cookie** (192 chars) is set on `.deezer.com`; a call to the
  internal RPC endpoint validates it and returns session tokens.
- Catalog: the **"gw-light" (Pipe) JSON-RPC** endpoint
  `https://www.deezer.com/ajax/gw-light.php` with `method`, `input=3`,
  `api_version=1.0`, `api_token` query params and a JSON body.
- Streams: `POST https://media.deezer.com/v1/get_url` turns `TRACK_TOKEN`s into
  signed CDN URLs, encrypted with **Blowfish-CBC "stripe"** (ciphertext
  stealing) for the higher tiers.
- Quality tiers: **MP3_128** (free), **MP3_320** (Premium), **FLAC** (HiFi),
  gated server-side by the account the ARL belongs to.
- Artwork: `https://e-cdns-images.dzcdn.net/images/cover/{md5}/{size}.jpg`.

Full endpoint table and the auth/stream flows are in §10.

### 5.2 Spotify's algorithm (what we borrow)

Spotify's pipeline (and its published research) gives us the *recommender
architecture*:

1. **Implicit feedback is the primary signal.** Saves and playlist-adds are the
   strongest positives; **skips before 30 seconds are confirmed negatives**;
   completion ratio and replays are strong positives.
2. **Collaborative filtering** on co-listening / co-playlisting. Two flavors:
   memory-based (user-user, item-item) and model-based.
3. **Matrix factorization** (`R ≈ U · Vᵀ`) with **Alternating Least Squares** to
   learn latent user/item vectors from the sparse interaction matrix.
4. **Track embeddings via word2vec**: treat each playlist (and, for us, each
   listening session) as an ordered "document" of tracks; learn fixed-length
   track vectors with **Continuous Bag-of-Words / skip-gram + negative
   sampling**.
5. **Multi-stage funnel**: *candidate retrieval* (narrow millions → thousands)
   → *ranking* (score the thousands) → *re-ranking* (diversity + freshness +
   business rules).
6. **Explore/exploit** via bandits (epsilon-greedy / Thompson sampling) so the
   engine keeps testing new music rather than only exploiting known taste.

We implement all six, scaled down to a single-user local engine (§12).

### 5.3 YouTube's algorithm (what we borrow)

The 2016 Google paper "Deep Neural Networks for YouTube Recommendations"
(Covington, Adams, Sargin) is the canonical two-stage design:

1. **Candidate generation** framed as **extreme multiclass classification**
   (predict the next-watched item over the whole corpus). A softmax over
   millions of classes is infeasible, so train with **negative sampling** and
   serve with **approximate nearest neighbor (ANN)** search over learned item
   embeddings.
2. **Ranking** via a **weighted logistic regression**: positive examples are
   weighted by observed watch time / completion, negatives get unit weight.
   The learned **odds ≈ expected engagement** (E[T]·(1+P) ≈ E[T] for small P),
   so sorting by score = sorting by predicted engagement, which beats sorting by
   raw click probability (avoids "clickbait").
3. **Example age** feature to correct popularity bias toward old items; set to
   ~0 at inference to prefer "popular now".
4. **Churn/diversity**: features describing prior impressions so successive
   requests don't return identical lists.

We port this *mathematics*, not the literal neural nets: a light gradient-boosted
or logistic ranker trained on local history, weighted by completion, with
freshness features and an MMR re-ranker (§12.4–12.6).

### 5.4 Netflix design language (what we reproduce)

- **Canvas**: pure black `#000000` with near-black/charcoal surfaces
  `#141414`, `#161616`, `#232323`, `#2d2d2d` — artwork carries all the chroma.
- **Single red accent**: Netflix Red `#E50914`, with `#B20710` as its darker
  sibling; used sparingly (CTA/play glyph/active states only), never on hairlines
  or body text.
- **Typography**: bold, geometric, tightly-tracked sans (Netflix Sans, which is
  proprietary and based on Gotham). We substitute **Inter** (and optionally
  **Barlow** for display) at weights 400–900.
- **Poster-first layout**: hero billboard → horizontal poster carousels (rows)
  with hover/scroll affordances, billboard background artwork with a
  dark-left gradient and title lockup.
- **Radii**: 8px base; **spacing**: a 9-step scale; **motion**: quick, ease-out,
  scale+fade (150–250 ms) for cards, slow Ken-Burns on hero.

Complete token table in §9.

---

## 6. System architecture

### 6.1 High-level

```
┌─────────────────────────────── Flutter UI (Dart) ───────────────────────────────┐
│  Navigation (go_router) · Screens · Design system · Presentation widgets        │
│  State: Riverpod providers (PlayerState, LibraryState, RecState, SettingsState) │
└───────────────┬───────────────────────────────┬─────────────────────────────────┘
                │ async calls (FRB)             │ stream/position events (FFI)
┌───────────────▼───────────────┐ ┌─────────────▼─────────────────────────────────┐
│  Core (Rust, via flutter_     │ │  Audio Engine (media_kit / libmpv)            │
│  rust_bridge)                 │ │  · gapless playlist, seek, volume             │
│  ┌─────────────────────────┐  │ │  · prefetch next source                       │
│  │ Deezer Gateway          │  │ │  · SMTC bridge (audio_service + smtc_windows) │
│  │  · ARL auth, tokens     │  │ └────────────────────────────────────────────────┘
│  │  · catalog JSON-RPC     │──┼──► Decrypting Stream Source (Rust)
│  │  · stream URL resolver  │  │      HTTP range fetch → Blowfish-CBC/CTS decrypt
│  │  · artwork URL builder  │  │      → ring-buffer of plain audio → mpv
│  ├─────────────────────────┤  │
│  │ Recommender (local)     │  │
│  │  · embeddings, ANN      │  │
│  │  · ranker, MMR, bandits │  │
│  └─────────────────────────┘  │
└───────────────┬───────────────┘
                │
┌───────────────▼───────────────┐
│  Persistence (drift/SQLite)   │
│  · listening events, library  │
│  · cached metadata + artwork  │
│  · encrypted ARL vault        │
└───────────────────────────────┘
```

### 6.2 Why Rust for the core

- **Blowfish-CBC with ciphertext stealing on a stream with random-access seek**
  is performance- and correctness-critical. RustCrypto provides `blowfish` +
  `cbc` (with CTS) as audited primitives, and Rust's streaming iterators make
  the decrypting ring buffer deterministic and fast. Pure Dart would require
  hand-rolling both the cipher and CTS.
- The **recommender** (embedding training, SVD, ANN) benefits from Rust's
  `ndarray`, `hnsw`/`usearch`, and `smartcore` crates.
- The **Deezer gateway** reuses `reqwest` (HTTP/2, connection pooling) for fast
  metadata and low-latency stream fetches.
- Everything is exposed through `flutter_rust_bridge` (FRB) so Dart stays clean.

> **Escape hatch**: if FRB tooling causes friction in Phase 1, the gateway can
> first be prototyped in Dart (`dio` + `package:crypto`), and only the
> **decrypting stream source** is required to be Rust from the start (it is the
> one piece that cannot be done well in pure Dart).

### 6.3 Threading / concurrency model

| Concern | Where it runs |
| --- | --- |
| UI build/layout | Flutter main isolate |
| Image decode/cache | `cached_network_image` (native decode, LRU) |
| Metadata JSON parsing | Rust worker threads in FRB pool |
| Decryption + buffering | Rust thread per active stream |
| Recommendation training | Rust worker; results are cheap to load into UI |
| SQLite | drift's background isolate |

**Rule:** never block the main isolate on network or disk. All Dart→Rust calls
are async. Any Dart-side JSON of a large playlist is parsed off the main
isolate (`compute`/`Isolate.run`).

---

## 7. Repository structure

```
hirena_music/                     # Flutter app root (this repo)
├── PLAN.md                       # this document
├── DECISIONS.md                  # decision log (start it early)
├── README.md
├── pubspec.yaml
├── analysis_options.yaml         # strict lints (flutter_lints + extra)
├── rust/                         # Rust core crate (flutter_rust_bridge)
│   ├── Cargo.toml
│   └── src/
│       ├── api/                  # FRB entry points
│       ├── deezer/               # gateway: auth, catalog, streams
│       │   ├── auth.rs           #   ARL -> tokens (validated, minimal)
│       │   ├── catalog.rs        #   pageTrack/Album/Artist/Playlist/search/charts
│       │   ├── stream.rs         #   get_url resolution
│       │   ├── decrypt.rs        #   Blowfish-CBC/CTS chunk decryptor (ported)
│       │   └── http.rs           #   reqwest client, rate limiter, retry
│       ├── recsys/               # recommender
│       │   ├── events.rs         #   listening event model
│       │   ├── embed.rs          #   co-occurrence / word2vec + SVD
│       │   ├── index.rs          #   HNSW index
│       │   ├── rank.rs           #   weighted-LR ranker + MMR
│       │   ├── bandit.rs         #   epsilon-greedy / Thompson
│       │   └── features.rs       #   audio-feature distance, freshness
│       └── audio/                # decrypting stream source
│           ├── source.rs         #   range fetch + decrypt + ring buffer
│           └── seek.rs           #   block-boundary seek math
├── lib/
│   ├── main.dart
│   ├── app.dart                  # MaterialApp + theme + router
│   ├── core/
│   │   ├── constants.dart
│   │   ├── result.dart           # Result/Either type (no naked exceptions)
│   │   └── logging.dart
│   ├── design/                   # design system (§9)
│   │   ├── tokens.dart
│   │   ├── theme.dart
│   │   ├── typography.dart
│   │   └── motion.dart
│   ├── data/
│   │   ├── models/               # Track, Album, Artist, Playlist, ...
│   │   ├── db/                   # drift tables + DAOs
│   │   ├── repo/                 # repositories (catalog, library, settings)
│   │   └── cache/                # metadata + artwork cache policies
│   ├── features/
│   │   ├── auth/                 # ARL entry screen
│   │   ├── home/                 # hero + rows
│   │   ├── browse/               # search, charts, genres
│   │   ├── detail/               # album/artist/playlist pages
│   │   ├── player/               # now-playing bar, full player, queue
│   │   ├── library/              # local plays/saves
│   │   └── settings/             # quality, crossfade, ARL, shuffle defaults
│   ├── state/                    # Riverpod providers
│   └── widgets/                  # shared widgets (PosterCard, Row, Hero...)
├── test/                         # Dart tests + golden UI tests
├── integration_test/             # end-to-end flows
├── assets/fonts/                 # Inter (and Barlow) variable fonts
├── windows/                      # Flutter Windows runner (customized titlebar)
└── .github/workflows/build.yml   # Windows CI + release packaging
```

---

## 8. Tech stack & dependencies

### 8.1 Dart (Flutter) — pinned majors (verify latest at build time)

| Package | Purpose | Notes |
| --- | --- | --- |
| `flutter_riverpod` | state management | prefer `AsyncNotifier`/`Notifier` APIs |
| `go_router` | navigation | shell routes for player + detail stack |
| `media_kit` + `media_kit_libs_windows_audio` | playback (libmpv) | primary engine |
| `audio_service` | background/service abstraction | wires SMTC + media keys |
| `smtc_windows` | Windows System Media Transport Controls | title/artist/art/buttons |
| `flutter_rust_bridge` | Rust interop | codegen via `flutter_rust_bridge_codegen` |
| `drift` + `drift_flutter` + `sqlite3_flutter_libs` | local DB | events, library, cache index |
| `cached_network_image` | artwork | LRU + resizing; point at dzcdn |
| `google_fonts` | Inter/Barlow bundling | bundle locally (offline + reproducible) |
| `window_manager` | frameless/custom window | cinematic titlebar |
| `flutter_acrylic` | translucency/blur | optional, Windows-only polish |
| `dio` | Dart-side HTTP | only for non-core calls (artwork, misc) |
| `collection` | fast list helpers | — |
| `uuid`, `clock` | ids, testable time | — |

### 8.2 Rust — crates

| Crate | Purpose |
| --- | --- |
| `flutter_rust_bridge` | FFI bridge |
| `reqwest` (rustls, http2) | gateway + stream HTTP |
| `serde` / `serde_json` | model (de)serialization |
| `blowfish`, `cbc` (CTS), `cipher` | stream decryption |
| `md-5` | MD5_ORIGIN/key derivation |
| `ndarray`, `nalgebra` | linear algebra (SVD, embeddings) |
| `hnsw_rs` or `usearch` | ANN index |
| `smartcore` | logistic regression ranker (optional; else hand-rolled) |
| `tokio` | async runtime for FRB worker |
| `rand` / `rand_distr` | shuffle + bandit sampling |

### 8.3 Toolchain requirements

- Flutter SDK ≥ 3.x (stable), Dart ≥ 3.x.
- **Rust** stable toolchain (`rustup`), `flutter_rust_bridge_codegen`.
- **Windows**: Visual Studio 2022 with "Desktop development with C++",
  Windows 10/11 SDK (required for the Flutter Windows toolchain and media_kit
  native libs).
- **Dev iteration**: Linux/macOS for hot-reload of UI; the decrypting stream +
  audio engine are Windows-validated via GitHub Actions (Windows runner) and on
  a real Windows machine. See §19 for CI.

---

## 9. Design system (Netflix language)

### 9.1 Guiding rules (MUST)

1. **Black canvas carries the chroma.** Cards/artwork are the only saturated
   elements by default.
2. **One red.** `#E50914` only for: primary CTA, play glyph, active/selected
   states, and focus rings. Never for hairline dividers or body text.
3. **Poster-first.** Every browse surface is a set of horizontal poster rows
   with a hero billboard on Home.
4. **Type is loud.** Heavy weights, tight tracking on headings; generous
   weight contrast between title and metadata.
5. **Motion is quick and eased** (150–250 ms, `easeOutCubic`), with a slow
   Ken-Burns zoom on the hero (30–60 s loop).

### 9.2 Color tokens

| Token | Hex | Role |
| --- | --- | --- |
| `canvas` | `#000000` | app background |
| `surface` | `#141414` | page background / billboard fade |
| `surfaceRaised` | `#161616` | cards, accordions |
| `surfaceHover` | `#232323` | hovered cards |
| `surfacePressed` | `#2d2d2d` | pressed cards / input |
| `hairline` | `rgba(255,255,255,0.16)` | dividers, borders |
| `inkPrimary` | `#FFFFFF` | headings, primary text |
| `inkSecondary` | `rgba(255,255,255,0.70)` | metadata, subtitles |
| `inkDisabled` | `rgba(255,255,255,0.40)` | placeholder text |
| `brandRed` | `#E50914` | single accent (CTA/play/active) |
| `brandRedDark` | `#B20710` | pressed CTA / gradient stop |
| `gradient` | `#000000 → transparent` | hero scrim (left + bottom) |
| `error` | `#E50914` | reuse red for errors (keeps palette tight) |
| `success` | `#2AB759` (rare) | only for "added"/"playing" confirmations |

### 9.3 Typography

- **Fonts**: bundle **Inter** (UI/body) and **Barlow** (display/hero) locally
  via `google_fonts` (`google_fonts` supports local bundling; commit the TTFs
  under `assets/fonts/`). **Never ship "Netflix Sans"** (§17).
- **Scale** (in logical px, adjust for window DPI):

| Role | Size / weight / tracking |
| --- | --- |
| Hero title | 48–56 / 900 / -1.5% |
| Screen title | 34 / 800 / -1% |
| Section (row) title | 20 / 700 / 0% |
| Card title | 14 / 600 / 0% |
| Body / metadata | 13–14 / 400–500 / 0% |
| Caption / eyebrow | 11–12 / 600 / +2% (uppercase, red or gray) |

- **Rules:** line-height 1.2 for display, 1.45 for body; always cap headings;
  minimum contrast for inkSecondary ≥ 4.5:1 on `#141414`.

### 9.4 Shape, spacing, elevation

- **Radii**: `8` base (cards), `4` (small chips/buttons), `50%` (avatars).
- **Spacing scale** (9 steps): `4, 8, 12, 16, 24, 32, 48, 64, 96`.
- **Elevation**: shadows sparingly; rely on surface-color change for hover;
  poster cards get `elevation 2` + scale 1.06 on hover.

### 9.5 Component inventory (build these first, in order)

1. `PosterCard` (2:3 portrait) + `LandscapeCard` (16:9) with hover scale/fade.
2. `Row` (title + horizontal `ListView` of cards, lazy, snap-scroll arrows).
3. `HeroBillboard` (backdrop artwork, left gradient scrim, title lockup,
   `Play` + `Shuffle` + `More` actions, Ken-Burns).
4. `NowPlayingBar` (compact, bottom, with thumbnail + controls + progress).
5. `FullPlayer` (large artwork, scrubber, controls, queue, "Up next" with
   Automix/smart-shuffle indicators).
6. `SearchBar` + result categories (Top result, Songs, Albums, Artists, Playlists).
7. `TrackRow` (index, artwork, title/artist, duration, hover actions:
   play, queue, like, "More").
8. `Chip`/`Pill` (genres, moods, quality badges).
9. `Toast`/`Snackbar` (dark, bottom, quick).
10. `Settings` surfaces (accordion sections, dark inputs).

### 9.6 Motion tokens

| Motion | Value |
| --- | --- |
| `durationFast` | 150 ms |
| `durationBase` | 200 ms |
| `durationSlow` | 300 ms |
| `ease` | `Curves.easeOutCubic` |
| `cardHoverScale` | 1.06 |
| `heroKenBurns` | scale 1.0→1.08 over 45 s, ease linear |

---

## 10. Deezer integration (the gateway)

### 10.1 The ARL lifecycle

```
User pastes ARL
      │
      ▼
1. Store ARL encrypted (DPAPI on Windows / AES-GCM keychain)   [§16]
      │
      ▼
2. Validate: set `arl` cookie on .deezer.com → call
   `deezer.getUserData` → expect USER_ID != 0 and `checkForm` token present.
      │
      ▼
3. Extract ONLY: `checkForm` (→ api_token), `license_token`.
   Discard every other field immediately. NEVER persist or render them.  [§16]
      │
      ▼
4. Cache tokens in memory (they rotate). On 401/expiry → re-run step 2.
   On hard failure → show "ARL expired — paste a fresh one" screen.
```

**Error matrix** (gateway MUST map these to user-friendly states):

| Symptom | Cause | UX |
| --- | --- | --- |
| `USER_ID == 0` after getUserData | invalid/expired ARL | "Invalid ARL" |
| 401 on a stream/gw call | token rotation | silent re-auth (step 4), retry once |
| `get_url` returns no source for FLAC/320 | tier mismatch | fall back MP3_320→MP3_128, surface a quality badge |
| 429 / rate limit | too many calls | exponential backoff + jitter, cache harder |
| geo/consent error | region | explain + retry |

### 10.2 Endpoint reference (gw-light "Pipe" RPC)

All go through `GET https://www.deezer.com/ajax/gw-light.php?method=<M>&input=3&api_version=1.0&api_token=<t>` with a JSON body; `sid`/`arl` cookie for auth.

| Method | Purpose | Key inputs → outputs |
| --- | --- | --- |
| `deezer.getUserData` | auth/validation | → `checkForm` (api_token), `USER.OPTIONS.license_token`, `USER_ID` |
| `deezer.pageTrack` | single track | `sng_id` → track + album + artist |
| `song.getListData` | batch track data + tokens | `sng_ids[]` → `TRACK_TOKEN`, `MD5_ORIGIN`, `TRACK_TOKEN_EXPIRE` |
| `deezer.pageAlbum` | album + tracklist | `alb_id` → `SONGS.data[]` (with tokens) |
| `deezer.pageArtist` | artist + top + discography | `art_id`, `nb`, `lang` → `TOP`, `ALBUMS`, `ARTIST` |
| `deezer.pagePlaylist` | playlist + tracklist | `playlist_id`, `nb` (≤2000), `lang` → `SONGS.data[]` |
| `deezer.getCharts` | charts | → `TRACKS`, `ALBUMS`, `ARTISTS`, `PLAYLISTS` |
| `search.music` | unified search | `query`, `limit`, `start` → tracks/albums/artists/playlists |
| `deezer.getGenres` / `genre.getArtists` | genre browse | `genre_id` → lists |
| `song.getListByGenre` | editorial/curated by genre | `genre_id` → track list |
| `deezer.getSmartTrackList` / `deezer.pageSmart` | Deezer's own recs | seed → similar tracks (used as a *signal*, not authority) |
| `track.getLyrics` / `song.getLyrics` | synced lyrics | `sng_id` → lyrics (optional polish) |

> **Fallback note:** if gw-light changes, there is a maintained **GraphQL
> ("Pipe")** client (`deezer-python-gql`, music-assistant) exposing
> `get_track`, `get_album`, `get_artist`, `get_playlist`, `search`,
> `get_similar_tracks`, `get_artist_mix`, `get_track_mix`, `get_flow`,
> `get_charts`, `get_recommendations`. The gateway SHOULD isolate all endpoint
> logic behind one trait (`DeezerClient`) so the transport can be swapped
> without touching the UI.

### 10.3 Stream resolution flow

```
track id (SNG_ID)
   │
   ▼ song.getListData(sng_ids=[id])
   │  → TRACK_TOKEN, MD5_ORIGIN
   ▼ POST https://media.deezer.com/v1/get_url
   │  body: { license_token, media: [{ type:"FULL",
   │           formats:[{cipher:"BF_CBC_STRIPE", format:"<Q>"}] }],
   │          track_tokens:[...] }
   │  → data[].media[].sources[] with a signed URL (and expiry)
   ▼
Decrypting Stream Source (Rust) ──► media_kit/libmpv
```

- **Quality ladder (MUST):** request FLAC → on absence fall back MP3_320 →
  MP3_128; persist the user's cap in settings. Respect the ARL's tier; never
  upsample.
- **URL expiry:** signed URLs expire. Cache per-track for the expiry window;
  re-resolve on demand. Prefetch the *next* track's URL while the current one
  plays.

### 10.4 On-the-fly decryption (the hard part)

The bytes at the resolved URL are **Blowfish-CBC in "stripe"/ciphertext-stealing
mode** (Deezer's `BF_CBC_STRIPE`). The reference implementation to port is
**deemix's `src/utils/decryption.py`**:

- `generateBlowfishKey(trackId, MD5_ORIGIN)` — derives the key from the numeric
  track id + `MD5_ORIGIN` + a public hardcoded secret. **Port this verbatim and
  lock it with a golden test** (do not re-derive from memory).
- `chunkBlowfish(chunk)` — the ciphertext is processed in **2048-byte chunks**;
  each chunk's first 8 bytes are the **IV** for the remainder of that chunk
  (CBC), with ciphertext-stealing semantics for the tail chunk.
- Rust primitives: `blowfish` crate + `cbc` crate in **CTS** mode. Blowfish
  block size is **8 bytes**.

**Streaming/seek requirements** (this is what makes it a streamer, not a
downloader):

1. **Random access:** to decrypt byte offset `i`, you only need the 8-byte block
   containing `i` plus the preceding ciphertext block (the IV). The decrypting
   source fetches via **HTTP Range** requests aligned to chunk boundaries, so
   seeking is O(1) network + O(block) CPU — no full-file download.
2. **Ring buffer:** decrypted bytes are pushed into a bounded ring buffer that
   `media_kit` consumes; backpressure pauses the fetcher (never unbounded RAM).
3. **Prefetch & gapless:** while track N plays, the engine resolves + begins
   buffering track N+1's first seconds so hand-off is instantaneous.
4. **HTTP/2 + connection reuse** on the CDN client; 1–2 concurrent range
   fetchers max.

### 10.5 Artwork

- URLs: `https://e-cdns-images.dzcdn.net/images/cover/{MD5}/{size}.jpg`
  with sizes `56x56`, `250x250`, `500x500`, `1000x1000`. Artist:
  `/artist/{MD5}/{size}.jpg`.
- Always request the size closest to the render box (device-pixel-ratio aware)
  to keep memory low; `cached_network_image` with a 512 MB disk cache + 64 MB
  memory cache.

### 10.6 Golden tests (MUST)

- Pin a small, known encrypted sample (a few KB captured from a real resolve —
  or reuse the deemix test vectors) and assert the Rust decryptor reproduces the
  reference plaintext **byte-for-byte**, including a **seek into the middle** of
  a chunk and a **tail chunk** (CTS path).
- Assert `generateBlowfishKey` matches deemix for a fixed `(trackId, MD5_ORIGIN)`
  pair.

---

## 11. Audio engine

### 11.1 Engine choice

**`media_kit` (libmpv)** is the primary engine because it provides, on Windows:

- gapless playlist playback and `prefetch-playlist`,
- arbitrary input (it can consume our decrypting stream source over a custom
  protocol or a loopback URL),
- a full filter graph (`af=scaletempo2/rubberband`, `lavfi acrossfade`, EQ)
  that we need for **Automix**,
- low-level control for a two-player crossfade when needed.

`just_audio` + `just_audio_windows` (WinRT) is the documented **fallback** for
the MVP if media_kit hits a blocker; it supports gapless but has a weaker filter
graph, so Automix degrades to a plain crossfade there.

### 11.2 Core states & contracts

A single `PlayerState` (Riverpod) with an explicit state machine:

```
idle → loading → buffering → playing ⇄ paused → completed
                                     ↘ stalled (auto-recover) ↘ error
```

The engine exposes an immutable `PlaybackSnapshot` (current track, position,
buffered position, queue, shuffle mode, repeat mode, automix state, volume) so
UI rebuilds are cheap and deterministic.

### 11.3 Queue model

- `Queue` = ordered list of `QueueItem { track, source, origin }` where `origin`
  ∈ `{user, album, playlist, radio, smart}` (drives the "Up Next" badges).
- **Reordering, insert, remove, move, clear, "Play next", "Add to queue"** all
  operate on the same list; the engine diff-updates mpv's playlist.
- History (played) and future are kept so next/prev behave correctly across
  shuffle modes.

### 11.4 Gapless + prefetch (N1/F2/F3)

- mpv `--prefetch-playlist=yes`, and resolve stream URLs for the **next 2
  tracks** in the background.
- Start next track decode while current is in its final 2–3 s.
- Never allow a silent gap > 40 ms between consecutive tracks when gapless is on.

### 11.5 System integration

- `audio_service` wraps the engine; `smtc_windows` publishes
  **title / artist / album art / play-pause / next-prev / seek** to Windows
  System Media Transport Controls; media keys route through it.
- Taskbar: Flutter Windows + `window_manager` set app title to current track;
  (optional) thumbnail toolbar buttons.

---

## 12. Recommendation engine

> Goal from the brief: *"an intelligent algorithm that can predict what the user
> wants."* This is a **single-user, on-device** engine (no cloud, no cross-user
> data) that borrows Spotify's CF/embedding funnel and YouTube's two-stage
> weighted-LR ranking. It runs on the user's own listening events only.

### 12.1 Data model (what we log, all local)

`ListeningEvent`:
```
track_id, started_at, ended_at, duration_ms,
completion_ratio,   // ended/duration, capped 1.0
action: { play, skip, save, replay, thumbs_up, thumbs_down },
context: { origin, shuffle_mode, automix, session_id, position_in_session },
source: { user | smart | radio }
```

`SavedTrack` (local "library") is the strongest positive signal.

**30-second rule (Spotify):** a skip before 30 s of *audible* playback is a
negative; completion and replays are strong positives; saves are the strongest.

### 12.2 Implicit feedback weighting

Convert events into an interaction weight for each (user, track):

```
w = base(completion_ratio)
  + a1 * save
  + a2 * replay_bonus
  - a3 * early_skip          // skip in first 30s
  + a4 * session_recency
```
Start with `base(x) = 1 + 2x`, `a1 = 2`, `a2 = 0.5`, `a3 = 1.5`, `a4 = 0.2`,
and tune with offline evaluation (§12.8). Weights decay over time
(`0.99^days` half-life ~ 10 weeks) so taste drifts.

### 12.3 Track embeddings (Spotify word2vec + SVD)

Two complementary embeddings, fused:

1. **Co-occurrence embedding.** Build matrix `C` where `C_ij` = count of times
   tracks `i`,`j` appear in the same session/playlist within a window. Apply
   **PPMI** then truncated **SVD** to `d = 64`:
   `C ≈ U Σ Vᵀ`, track embedding `= U·Σ^0.5` (rows). This is the item-item CF
   signal.
2. **Word2vec embedding.** Treat each session (and each saved playlist) as an
   ordered track "sentence". Train **skip-gram with negative sampling**:
   maximize
   `log σ(v_out · v_in) + Σ_{k=1..K, n_k ~ P_noise} E[ log σ(−v_out · v_nk) ]`.
   `K = 5`, `d = 64`, window 5, 3 epochs. This captures *sequencing* (what
   follows what), which is exactly the "predict next" signal.
3. **Fuse** the two 64-d vectors by concatenation → 128-d `track_embedding`.

Retrain incrementally: full retrain when ≥ 200 new events accrue; otherwise
**online-update** the user's own vector only (cheap).

### 12.4 User taste vector

```
user_vector = normalize( Σ_e w(e) · track_embedding(track_e) )
```
Plus per-genre/BPM/key histograms for content-based priors and cold start.

### 12.5 Candidate generation (recall: millions→thousands)

Funnel sources, blended:

1. **ANN over track embeddings** (HNSW) → nearest neighbors of recently-loved
   tracks (cosine similarity). YouTube's "extreme multiclass → ANN" idea,
   localized.
2. **Sequential model** → "tracks that usually follow tracks like the last few
   played" (word2vec v_out · v_in scoring).
3. **Content-based** → same genre/BPM/key band as the user's histogram peaks.
4. **Deezer signals** (used as *nominators*, not authority): `getSimilarTracks`,
   `get_track_mix`/`get_artist_mix`, Flow, charts, "fresh" (recent releases).
5. **Explore pool** → random sample from the catalog/decades/genres, weighted by
   popularity prior (so it's "good random", not "any random").

Each nominator returns candidates with a provenance tag (this feeds ranking
features and lets us explain recs in the UI).

### 12.6 Ranking (YouTube weighted-LR + MMR)

**Scorer** — logistic model predicting *expected engagement*:

```
score = σ( θ · features )
features = [
   user_vector · track_embedding,          // taste affinity
   sequential_score,                        // "what comes next"
   content_distance(bpm,key,genre),         // smaller is better
   freshness(example_age),                  // YouTube "example age"
   popularity_prior,
   nominator_indicators,                    // which sources proposed it
   exploration_uncertainty                  // bandit bonus
]
```
Train with **weighted logistic regression**: positive examples (played/completed)
weighted by `completion_ratio`, negatives (skips/impressions) weight 1 — so the
learned odds approximate expected engagement (YouTube's trick). Use `smartcore`
or a 15-line IRLS/Nesterov implementation in Rust; retrain nightly on-device.

**Re-ranker** — **Maximal Marginal Relevance** for diversity:

```
MMR(d) = λ · rel(d) − (1 − λ) · max_{d_j ∈ selected} sim(embed_d, embed_{d_j})
```
Greedily fill the row/session with `λ = 0.7`. Add a **churn** penalty for tracks
shown recently (impression count) so consecutive sessions differ (YouTube §5.3).

### 12.7 Explore/exploit (bandits)

- **Epsilon-greedy**: with probability `ε` pick from the Explore pool, else
  Exploit (top-ranked). Start `ε = 0.25`, anneal to `0.05` as history grows.
- **Thompson sampling** over candidate *pools* (genre/BPM bands, nominators):
  maintain Beta(α=1+successes, β=1+failures) per pool; sample to pick which pool
  to draw from. Success = completion, failure = early skip. This is what makes
  Smart Shuffle and "Fresh for you" feel alive instead of samey.

### 12.8 Offline evaluation (MUST before claiming it "works")

Hold out the last 20% of events; measure:
- **Recall@50** on the held-out next-played track,
- **hit rate & inverse skip rate** of generated mixes,
- **click/skip telemetry** on real Smart Shuffle injections.
Targets to beat the baseline (popularity): +15% recall, −10% early-skip.

### 12.9 Cold start (new user, no history)

- Seed with Deezer charts + editorial mixes + genre hubs.
- Ask **zero questions** (Netflix-like: show, don't interrogate); infer from the
  first 10–20 plays. Optionally one lightweight "pick artists you like" screen
  that feeds the content-based prior (not the ARL).

---

## 13. Smart Shuffle, Automix & shuffle family

### 13.1 Shuffle family (shared guarantees)

All shuffles MUST: never repeat a track until the pool is exhausted; keep
next/prev consistent with what was actually played; be O(n) and reseedable
(`rand` ChaCha). Implementation lives in Rust for determinism and speed.

| Mode | Algorithm | Behavior |
| --- | --- | --- |
| **Sequential (off)** | queue order | — |
| **Standard Shuffle** | Fisher–Yates + constraints | avoid recent tracks + avoid same-artist adjacency (soft penalty), mild key/BPM smoothing when Automix is on |
| **True Shuffle** | Fisher–Yates, uniform | pure uniform random, no constraints, full history so no repeats |
| **Smart Shuffle** | queue + injection | every `k`th slot (k ≈ 3–6, adaptive) insert a bandit-selected recommendation |

### 13.2 Smart Shuffle (Spotify-style)

- On enable, annotate the queue with `origin: smart` items (badged in "Up Next").
- Injections are drawn from the **Thompson pool sampler** (§12.7) restricted to
  tracks **not** already in the user's local library/history (novelty).
- Each injected track offers implicit feedback automatically (did they skip in
  < 30 s?) plus an explicit "👍 / 👎 / Why this?" affordance. Feedback updates the
  bandit posteriors and the ranker weights **immediately** (online update).
- Injection rate adapts: if skip-rate of injected tracks rises, back off `k`;
  if they're well-received, increase.

### 13.3 Automix (beat-matched crossfade)

Deezer exposes per-track **analytics** (BPM, gain, energy, danceability, and key
where available) via track data. Automix consumes those plus our own beat-grid
estimation when analytics are missing.

Pipeline per track-pair:

1. **Feature fetch**: `bpm`, `key` (Camelot numeric), `energy`, `gain`, loudness
   of the first/last 10 s.
2. **Compatibility check**:
   - `ΔBPM` ratio within `[0.8, 1.25]` (else no beat-match, plain fade),
   - Camelot key compatible (same number, or ±1 ring) → harmonic mix bonus.
3. **Transition plan**:
   - detect **outro** of current and **intro** of next (energy floor),
   - align **downbeats** (round to nearest beat using BPM),
   - choose **mix length** `T` from intensity setting (2–16 s) and pair
     compatibility.
4. **Apply**:
   - **time-stretch** the incoming track to match tempo (`scaletempo2` /
     `rubberband` filter in mpv) when `ΔBPM` is small,
   - **equal-power crossfade** with gains `g1(t)=cos(θ)`, `g2(t)=sin(θ)`,
     `θ = (π/2)(t/T)`, implemented via mpv `lavfi acrossfade` or a two-player
     mix,
   - **bass-swap EQ** (cut incoming low shelf for the first seconds) to avoid
     low-end clash.
5. **Fallback ladder**: beat-match → harmonic fade → plain crossfade → gapless.

**Real-time beat alignment** (if no analytics): run a lightweight onset/energy
autocorrelation in Rust on the buffered tail of the current track (~8 s) to
estimate BPM, then align. This is Phase 7 polish; start with Deezer analytics.

### 13.4 True shuffle correctness

- Maintain a `playedSet` and `remainingPool`; when `remainingPool` empties,
  reset and reshuffle (so "true" = uniform with no repeats until exhaustion).
- Persist shuffle state so app restart continues correctly.

---

## 14. Performance engineering

### 14.1 Network

- **HTTP/2 + connection pooling** (reqwest) for both gw-light and CDN.
- **Metadata in one round-trip**: batch track resolution via `song.getListData`
  (send many `sng_ids` at once) rather than N calls.
- **Artwork**: request size-matched; prewarm the row that's 1 viewport ahead;
  lazy-load off-screen rows.
- **Prefetch** next-track URL + first seconds (§11.4).

### 14.2 Rendering

- **List virtualization** everywhere (`ListView.builder`, `SliverList`) — a home
  screen of 10 rows × 20 cards must never build all 200 at once.
- **RepaintBoundary** per card; const constructors; no per-frame allocations in
  `build`.
- **Image caching** via `cached_network_image` with LRU + resizing; avoid
  decoding full 1000×1000 art for 120 px cards.
- **Impeller/skia**: default renderer on Windows; profile with DevTools and
  `flutter run --profile` on real Windows hardware.

### 14.3 Startup

- Lazy-init the Rust core after first frame; show the shell immediately.
- Restore last session from SQLite cache in < 150 ms; fetch fresh in background
  and reconcile.
- Don't block startup on ARL validation — validate in background, show cached
  home meanwhile.

### 14.4 Memory budgets

| Budget | Limit |
| --- | --- |
| Image memory cache | 64 MB |
| Image disk cache | 512 MB |
| Audio ring buffer | 4–8 MB per active stream |
| Metadata LRU | 20k entries |
| Steady-state RSS | < 300 MB |

---

## 15. Persistence & caching

| Store | Tech | Contents | Notes |
| --- | --- | --- | --- |
| SQLite | drift | events, local library, settings, queue/session state | WAL mode, indexes on `track_id`, `started_at` |
| KV cache | in-memory LRU | track/album/artist/playlist JSON | TTL + LRU, 20k entries |
| Artwork | `cached_network_image` | poster images | disk 512 MB / mem 64 MB |
| Embeddings | SQLite BLOB / file | 128-d vectors, HNSW index | loaded into Rust on demand |
| ARL vault | DPAPI (Windows) / AES-GCM | ARL only | see §16 |

All caches MUST be transparently invalidatable (version-stamped) and MUST NOT
leak the ARL into logs, SQL dumps, or crash reports.

---

## 16. Security & privacy

### 16.1 ARL handling (MUST)

- Stored **encrypted at rest** using Windows DPAPI (via a small Rust winapi
  binding) or an AES-256-GCM key stored in the OS keychain. **Never plaintext
  on disk, never in logs, never in analytics/crash reports.**
- Held in memory only as long as needed; zeroized on shutdown.
- **Never** sent anywhere except `deezer.com` / `media.deezer.com` / dzcdn.

### 16.2 The privacy firewall (the brief's hard rule)

> *"The ARL is simply the key it uses to stream the data; it should not pull the
> user's details using the ARL."*

Enforce with an explicit **allowlist** in the gateway: the only *authenticated*
call that reads account scope is `deezer.getUserData`, and only to extract
`checkForm` and `license_token`. The gateway MUST:

- **Not call** `deezer.pageProfile`, `deezer.getUserPlaylists`, favorites,
  history, followings, friends, or any user-scoped method.
- **Discard** the rest of `getUserData`'s response (name, email, picture,
  country, plan, `USER` object) immediately — don't serialize, don't log, don't
  cache.
- **Not render** any account identity in the UI. The "account" screen shows only
  "ARL: valid / expired" and the detected **quality tier** (needed to pick a
  stream format), nothing else.
- The recommender and "library" operate **exclusively** on local events Hirena
  recorded itself.

### 16.3 Network & telemetry

- No analytics SDKs. No crash reporter that uploads content (if one is ever
  added, it must scrub the ARL and identifiers, and be opt-in).
- Certificate pinning / rustls with system roots; no user data in URLs beyond
  Deezer's own ids.

---

## 17. Legal & ToS notes

> These are engineering constraints, not legal advice.

- **Deezer ToS**: a third-party client using the gw-light internal API and
  decrypting streams violates Deezer's Terms of Service. This is a **personal
  use** tool. Do **not** ship accounts, tokens, or any Deezer assets; do **not**
  distribute decryption keys beyond the public constants already in deemix
  (which are not secret); do **not** enable bulk scraping.
- **Account risk**: ARLs expire (roughly 90 days–6 months) and can be
  invalidated; aggressive use can trigger bans. The app MUST rate-limit (§10.2)
  and MUST make "paste a fresh ARL" a first-class, friendly flow.
- **Netflix trademark/copyright**: do **not** use the Netflix name, logo, "N"
  ribbon, "Tudum" sound, or the proprietary **Netflix Sans** font. Use
  **Inter/Barlow** and the color/token system in §9, which reproduces the
  *language* (cinematic black + red accent + poster rows) without copying
  protected assets.
- **Audio rights**: users may only stream content their Deezer subscription
  entitles them to; the app performs no rights circumvention beyond the
  on-the-fly decryption required to play what their own account can already
  stream.

---

## 18. Testing strategy

| Layer | Tooling | What to cover |
| --- | --- | --- |
| Rust unit | `cargo test` | gateway models, token extraction, decryptor (golden), shuffle algorithms, ranker math, bandits |
| Dart unit | `flutter test` | state machines, queue logic, providers, models |
| Golden UI | `golden_toolkit` | PosterCard, Row, Hero, NowPlayingBar, tokens |
| Widget tests | `flutter_test` | interaction: hover, play, queue, search |
| Integration | `integration_test` | ARL→search→play→skip→smart-shuffle loop (on Windows) |
| Performance | DevTools + `integration_test` timers | launch < 2 s, 60 fps scroll, memory budget |
| End-to-end streaming | manual script + automation | resolve URL → decrypt → verify hash vs reference |

**Golden-stream fixtures** (§10.6) are the single most important test — the
decryptor is the linchpin of the whole product.

---

## 19. Build & release

### 19.1 Development loop

```bash
# 1) Flutter + Rust codegen (after editing rust/)
flutter_rust_bridge_codegen generate
cargo build --manifest-path rust/Cargo.toml --release   # or dev profile

# 2) Run (Windows)
flutter run -d windows

# 3) Profile
flutter run -d windows --profile
```

### 19.2 Windows packaging

- **flutter_distributor** to produce **MSIX** (preferred: clean install/update,
  works with SMTC/DPAPI) and an **Inno Setup** `.exe` fallback.
- Configure `windows/runner` for the custom titlebar (window_manager) and
  minimum window size.
- Sign with a code-signing cert (store as a GitHub secret).

### 19.3 CI (GitHub Actions)

`windows-latest` runner workflow:

1. Setup Flutter + Rust + VS2022 C++ toolchain.
2. `flutter pub get`, FRB codegen, `cargo build`.
3. `flutter analyze`, `cargo clippy`, `cargo test`, `flutter test`.
4. Build MSIX + Inno Setup artifacts; upload to releases.
5. (Optional) `flutter test integration_test` on the Windows runner for the
   headless-able subset.

> The Linux/Mac sandbox can build/run the **UI** for fast iteration and can run
> the **Rust core tests**, but Windows-specific audio/SMTC/DPAPI must be
> validated on Windows (locally or via the CI Windows runner).

---

## 20. Milestone roadmap

Each phase ends with a runnable, reviewable milestone. Effort is a rough guide.

### Phase 0 — Spike & de-risk (1–2 days) — *gate before building UI*
- [ ] In a Rust scratch crate: set ARL cookie → `deezer.getUserData` → tokens.
- [ ] Resolve one track: `song.getListData` → `get_url` → signed URL.
- [ ] Decrypt a byte range and verify against a reference (deemix) — **this
      spike proves the entire premise.**
- [ ] Determine which qualities return plain vs. encrypted streams for a test
      account.
- **Exit:** a CLI that prints "authenticated ✓, resolved ✓, decrypted ✓ (hash
  match)".

### Phase 1 — App scaffold + design system (2–3 days)
- [ ] Flutter Windows project, Riverpod + go_router shell, dark theme.
- [ ] Design tokens (§9) as code; fonts bundled locally.
- [ ] Component library: PosterCard, Row, HeroBillboard, NowPlayingBar,
      FullPlayer shell (empty states), navigation skeleton.
- **Exit:** launchable Windows app with the Netflix-look home shell and empty
  rows; golden tests pass.

### Phase 2 — Deezer gateway (3–4 days)
- [ ] Rust `DeezerClient` with endpoint methods (§10.2), reqwest client,
      retry/backoff, token lifecycle.
- [ ] FRB bindings; Dart repositories + models.
- [ ] Search + track/album/artist/playlist/chart resolution.
- **Exit:** search returns real results; detail pages render real tracklists.

### Phase 3 — Audio engine (4–5 days)
- [ ] Decrypting stream source in Rust (golden tests green).
- [ ] media_kit integration: gapless, seek, volume, repeat, queue.
- [ ] SMTC + media keys; quality ladder.
- **Exit:** click a track → gapless playback with seek; SMTC shows art/buttons.

### Phase 4 — Browse experience (2–3 days)
- [ ] Home hero + rows (charts, genres, new releases).
- [ ] Search results categories; album/artist/playlist pages; queue UI.
- **Exit:** full browse loop works end-to-end.

### Phase 5 — Library + events + shuffle (2–3 days)
- [ ] Local event capture + drift schema (§12.1); local "library" (saves).
- [ ] Standard + true shuffle; session persistence.
- **Exit:** plays/skips persist across restarts; true shuffle never repeats.

### Phase 6 — Recommender v1 (4–5 days)
- [ ] Embeddings (co-occurrence SVD + word2vec), user vector.
- [ ] Candidate funnel (ANN, sequential, content, Deezer, explore).
- [ ] Weighted-LR ranker + MMR; nightly retrain; offline eval harness.
- [ ] Home "For You" rows, track/artist/album radio, "Make a Mix".
- **Exit:** offline eval meets §12.8 targets; mixes feel relevant.

### Phase 7 — Smart Shuffle + Automix (4–5 days)
- [ ] Thompson-sampling injection engine + feedback loop (§13.2).
- [ ] BPM/key feature fetch + beat grid; equal-power crossfade + time-stretch
      (§13.3); Automix toggle with intensity setting.
- **Exit:** Automix blends compatible tracks; Smart Shuffle injects badged,
  feedback-able recommendations.

### Phase 8 — Polish & performance (3–4 days)
- [ ] Virtualization, prefetch, caching budgets (§14); 60 fps audit.
- [ ] Settings (quality, crossfade, shuffle defaults, ARL management, cache).
- [ ] Error/empty states; ARL expiry UX; offline-resilience.
- **Exit:** performance budget (§4.2) met on a real Windows machine.

### Phase 9 — Packaging & release (2 days)
- [ ] MSIX + Inno Setup via flutter_distributor; code signing; CI release job.
- **Exit:** installable, updatable Windows build.

### Phase 10 — Hardening & docs (2 days)
- [ ] Full test suite green on CI (Windows), docs (README, DECISIONS),
      privacy/ToS screen.
- **Exit:** Definition of Done (§21) checklist complete.

---

## 21. Definition of done

The project is "done" when all of these are true:

- [ ] ARL is stored encrypted; the only authenticated account-scope call is the
      token extraction; zero user-profile data is fetched or rendered (§16.2).
- [ ] Gapless playback; next-track prefetch; < 500 ms track start; < 2 s launch.
- [ ] All four shuffle modes behave per §13.1; true shuffle never repeats early.
- [ ] Automix and Smart Shuffle work and degrade gracefully.
- [ ] Recommender beats popularity baseline on the offline eval (§12.8).
- [ ] Netflix design tokens (§9) drive 100% of the UI; no hardcoded colors.
- [ ] Golden decryptor tests byte-for-byte match the reference.
- [ ] Windows MSIX/EXE builds and installs; SMTC + media keys work.
- [ ] Performance budgets (§14.4) hold on real hardware.
- [ ] No ARL or personal data in logs, crash reports, or telemetry.

---

## 22. Risks & mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Deezer changes gw-light/get_url | app breaks | isolate transport behind `DeezerClient`; GraphQL fallback (§10.2) |
| Decryption format changes | no playback | golden tests + pin version; Phase 0 spike detects early |
| ARL expiry / bans | lockout | friendly re-auth flow; rate limits; quality ladder |
| media_kit Windows issues | playback broken | just_audio_windows fallback (Automix degrades) |
| Rec engine cold start | boring home | charts/editorial + content-based priors + no-signup |
| Overfitting to niche taste | samey recs | bandit exploration + MMR diversity + churn penalty |
| Trademark/IP misuse | legal | no Netflix assets/fonts; lookalike fonts + tokens only (§17) |
| FRB build friction | slow start | gateway prototypable in Dart; only decryptor must be Rust |

---

## 23. Open questions & decision log

Seed the `DECISIONS.md` with these; the next agent MUST record any reversal.

| # | Decision | Status |
| --- | --- | --- |
| D1 | Windows-first Flutter, Rust core via FRB | decided |
| D2 | Deezer via gw-light (deemix/deezer-py foundation), QBDLX pattern generalized | decided |
| D3 | media_kit primary, just_audio_windows fallback | decided |
| D4 | Inter + Barlow as Netflix-Sans stand-ins | decided |
| D5 | "streamless" = seamless/gapless interpretation | decided (confirm with user if it meant something else) |
| Q1 | Should Smart Shuffle only inject into *user* playlists, or also radio/albums? | propose: everywhere a queue exists |
| Q2 | Is FLAC required for MVP or is MP3_320 acceptable? | propose: support both, default MP3_320 |
| Q3 | "Make a Mix" — multi-seed artist blend needed at launch? | propose: Phase 6+ |

---

## 24. Quickstart for the next agent

```bash
# 0. Prereqs
flutter --version          # >= 3.x
rustup show                # stable toolchain
flutter_rust_bridge_codegen --version
# Windows: Visual Studio 2022 + C++ workload + Win SDK

# 1. Scaffold (from this repo root)
flutter create . --platforms=windows --org dev.hirena --project-name hirena_music
flutter pub add flutter_riverpod go_router media_kit media_kit_libs_windows_audio \
  audio_service smtc_windows flutter_rust_bridge drift drift_flutter \
  sqlite3_flutter_libs cached_network_image google_fonts window_manager dio collection
flutter pub add --dev flutter_lints golden_toolkit

# 2. Rust core
mkdir -p rust/src && cd rust
cargo init --name hirena_core
cargo add flutter_rust_bridge reqwest serde serde_json blowfish cbc cipher \
  md-5 ndarray nalgebra rand rand_distr tokio
cd ..

# 3. Codegen + build
flutter_rust_bridge_codegen generate
cargo build --manifest-path rust/Cargo.toml

# 4. Run (Windows)
flutter run -d windows
```

Then execute **Phase 0 (the spike)** before anything else — it validates the
ARL→stream→decrypt chain that the entire product depends on.

---

## 25. References

**Deezer / streaming foundations**
- deemix (ARL auth, gw-light API, `src/utils/decryption.py` decryptor) — github.com/deemix
- deezer-py (Deezer client library used by deemix) — pypi/github
- freyr (Node.js Deezer ARL **streamer** — proof of on-the-fly decryption streaming) — github.com/miraclx/freyr-js
- dzr `deezer protection` gist (gw-light + get_url curl flow) — github.com/yne/dzr
- music-assistant `deezer-python-gql` (modern GraphQL "Pipe" client: get_track, get_similar_tracks, get_track_mix, get_flow, get_charts) — github.com/music-assistant/deezer-python-gql
- Deezer official public API (catalog-only, for reference) — developers.deezer.com/api

**Recommendation algorithms**
- Covington, Adams, Sargin — *Deep Neural Networks for YouTube Recommendations* (RecSys 2016)
- Spotify research on Discover Weekly (matrix factorization/ALS, word2vec track embeddings, reinforcement learning for playlists)
- "How the Spotify Algorithm Works" (multi-stage retrieval → ranking → re-ranking; 30 s skip signal; Smart Shuffle/Autoplay semantics)
- MMR (Carbonell & Goldstein, 1998) for diversity re-ranking
- Multi-armed bandits (epsilon-greedy, Thompson sampling)

**Design**
- Netflix brand palette (`#E50914`, `#B20710`, `#000000`, `#FFFFFF`), Netflix Sans (proprietary; Dalton Maag) — used only as *inspiration*; implement with Inter/Barlow per §17

**Flutter / audio**
- media_kit (libmpv bindings), just_audio + just_audio_windows (WinRT), audio_service, smtc_windows
- flutter_rust_bridge; RustCrypto `blowfish` + `cbc` (CTS)
