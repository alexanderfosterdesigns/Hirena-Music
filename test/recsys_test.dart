import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hirena_music/recsys/automix.dart';
import 'package:hirena_music/recsys/bandit.dart';
import 'package:hirena_music/recsys/events.dart';
import 'package:hirena_music/recsys/profile.dart';
import 'package:hirena_music/recsys/shuffle.dart';

void main() {
  group('Shuffler', () {
    test('true shuffle is a permutation (no repeats until exhaustion)', () {
      final rng = Random(1);
      final order = Shuffler.shuffle(
        100,
        mode: ShuffleMode.trueShuffle,
        artistKey: (_) => 0,
        random: rng,
      );
      expect(order.toSet().length, 100);
      expect(order, isNot(equals(List.generate(100, (i) => i))));
    });

    test('startAt is placed first', () {
      final order = Shuffler.shuffle(
        10,
        mode: ShuffleMode.trueShuffle,
        artistKey: (_) => 0,
        startAt: 4,
        random: Random(2),
      );
      expect(order.first, 4);
      expect(order.toSet().length, 10);
    });

    test('standard shuffle separates adjacent same-artist tracks', () {
      final order = Shuffler.shuffle(
        30,
        mode: ShuffleMode.standard,
        artistKey: (i) => i ~/ 2, // pairs of same artist
        random: Random(3),
      );
      expect(order.toSet().length, 30);
      for (var i = 0; i < order.length - 1; i++) {
        expect((order[i] ~/ 2), isNot(equals(order[i + 1] ~/ 2)));
      }
    });

    test('interleaveSmart inserts every k slots', () {
      final base = List.generate(12, (i) => i);
      final smart = [100, 101, 102];
      final out = Shuffler.interleaveSmart(base, smart, 4);
      expect(out.where((i) => i >= 100).length, 3);
      expect(out.length, 15);
    });
  });

  group('TasteProfile', () {
    test('saves are strong positives, early skips are negatives', () {
      final now = DateTime.now();
      final save = ListeningEvent(
        trackId: 1,
        startedAt: now,
        durationMs: 200000,
        completionRatio: 1,
        action: ListenAction.save,
        sessionId: 's',
      );
      final skip = ListeningEvent(
        trackId: 2,
        startedAt: now,
        durationMs: 15000,
        completionRatio: 0.1,
        action: ListenAction.skip,
        sessionId: 's',
      );
      final p = TasteProfile.fromEvents([save, skip], now: now);
      expect(p.trackWeights[1], greaterThan(0));
      expect(p.trackWeights[2] ?? 0, lessThan(0));
    });
  });

  group('Bandits', () {
    test('thompson observes shift posteriors toward success', () {
      final b = Bandits(random: Random(4));
      final before = b.posteriors['src'];
      b.observe('src', true);
      final after = b.posteriors['src']!;
      expect(after.alpha, greaterThan(before?.alpha ?? 1));
    });

    test('anneal lowers epsilon', () {
      final b = Bandits();
      final start = b.epsilon;
      b.anneal(1000);
      expect(b.epsilon, lessThan(start));
    });
  });

  group('Automix', () {
    test('beat-matches compatible tempos', () {
      final p = Automix.plan(fromBpm: 120, fromGain: -8, toBpm: 124, toGain: -7);
      expect(p.beatMatch, true);
      expect(p.tempoRatio, closeTo(124 / 120, 0.001));
    });

    test('falls back for incompatible tempos', () {
      final p = Automix.plan(fromBpm: 90, fromGain: -8, toBpm: 180, toGain: -8);
      expect(p.beatMatch, false);
    });

    test('equal-power gains sum-of-squares is 1', () {
      for (var i = 0; i <= 10; i++) {
        final (g1, g2) = Automix.equalPowerGains(i / 10);
        expect(g1 * g1 + g2 * g2, closeTo(1.0, 0.001));
      }
    });
  });
}
