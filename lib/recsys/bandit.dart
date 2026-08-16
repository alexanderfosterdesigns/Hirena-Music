import 'dart:math';

/// Explore/exploit machinery: epsilon-greedy (global) + Thompson sampling over
/// candidate sources (Beta posteriors).
final class Bandits {
  Bandits({Random? random}) : _r = random ?? Random();

  final Random _r;

  double epsilon = 0.25;

  /// Anneals epsilon toward [floor] as [trials] grows.
  void anneal(int trials) {
    epsilon = (0.25 - 0.05) * exp(-trials / 120) + 0.05;
  }

  bool shouldExplore() => _r.nextDouble() < epsilon;

  // --- Thompson sampling over named sources --------------------------------

  final Map<String, _Beta> _posteriors = {};

  String sample(List<String> options) {
    if (options.isEmpty) return '';
    var best = options.first;
    var bestV = -1.0;
    for (final o in options) {
      final v = (_posteriors[o] ?? const _Beta(1, 1)).sample(_r);
      if (v > bestV) {
        bestV = v;
        best = o;
      }
    }
    return best;
  }

  void observe(String option, bool success) {
    final p = _posteriors[option] ?? const _Beta(1, 1);
    _posteriors[option] =
        success ? _Beta(p.alpha + 1, p.beta) : _Beta(p.alpha, p.beta + 1);
  }

  Map<String, ({double alpha, double beta})> get posteriors => {
        for (final e in _posteriors.entries)
          e.key: (alpha: e.value.alpha, beta: e.value.beta),
      };
}

final class _Beta {
  const _Beta(this.alpha, this.beta);

  final double alpha;
  final double beta;

  double sample(Random r) {
    final g1 = _gamma(r, alpha);
    final g2 = _gamma(r, beta);
    return g1 / (g1 + g2);
  }
}

/// Marsaglia–Tsang gamma sampler (shape > 0, scale = 1).
double _gamma(Random r, double shape) {
  if (shape < 1) {
    return _gamma(r, shape + 1) * pow(r.nextDouble(), 1 / shape).toDouble();
  }
  final d = shape - 1 / 3;
  final c = 1 / sqrt(9 * d);
  for (;;) {
    double x;
    double v;
    do {
      x = _gauss(r);
      v = 1 + c * x;
    } while (v <= 0);
    v = v * v * v;
    final u = r.nextDouble();
    if (u < 1 - 0.0331 * x * x * x * x) return d * v;
    if (log(u) < 0.5 * x * x + d * (1 - v + log(v))) return d * v;
  }
}

double _gauss(Random r) {
  final u1 = max(r.nextDouble(), 1e-12);
  final u2 = r.nextDouble();
  return sqrt(-2 * log(u1)) * cos(2 * pi * u2);
}
