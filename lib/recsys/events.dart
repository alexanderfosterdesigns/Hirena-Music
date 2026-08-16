/// Local listening events — the sole input to the recommendation engine.
/// No user identity, no cloud, no cross-user data.
library;

enum ListenAction { play, skip, save, replay, thumbsUp, thumbsDown }

final class ListeningEvent {
  const ListeningEvent({
    required this.trackId,
    required this.startedAt,
    required this.durationMs,
    required this.completionRatio,
    required this.action,
    this.artistId,
    this.genreId,
    this.bpm,
    this.gain,
    this.sessionId,
    this.positionInSession = 0,
    this.smart = false,
  });

  final int trackId;
  final DateTime startedAt;
  final int durationMs;
  final double completionRatio;
  final ListenAction action;
  final int? artistId;
  final int? genreId;
  final int? bpm;
  final double? gain;
  final String? sessionId;
  final int positionInSession;
  final bool smart;

  /// True when this is a "skip before 30 seconds" (Spotify's confirmed
  /// negative signal).
  bool get isEarlySkip =>
      action == ListenAction.skip && durationMs < 30000;

  Map<String, Object?> toRow() => {
        'track_id': trackId,
        'started_at': startedAt.millisecondsSinceEpoch,
        'duration_ms': durationMs,
        'completion_ratio': completionRatio,
        'action': action.name,
        'artist_id': artistId,
        'genre_id': genreId,
        'bpm': bpm,
        'gain': gain,
        'session_id': sessionId,
        'position_in_session': positionInSession,
        'smart': smart ? 1 : 0,
      };

  static ListeningEvent fromRow(Map<String, Object?> r) => ListeningEvent(
        trackId: r['track_id'] as int,
        startedAt:
            DateTime.fromMillisecondsSinceEpoch((r['started_at'] as int?) ?? 0),
        durationMs: (r['duration_ms'] as int?) ?? 0,
        completionRatio: ((r['completion_ratio'] as num?) ?? 0).toDouble(),
        action: _actionFrom(r['action'] as String?),
        artistId: r['artist_id'] as int?,
        genreId: r['genre_id'] as int?,
        bpm: r['bpm'] as int?,
        gain: (r['gain'] as num?)?.toDouble(),
        sessionId: r['session_id'] as String?,
        positionInSession: (r['position_in_session'] as int?) ?? 0,
        smart: (r['smart'] as int? ?? 0) == 1,
      );

  static ListenAction _actionFrom(String? name) {
    for (final a in ListenAction.values) {
      if (a.name == name) return a;
    }
    return ListenAction.play;
  }
}
