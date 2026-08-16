import 'dart:math';

/// Shuffle modes.
enum ShuffleMode { sequential, standard, trueShuffle, smart }

/// Pure, seedable shuffle algorithms. No repeats until the pool is exhausted
/// (every mode produces a permutation).
abstract final class Shuffler {
  static Random rng = Random();

  /// Produces a play order of pool indices (a permutation of 0..n-1) with
  /// [startAt] placed first when >= 0.
  ///
  /// - [ShuffleMode.trueShuffle]: uniform random permutation.
  /// - [ShuffleMode.standard]: permutation with a repair pass that separates
  ///   adjacent same-artist tracks (soft constraint).
  /// - [ShuffleMode.smart]: standard shuffle; injection of recommendation
  ///   slots is handled by [interleaveSmart].
  static List<int> shuffle(
    int n, {
    required ShuffleMode mode,
    required int Function(int index) artistKey,
    int startAt = -1,
    Random? random,
  }) {
    if (n <= 1) return List.generate(n, (i) => i);
    final r = random ?? rng;
    final order = List<int>.generate(n, (i) => i);

    switch (mode) {
      case ShuffleMode.sequential:
        break;
      case ShuffleMode.trueShuffle:
        order.shuffle(r);
        break;
      case ShuffleMode.standard:
      case ShuffleMode.smart:
        order.shuffle(r);
        _repairAdjacent(order, artistKey);
        break;
    }

    if (startAt >= 0 && startAt < n) {
      final pos = order.indexOf(startAt);
      if (pos > 0) {
        final t = order[0];
        order[0] = order[pos];
        order[pos] = t;
      }
    }
    return order;
  }

  /// Separates adjacent same-artist tracks with a bounded repair pass.
  static void _repairAdjacent(List<int> order, int Function(int) artistKey) {
    final n = order.length;
    for (var pass = 0; pass < 3; pass++) {
      var changed = false;
      for (var i = 0; i < n - 1; i++) {
        if (artistKey(order[i]) != artistKey(order[i + 1])) continue;
        for (var j = i + 1; j < n; j++) {
          final aOk = artistKey(order[j]) != artistKey(order[i]);
          final bOk = j == n - 1 || artistKey(order[j]) != artistKey(order[j - 1]);
          if (aOk && bOk) {
            final t = order[i + 1];
            order[i + 1] = order[j];
            order[j] = t;
            changed = true;
            break;
          }
        }
      }
      if (!changed) break;
    }
  }

  /// Interleaves [smartIndices] into [baseOrder] roughly every [k] slots.
  /// Smart tracks are placed at positions k, 2k, ... within the result.
  static List<int> interleaveSmart(List<int> baseOrder, List<int> smartIndices, int k) {
    if (smartIndices.isEmpty) return List.of(baseOrder);
    final out = <int>[];
    var si = 0;
    var bi = 0;
    var sinceInjection = 0;
    final effectiveK = k.clamp(1, 1 << 30);
    while (bi < baseOrder.length || si < smartIndices.length) {
      if (si < smartIndices.length &&
          (sinceInjection >= effectiveK || bi >= baseOrder.length)) {
        out.add(smartIndices[si++]);
        sinceInjection = 0;
      } else {
        out.add(baseOrder[bi++]);
        sinceInjection++;
      }
    }
    return out;
  }
}
