import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../core/logging.dart';
import '../deezer/models.dart';
import '../recsys/shuffle.dart';
import 'proxy_server.dart';

enum RepeatMode { off, all, one }

/// An entry in the playable pool (may be a smart-shuffle injection).
final class QueuedTrack {
  const QueuedTrack({
    required this.track,
    required this.quality,
    this.smart = false,
    this.origin = 'user',
  });

  final Track track;
  final int quality;
  final bool smart;
  final String origin;

  int get id => track.id;
}

/// Wraps [AudioPlayer] with Hirena's queue + shuffle semantics.
final class PlayerController extends ChangeNotifier {
  PlayerController(this._proxy) {
    _player = AudioPlayer();
    _subs.add(_player.playerStateStream.listen((s) {
      _playing = s.playing;
      _processing = s.processingState;
      _notify();
    }));
    _subs.add(_player.positionStream.listen((p) {
      _position = p;
      _notify();
    }));
    _subs.add(_player.durationStream.listen((d) {
      _duration = d ?? Duration.zero;
      _notify();
    }));
    _subs.add(_player.bufferedPositionStream.listen((b) {
      _buffered = b;
      _notify();
    }));
    _subs.add(_player.currentIndexStream.listen((i) {
      _handleIndexChange(i);
    }));
    _subs.add(_player.processingStateStream.listen((ps) {
      if (ps == ProcessingState.completed) _handleCompleted();
    }));
    _subs.add(_player.errorStream.listen((e) {
      HLog.e('player error', e);
    }));
  }

  final StreamProxyServer _proxy;
  late final AudioPlayer _player;
  final List<StreamSubscription<dynamic>> _subs = [];

  List<QueuedTrack> _pool = const [];
  List<int> _order = const [];
  int _pos = -1;

  bool _playing = false;
  ProcessingState _processing = ProcessingState.idle;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _buffered = Duration.zero;
  RepeatMode _repeat = RepeatMode.off;
  ShuffleMode _shuffle = ShuffleMode.sequential;

  QueuedTrack? get current => _current();
  QueuedTrack? get next => _at(_pos + 1);
  bool get playing => _playing;
  ProcessingState get processing => _processing;
  Duration get position => _position;
  Duration get duration => _duration;
  Duration get buffered => _buffered;
  RepeatMode get repeat => _repeat;
  ShuffleMode get shuffle => _shuffle;
  List<QueuedTrack> get pool => List.unmodifiable(_pool);
  int get positionIndex => _pos;
  int get queueLength => _order.length;

  QueuedTrack? _current() {
    if (_pos < 0 || _pos >= _order.length) return null;
    final i = _order[_pos];
    if (i < 0 || i >= _pool.length) return null;
    return _pool[i];
  }

  QueuedTrack? _at(int orderPos) {
    if (orderPos < 0 || orderPos >= _order.length) return null;
    final i = _order[orderPos];
    return (i < 0 || i >= _pool.length) ? null : _pool[i];
  }

  // --- Queue control --------------------------------------------------------

  /// Replaces the queue and begins playing at [startIndex] (index into [pool]).
  Future<void> playQueue(
    List<QueuedTrack> pool, {
    int startIndex = 0,
    ShuffleMode? shuffleMode,
  }) async {
    if (pool.isEmpty) return;
    _pool = List.of(pool);
    if (shuffleMode != null) _shuffle = shuffleMode;
    _order = _computeOrder(_shuffle, startIndex);
    _pos = _order.indexOf(startIndex);
    if (_pos < 0) _pos = 0;
    await _load();
  }

  /// Plays a single track immediately (replacing the queue with a one-track
  /// queue, or prepending if [enqueue] is true).
  Future<void> playTrack(Track track, {int quality = 3}) async {
    await playQueue([QueuedTrack(track: track, quality: quality)]);
    await _player.play();
  }

  Future<void> togglePlayPause() async {
    if (_playing) {
      await _player.pause();
    } else {
      if (_player.audioSource == null && _order.isNotEmpty) await _load();
      await _player.play();
    }
  }

  Future<void> next() async {
    if (_pos + 1 < _order.length) {
      await _player.seekToNext();
    } else if (_repeat == RepeatMode.all) {
      await _jump(0);
    }
  }

  Future<void> previous() async {
    if (_position > const Duration(seconds: 3)) {
      await _player.seek(Duration.zero);
    } else if (_pos > 0) {
      await _player.seekToPrevious();
    }
  }

  Future<void> seek(Duration d) => _player.seek(d);

  Future<void> setVolume(double v) => _player.setVolume(v.clamp(0, 1));

  Future<void> setRepeat(RepeatMode m) async {
    _repeat = m;
    _notify();
    await _player.setLoopMode(switch (m) {
      RepeatMode.off => LoopMode.off,
      RepeatMode.all => LoopMode.all,
      RepeatMode.one => LoopMode.one,
    });
  }

  Future<void> setShuffle(ShuffleMode m) async {
    final currentId = _current()?.id;
    _shuffle = m;
    _order = _computeOrder(m, currentId == null ? -1 : _pool.indexWhere((p) => p.id == currentId));
    final oldPos = _pos;
    _pos = currentId == null
        ? 0
        : (_order.indexWhere((i) => _pool[i].id == currentId));
    if (_pos < 0) _pos = oldPos < _order.length ? oldPos : 0;
    await _load();
    _notify();
  }

  List<int> _computeOrder(ShuffleMode m, int startIndex) {
    final n = _pool.length;
    if (m == ShuffleMode.sequential) {
      return List.generate(n, (i) => i);
    }
    return Shuffler.shuffle(
      n,
      mode: m,
      artistKey: (i) => _pool[i].track.artistId,
      startAt: startIndex,
    );
  }

  Future<void> _load() async {
    if (_order.isEmpty) return;
    final sources = <AudioSource>[];
    for (final i in _order) {
      final item = _pool[i];
      sources.add(AudioSource.uri(
        Uri.parse(_proxy.urlFor(item.id, item.quality)),
      ));
    }
    await _player.setAudioSources(
      sources,
      initialIndex: _pos,
      useLazyPreparation: true,
    );
    _notify();
  }

  void _handleIndexChange(int? i) {
    if (i != null && i != _pos) {
      _pos = i;
      _notify();
    }
  }

  void _handleCompleted() {
    if (_repeat == RepeatMode.off && _pos >= _order.length - 1) {
      // End of queue reached.
      _notify();
    }
  }

  Future<void> _jump(int orderPos) async {
    if (orderPos < 0 || orderPos >= _order.length) return;
    _pos = orderPos;
    await _player.seek(Duration.zero, index: orderPos);
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }
}
