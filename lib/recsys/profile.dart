import 'dart:math';

import 'events.dart';

/// A user's taste profile, derived exclusively from local listening events.
final class TasteProfile {
  TasteProfile._();

  /// Track id → implicit-feedback weight (higher = stronger affinity).
  final Map<int, double> trackWeights = {};

  /// Artist id → aggregated weight.
  final Map<int, double> artistWeights = {};

  /// Genre id → normalized affinity (0..1).
  final Map<int, double> genreAffinity = {};

  /// BPM bucket → count (for tempo preference).
  final Map<int, int> bpmBuckets = {};

  /// Most recently played track ids (newest first).
  final List<int> recentTracks = [];

  /// Build a profile from a chronological list of events.
  factory TasteProfile.fromEvents(List<ListeningEvent> events, {DateTime? now}) {
    final p = TasteProfile._();
    final t = now ?? DateTime.now();
    for (final e in events) {
      final ageDays = t.difference(e.startedAt).inHours / 24.0;
      final decay = pow(0.99, ageDays).toDouble(); // ~10-week half-life
      final w = _weight(e) * decay;
      if (w == 0) continue;

      p.trackWeights[e.trackId] = (p.trackWeights[e.trackId] ?? 0) + w;
      if (e.artistId != null) {
        p.artistWeights[e.artistId!] = (p.artistWeights[e.artistId!] ?? 0) + w;
      }
      if (e.genreId != null) {
        p.genreAffinity[e.genreId!] = (p.genreAffinity[e.genreId!] ?? 0) + w;
      }
      if (e.bpm != null && e.bpm! > 0) {
        final b = _bpmBucket(e.bpm!);
        p.bpmBuckets[b] = (p.bpmBuckets[b] ?? 0) + 1;
      }
    }

    // Normalize genre affinity to 0..1.
    if (p.genreAffinity.isNotEmpty) {
      final maxV = p.genreAffinity.values.reduce(max);
      p.genreAffinity.updateAll((_, v) => v / maxV);
    }

    // Recent tracks (unique, newest first).
    final seen = <int>{};
    for (final e in events.reversed) {
      if (seen.add(e.trackId)) p.recentTracks.add(e.trackId);
      if (p.recentTracks.length >= 50) break;
    }
    return p;
  }

  /// Implicit-feedback weight (Spotify-style). Saves/replays are strong
  /// positives; early skips are negatives; completion scales the base weight.
  static double _weight(ListeningEvent e) {
    var w = 1.0 + 2.0 * e.completionRatio.clamp(0.0, 1.0).toDouble();
    switch (e.action) {
      case ListenAction.save:
        w += 2.0;
      case ListenAction.replay:
        w += 0.5;
      case ListenAction.thumbsUp:
        w += 2.0;
      case ListenAction.thumbsDown:
        w -= 1.5;
      case ListenAction.skip:
        if (e.isEarlySkip) w -= 1.5;
        if (e.smart) w *= 0.5; // weigh injected-test failures less
      case ListenAction.play:
        break;
    }
    return w;
  }

  static int _bpmBucket(int bpm) => (bpm ~/ 10) * 10;

  /// Top genre ids by affinity.
  List<int> topGenres([int n = 5]) {
    final entries = genreAffinity.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(n).map((e) => e.key).toList();
  }
}
