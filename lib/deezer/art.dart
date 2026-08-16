import '../core/constants.dart';

/// Artwork URL builders (see docs/DEEZER_REFERENCE.md §6).
abstract final class Art {
  static String cover(String md5, {int size = 500}) =>
      '$HConstants.coverBase/cover/$md5/${size}x$size-000000-80-0-0.jpg';

  static String artist(String md5, {int size = 500}) =>
      '$HConstants.coverBase/artist/$md5/${size}x$size-000000-80-0-0.jpg';

  /// Picks the size class closest to [logicalSize] for the device pixel ratio.
  static int sizeFor(double logicalSize, double dpr) {
    final px = (logicalSize * dpr).round();
    if (px <= 56) return 56;
    if (px <= 250) return 250;
    if (px <= 500) return 500;
    return 1000;
  }
}
