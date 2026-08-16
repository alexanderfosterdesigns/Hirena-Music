import 'dart:math';

/// An Automix transition plan for a track pair.
final class AutomixPlan {
  const AutomixPlan({
    required this.beatMatch,
    required this.crossfadeMs,
    required this.tempoRatio,
    this.mode = 'gapless',
  });

  final bool beatMatch;
  final int crossfadeMs;
  final double tempoRatio;
  final String mode; // 'beatmatch' | 'crossfade' | 'gapless'

  static const gapless = AutomixPlan(
    beatMatch: false,
    crossfadeMs: 0,
    tempoRatio: 1.0,
  );
}

/// Plans a beat-matched crossfade between two tracks using BPM/gain (Spotify
/// Automix analog). Key (Camelot) is not exposed by Deezer's API, so harmonic
/// mixing is approximated via BPM + gain compatibility.
abstract final class Automix {
  /// Plans a transition from [fromBpm]/[fromGain] to [toBpm]/[toGain].
  static AutomixPlan plan({
    required int? fromBpm,
    required double? fromGain,
    required int? toBpm,
    required double? toGain,
    int intensityMs = 4000,
  }) {
    final a = fromBpm ?? 0;
    final b = toBpm ?? 0;
    if (a <= 0 || b <= 0) {
      return AutomixPlan(
        beatMatch: false,
        crossfadeMs: intensityMs.clamp(0, 12000).toInt(),
        tempoRatio: 1.0,
        mode: 'crossfade',
      );
    }

    final ratio = b / a;
    if (ratio > 0.8 && ratio < 1.25) {
      // Beat-matchable: time-stretch the incoming track to the outgoing tempo.
      final gainDiff = ((fromGain ?? 0) - (toGain ?? 0)).abs();
      final length = intensityMs.clamp(2000, 16000).toInt();
      return AutomixPlan(
        beatMatch: true,
        crossfadeMs: length,
        tempoRatio: ratio,
        mode: gainDiff < 3 ? 'beatmatch' : 'crossfade',
      );
    }

    // Too far apart — plain crossfade or gapless.
    return AutomixPlan(
      beatMatch: false,
      crossfadeMs: intensityMs.clamp(0, 8000).toInt(),
      tempoRatio: 1.0,
      mode: 'crossfade',
    );
  }

  /// Equal-power crossfade gains: g1(t)=cos, g2(t)=sin over [0,1].
  static (double, double) equalPowerGains(double t) {
    final theta = (pi / 2) * t.clamp(0.0, 1.0).toDouble();
    return (cos(theta), sin(theta));
  }
}
