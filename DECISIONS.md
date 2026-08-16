# Decision Log

This log records deviations from `PLAN.md` and their rationale. Append, never silently rewrite.

## D1 — Pure-Dart MVP instead of Flutter+Rust (flutter_rust_bridge)
- **Date:** 2026-08-16
- **Decision:** Implement the MVP in pure Dart (no Rust core). Crypto via `pointycastle`
  (Blowfish, AES-128-ECB, MD5); networking via `dio`; audio via `just_audio` fed by a
  local decrypting HTTP proxy (`dart:io HttpServer`); recommender/shuffle/automix in Dart.
- **Why:** The build sandbox cannot install the Flutter or Rust toolchains (package
  registries are network-blocked), so a Rust + flutter_rust_bridge core could not be
  codegen'd or compiled here and would be the single largest unverifiable build risk for
  the next agent. pointycastle provides the required primitives in pure Dart, and the
  per-block decryption throughput (~tens of KB/s at MP3_320) is trivial for any CPU.
  The plan explicitly allowed a Dart prototype of the gateway; this extends that escape
  hatch to the whole MVP.
- **Revert path:** Module boundaries mirror the planned Rust layout (`deezer/`,
  `recsys/`, `audio/`), so a Rust core can be swapped in later without UI changes.
- **Impact:** Slight loss vs. the "audited RustCrypto primitives" goal; mitigated by
  golden tests (see `docs/DEEZER_REFERENCE.md`) run in CI against cross-implementation
  vectors (OpenSSL + egoroof-blowfish JS).

## D2 — Local decrypting HTTP proxy for playback
- **Decision:** The app runs a loopback `HttpServer` (`127.0.0.1`) that resolves a
  track's encrypted stream URL, decrypts on the fly, and serves plain audio with
  `Accept-Ranges`/`Range` support; `just_audio` plays `http://127.0.0.1:<port>/track/<id>`.
- **Why:** `just_audio`'s `StreamAudioSource` (byte-stream feeding) has platform-varying
  seek support that cannot be verified here; a local HTTP URL uses the engine's mature,
  seekable, gapless-friendly HTTP path and keeps decryption in one testable module.
- **Note:** This is a desktop app; loopback is internal to the process (not web preview).
