import 'dart:math';

import 'bandit.dart';
import 'profile.dart';

/// A candidate track with the features used to rank it.
final class Candidate {
  const Candidate({
    required this.trackId,
    this.provenance = const {},
    this.genreId,
    this.bpm,
    this.gain,
    this.popularity = 0,
    this.cooccurScore = 0,
    this.artistId,
    this.releaseDaysAgo,
  });

  final int trackId;
  final Set<String> provenance;
  final int? genreId;
  final int? bpm;
  final double? gain;
  final double popularity; // 0..1
  final double cooccurScore;
  final int? artistId;
  final int? releaseDaysAgo;

  Candidate copyWith({Set<String>? provenance, double? cooccurScore}) =>
      Candidate(
        trackId: trackId,
        provenance: provenance ?? this.provenance,
        genreId: genreId,
        bpm: bpm,
        gain: gain,
        popularity: popularity,
        cooccurScore: cooccurScore ?? this.cooccurScore,
        artistId: artistId,
        releaseDaysAgo: releaseDaysAgo,
      );
}

/// Scores candidates (weighted features → engagement proxy) then re-ranks with
/// Maximal Marginal Relevance for diversity.
abstract final class Ranker {
  static const double _lambda = 0.7;

  /// Relevance score (higher = more likely to be engaged with).
  static double relevance(Candidate c, TasteProfile p, {Bandits? bandits}) {
    var s = 0.0;

    // Affinity already expressed in the profile.
    s += (p.trackWeights[c.trackId] ?? 0) * 1.5;

    // Genre affinity.
    if (c.genreId != null) {
      s += (p.genreAffinity[c.genreId] ?? 0) * 2.0;
    }

    // Artist affinity (log-scaled).
    if (c.artistId != null) {
      final aw = p.artistWeights[c.artistId] ?? 0;
      if (aw > 0) s += log(1 + aw) * 1.5;
    }

    // Tempo preference: closeness to the user's most frequent BPM bucket.
    if (c.bpm != null && c.bpm! > 0 && p.bpmBuckets.isNotEmpty) {
      final fav = p.bpmBuckets.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
      final d = (c.bpm! - fav).abs();
      s += max(0.0, 1 - d / 40).toDouble() * 1.2;
    }

    // Sequential (co-occurrence) signal.
    s += c.cooccurScore * 3.0;

    // Popularity prior.
    s += c.popularity * 0.5;

    // Freshness (YouTube "example age" analog).
    final age = c.releaseDaysAgo;
    if (age != null && age >= 0) {
      s += exp(-age / 180).toDouble() * 0.8;
    }

    // Exploration bonus from bandits (uncertainty).
    if (bandits != null) {
      s += bandits.epsilon * 0.4;
    }
    return s;
  }

  /// Ranks [candidates], returning track ids ordered for presentation with
  /// diversity (MMR). [similarity] returns 0..1 in the same feature space.
  static List<int> rank(
    List<Candidate> candidates,
    TasteProfile profile, {
    int limit = 20,
    Bandits? bandits,
  }) {
    final scored = candidates
        .map((c) => (c: c, s: relevance(c, profile, bandits: bandits)))
        .toList()
      ..sort((a, b) => b.s.compareTo(a.s));

    final selected = <Candidate>[];
    for (final item in scored) {
      if (selected.length >= limit) break;
      final rel = item.s;
      var maxSim = 0.0;
      for (final s in selected) {
        maxSim = max(maxSim, _similarity(item.c, s));
      }
      final mmr = _lambda * rel - (1 - _lambda) * maxSim;
      if (selected.isEmpty || mmr > 0) {
        selected.add(item.c);
      }
    }
    return selected.map((c) => c.trackId).toList();
  }

  static double _similarity(Candidate a, Candidate b) {
    var sim = 0.0;
    var terms = 0;
    if (a.artistId != null && b.artistId != null) {
      terms++;
      if (a.artistId == b.artistId) sim += 1.0;
    }
    if (a.genreId != null && b.genreId != null) {
      terms++;
      if (a.genreId == b.genreId) sim += 0.6;
    }
    if (a.bpm != null && b.bpm != null && a.bpm! > 0 && b.bpm! > 0) {
      terms++;
      sim += max(0.0, 1 - (a.bpm! - b.bpm!).abs() / 40).toDouble() * 0.4;
    }
    return terms == 0 ? 0 : sim / terms;
  }
}
