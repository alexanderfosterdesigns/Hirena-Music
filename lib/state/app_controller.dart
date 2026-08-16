import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../audio/player_controller.dart';
import '../audio/proxy_server.dart';
import '../core/logging.dart';
import '../core/result.dart';
import '../data/arl_vault.dart';
import '../data/db.dart';
import '../data/settings.dart';
import '../deezer/gateway.dart';
import '../deezer/models.dart';
import '../recsys/bandits.dart';
import '../recsys/events.dart';
import '../recsys/service.dart';
import '../recsys/shuffle.dart';

enum AppStatus { loading, ready, error }

/// Central app state: auth, settings, library, recommender, and the recorder.
final class AppController extends ChangeNotifier {
  AppController({
    required DeezerGateway gateway,
    required StreamProxyServer proxy,
    required PlayerController player,
  })  : gateway = gateway,
        proxy = proxy,
        player = player,
        bandits = Bandits() {
    rec = RecommendationService(gateway: gateway, bandits: bandits);
    _sessionId = const Uuid().v4();
    _bootstrap();
  }

  final DeezerGateway gateway;
  final StreamProxyServer proxy;
  final PlayerController player;
  final Bandits bandits;
  late final RecommendationService rec;

  String _sessionId = '';
  AppStatus status = AppStatus.loading;
  String? errorMessage;

  late HirenaDb db;
  late AppSettings settings;
  late ArlVault vault;

  bool get isAuthed => gateway.isAuthed;
  bool get ready => status == AppStatus.ready;
  int get maxQuality => gateway.maxFormat;
  int get quality => settings.quality;
  bool get automix => settings.automix;

  Future<void> _bootstrap() async {
    try {
      db = await HirenaDb.open();
      settings = await AppSettings.load();
      vault = await ArlVault.open();

      final arl = await vault.read();
      if (arl != null && arl.isNotEmpty) {
        await gateway.loginWithArl(arl);
      }

      final events = await db.events();
      rec.train(events);

      await proxy.start();
      _attachRecorder();

      status = AppStatus.ready;
      notifyListeners();
    } catch (e, st) {
      status = AppStatus.error;
      errorMessage = e.toString();
      HLog.e('bootstrap failed', e, st);
      notifyListeners();
    }
  }

  Future<bool> login(String arl) async {
    final r = await gateway.loginWithArl(arl);
    if (r is Err<SessionInfo>) {
      errorMessage = r.error.message;
      notifyListeners();
      return false;
    }
    await vault.write(arl);
    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    gateway.logout();
    await vault.clear();
    notifyListeners();
  }

  Future<void> setQuality(int q) async {
    await settings.setQuality(q);
    notifyListeners();
  }

  Future<void> setAutomix(bool v) async {
    await settings.setAutomix(v);
    notifyListeners();
  }

  Future<void> setDefaultShuffle(ShuffleMode m) => settings.setDefaultShuffle(m.name);

  // --- Playback -------------------------------------------------------------

  Future<void> playTrack(Track t) => player.playTrack(t, quality: quality);

  Future<void> playTracks(
    List<Track> tracks, {
    int startIndex = 0,
    ShuffleMode? shuffleMode,
  }) {
    final pool =
        tracks.map((t) => QueuedTrack(track: t, quality: quality)).toList();
    return player.playQueue(pool,
        startIndex: startIndex, shuffleMode: shuffleMode ?? _defaultShuffle());
  }

  ShuffleMode _defaultShuffle() => switch (settings.defaultShuffle) {
        'trueShuffle' => ShuffleMode.trueShuffle,
        'standard' => ShuffleMode.standard,
        'smart' => ShuffleMode.smart,
        _ => ShuffleMode.sequential,
      };

  /// Enables Smart Shuffle on the current queue by injecting recommendations.
  Future<void> enableSmartShuffle() async {
    final base = player.pool;
    if (base.isEmpty) return;
    final injects = await rec.smartInject(base.map((e) => e.track).toList(), 5);
    final smart = injects
        .map((t) => QueuedTrack(track: t, quality: quality, smart: true, origin: 'smart'))
        .toList();
    if (smart.isEmpty) return;
    await player.playQueue([...base, ...smart],
        startIndex: player.positionIndex, shuffleMode: ShuffleMode.smart);
  }

  // --- Library --------------------------------------------------------------

  Future<void> toggleSave(Track t) async {
    final saved = await db.isSaved(t.id);
    if (saved) {
      await db.unsaveTrack(t.id);
    } else {
      await db.saveTrack(jsonEncode(_trackJson(t)), trackId: t.id);
      await _recordAction(t, ListenAction.save);
    }
    notifyListeners();
  }

  Future<bool> isSaved(int id) => db.isSaved(id);

  // --- Recorder -------------------------------------------------------------

  int? _lastTrackId;
  DateTime? _lastStartedAt;
  int _lastDurationMs = 0;
  int? _lastArtistId;
  int? _lastGenreId;
  int? _lastBpm;
  int _sessionPos = 0;

  void _attachRecorder() {
    player.addListener(_onPlayerTick);
  }

  void _onPlayerTick() {
    final cur = player.current;
    if (cur?.id == _lastTrackId) return;
    _finalizeLast();
    if (cur != null) {
      _lastTrackId = cur.id;
      _lastStartedAt = DateTime.now();
      _lastDurationMs = cur.track.duration * 1000;
      _lastArtistId = cur.track.artistId;
      _lastGenreId = cur.track.genreId;
      _lastBpm = cur.track.bpm;
    }
  }

  void _finalizeLast() {
    if (_lastTrackId == null || _lastStartedAt == null) return;
    final elapsed = DateTime.now().difference(_lastStartedAt!).inMilliseconds;
    final ratio = _lastDurationMs == 0
        ? 1.0
        : (elapsed / _lastDurationMs).clamp(0.0, 1.0);
    final action = elapsed < _lastDurationMs - 2000
        ? (elapsed < 30000 ? ListenAction.skip : ListenAction.play)
        : ListenAction.play;
    db.insertEvent(ListeningEvent(
      trackId: _lastTrackId!,
      startedAt: _lastStartedAt!,
      durationMs: _lastDurationMs,
      completionRatio: ratio,
      action: action,
      artistId: _lastArtistId,
      genreId: _lastGenreId,
      bpm: _lastBpm,
      sessionId: _sessionId,
      positionInSession: _sessionPos++,
    ));
    _lastTrackId = null;
    _lastStartedAt = null;
  }

  Future<void> _recordAction(Track t, ListenAction action) async {
    await db.insertEvent(ListeningEvent(
      trackId: t.id,
      startedAt: DateTime.now(),
      durationMs: t.duration * 1000,
      completionRatio: 1.0,
      action: action,
      artistId: t.artistId,
      genreId: t.genreId,
      bpm: t.bpm,
      sessionId: _sessionId,
      positionInSession: _sessionPos++,
    ));
  }

  Map<String, Object?> _trackJson(Track t) => {
        'id': t.id,
        'title': t.title,
        'artist': t.artistName,
        'artist_id': t.artistId,
        'album': t.albumTitle,
        'album_id': t.albumId,
        'cover': t.albumCoverMd5,
        'duration': t.duration,
        'bpm': t.bpm,
        'genre_id': t.genreId,
      };

  @override
  void dispose() {
    player.removeListener(_onPlayerTick);
    proxy.stop();
    super.dispose();
  }
}
