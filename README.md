# Hirena Music

A **Netflix-designed, Windows-first streaming music app** built with Flutter. It
streams the Deezer catalog using your own **ARL token purely as a streaming key**
(no profile data is ever fetched), with a **local, self-learning recommendation
engine** (Spotify/YouTube-style math), **Automix**, and **Smart / True /
Standard shuffle**.

> Personal-use tool. See `docs/DEEZER_REFERENCE.md` for the integration spec and
> `PLAN.md` for the full engineering plan.

## Status

Early implementation. Working now: Deezer gateway (ARL auth + catalog + stream
resolution), on-the-fly Blowfish-CBC "stripe" decryption (golden-tested against
OpenSSL), the decrypting loopback proxy, `just_audio` playback with the shuffle
family, the recommendation engine (implicit feedback, co-occurrence, weighted
ranking, MMR, bandits), Automix planning, and the Netflix-style UI shell.

## Quickstart (Windows)

Prereqs: Flutter ≥ 3.x (stable), Visual Studio 2022 with the "Desktop development
with C++" workload.

```bash
# 1. Generate the Windows runner (not committed, so it matches your SDK)
flutter create --platforms=windows --org dev.hirena --project-name hirena_music .

# 2. Dependencies
flutter pub get

# 3. Run
flutter run -d windows
```

Paste your Deezer ARL on the first screen (deezer.com → F12 → Application →
Cookies → deezer.com → copy the `arl` cookie value).

## Rendering the UI (PNG screenshots)

The app's **real Flutter widgets** can be rendered to PNGs through Flutter's own
rendering engine (no device needed):

```bash
flutter pub get
flutter test test/screenshots/screenshots_test.dart
```

This writes `screenshots/01-home.png` … `07-library.png` (2880×1800). The same
job runs in CI and uploads a downloadable `ui-renders` artifact on every push.

To capture the *live* app on Windows, run it and use OS screenshot tooling, or:

```bash
flutter run -d windows
flutter screenshot          # only supported on mobile/web devices
```

## Test & verify

```bash
flutter analyze
flutter test          # includes the crypto golden vectors
```

## Layout

- `lib/deezer/` — gateway (ARL auth, gw-light catalog, stream URL resolution),
  crypto (Blowfish stripe + AES stream path), models.
- `lib/audio/` — decrypting proxy server, `just_audio` player, shuffle handling.
- `lib/recsys/` — events, taste profile, ranking, bandits, shuffle, automix.
- `lib/ui/` — design system + screens/widgets (Netflix language).
- `lib/state/` — Riverpod providers + app controller.

## License

GPL-3.0 (see [LICENSE](LICENSE)). Bundled fonts (Inter, Barlow) are OFL-licensed.
