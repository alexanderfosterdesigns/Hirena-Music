import 'dart:math';

import '../core/result.dart';
import '../deezer/gateway.dart';
import '../deezer/models.dart';
import 'bandit.dart';
import 'events.dart';
import 'profile.dart';
import 'rank.dart';

/// Local recommendation engine: Spotify-style implicit feedback +
/// co-occurrence (collaborative/sequential signal) with a YouTube-style
/// weighted relevance scorer, MMR diversity, and bandit exploration.
final class RecommendationService {
  RecommendationService({required this.gateway, Bandits? bandits})
      : bandits = bandits ?? Bandits();

  final DeezerGateway gateway;
  final Bandits bandits;

  TasteProfile? _profile;
  final Map<int, Map<int, int>> _cooccur = {}; // trackId -> {nextId: count}
  List<ListeningEvent> _events = const [];
  int _trials = 0;

  TasteProfile get profile => _profile ?? TasteProfile.fromEvents(const []);

  bool get isReady => _events.isNotEmpty;

  void train(List<ListeningEvent> events) {
    _events = events;
    _profile = TasteProfile.fromEvents(events);
    _cooccur.clear();
    final bySession = <String?, List<ListeningEvent>>{};
    for (final e in events) {
      bySession.putIfAbsent(e.sessionId, () => []).add(e);
    }
    for (final sess in bySession.values) {
      sess.sort((a, b) => a.startedAt.compareTo(b.startedAt));
      for (var i = 0; i < sess.length - 1; i++) {
        final a = sess[i].trackId;
        final b = sess[i + 1].trackId;
        if (a == b) continue;
        _cooccur.putIfAbsent(a, () => {})[b] =
            (_cooccur[a]![b] ?? 0) + 1;
      }
    }
    bandits.anneal(_events.length);
  }

  /// Co-occurrence neighbors of [trackId], sorted by frequency.
  List<int> cooccurring(int trackId, {int limit = 12}) {
    final m = _cooccur[trackId];
    if (m == null) return const [];
    final entries = m.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(limit).map((e) => e.key).toList();
  }

  /// Builds a personalized track list around [seedTrackIds].
  Future<List<Track>> recommendations({
    required List<int> seedTrackIds,
    int limit = 30,
    bool explore = false,
  }) async {
    final p = _profile;
    if (p == null) return const [];

    final candidateIds = <int>[];
    final cooccurScores = <int, double>{};
    final seen = <int>{...seedTrackIds};

    // 1) Sequential/co-occurrence candidates.
    for (final seed in seedTrackIds.take(8)) {
      for (final id in cooccurring(seed)) {
        if (seen.add(id)) {
          candidateIds.add(id);
        }
        cooccurScores[id] = max(cooccurScores[id] ?? 0, _cooccur[seed]![id]!.toDouble());
      }
    }

    // 2) Deezer's own "similar tracks" (nominator, not authority).
    final deezerSim = <Track>[];
    if (!explore) {
      for (final seed in seedTrackIds.take(3)) {
        final r = await gateway.similarTracks(seed);
        if (r.isOk) {
          deezerSim.addAll((r as Ok<List<Track>>).value);
        }
      }
    }
    for (final t in deezerSim) {
      if (seen.add(t.id)) candidateIds.add(t.id);
    }

    // 3) Explore: charts (popularity prior) — "good random".
    if (explore || candidateIds.length < limit) {
      final r = await gateway.charts();
      if (r.isOk) {
        final charts = (r as Ok<Charts>).value;
        for (final t in charts.tracks) {
          if (seen.add(t.id)) candidateIds.add(t.id);
          if (candidateIds.length > limit * 4) break;
        }
      }
    }

    if (candidateIds.isEmpty) return const [];

    // Fetch metadata (for ranking features) — best effort.
    final meta = <int, Track>{};
    final metaRes = await gateway.tracks(candidateIds.take(120).toList());
    if (metaRes.isOk) {
      for (final t in (metaRes as Ok<List<Track>>).value) {
        meta[t.id] = t;
      }
    }
    // Deezer similar already has metadata.
    for (final t in deezerSim) {
      meta[t.id] = t;
    }

    final candidates = candidateIds.map((id) {
      final t = meta[id];
      final days = _releaseDaysAgo(t);
      return Candidate(
        trackId: id,
        provenance: cooccurScores.containsKey(id) ? {'cooccur'} : {'deezer', 'explore'},
        genreId: t?.genreId,
        bpm: t?.bpm,
        gain: t?.gain,
        artistId: t?.artistId,
        popularity: 0.5,
        cooccurScore: cooccurScores[id] ?? 0,
        releaseDaysAgo: days,
      );
    }).toList();

    final ranked = Ranker.rank(candidates, p, limit: limit, bandits: bandits);

    // Resolve full tracks for the ranked ids.
    final missing = ranked.where((id) => !meta.containsKey(id)).toList();
    if (missing.isNotEmpty) {
      final r = await gateway.tracks(missing);
      if (r.isOk) {
        for (final t in (r as Ok<List<Track>>).value) {
          meta[t.id] = t;
        }
      }
    }
    return ranked.map((id) => meta[id]).whereType<Track>().toList();
  }

  /// Smart-shuffle injections: bandit-chosen, novel (not in [exclude]).
  Future<List<Track>> smartInject(List<Track> base, int n) async {
    final exclude = base.map((t) => t.id).toSet();
    final seeds = _profile?.recentTracks.take(10).toList() ?? const [];
    final picks = <Track>[];
    var guard = 0;
    while (picks.length < n && guard < n * 3) {
      guard++;
      final recs = await recommendations(
        seedTrackIds: seeds.isEmpty ? base.take(3).map((t) => t.id).toList() : seeds,
        limit: n * 2,
        explore: bandits.shouldExplore(),
      );
      for (final t in recs) {
        if (!exclude.contains(t.id) && picks.length < n) {
          picks.add(t);
          exclude.add(t.id);
        }
      }
      if (recs.isEmpty) break;
    }
    _trials++;
    return picks;
  }

  /// A radio: starts from a seed and follows co-occurrence + Deezer similarity.
  Future<List<Track>> radio(Track seed, {int limit = 40}) async {
    final out = <Track>[seed];
    final recs = await recommendations(
      seedTrackIds: [seed.id],
      limit: limit,
      explore: true,
    );
    out.addAll(recs);
    return out;
  }

  int? _releaseDaysAgo(Track? t) => null; // gw tracks lack release date; opt-in later

  int get trials => _trials;
}
