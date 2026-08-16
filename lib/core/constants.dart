import 'package:flutter/foundation.dart';

/// App-wide constants.
abstract final class HConstants {
  static const String appName = 'Hirena Music';

  /// Deezer endpoints (see docs/DEEZER_REFERENCE.md).
  static const String gwLight = 'http://www.deezer.com/ajax/gw-light.php';
  static const String mediaGetUrl = 'https://media.deezer.com/v1/get_url';
  static const String coverBase = 'https://e-cdns-images.dzcdn.net/images';
  static const String cdnsProxyBase = 'https://e-cdns-proxy-';

  /// Chrome/79 UA used by the reference client; some endpoints are picky.
  static const String userAgent =
      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/79.0.3945.130 Safari/537.36';

  /// Quality tiers (numeric format ids, see reference).
  static const int fmtMp3_128 = 1;
  static const int fmtMp3_320 = 3;
  static const int fmtFlac = 9;

  /// Local decrypting proxy host/port range.
  static const String proxyHost = '127.0.0.1';
  static const int proxyPort = 43110;

  /// Skip-before threshold (ms) that counts as a negative signal.
  static const int earlySkipMs = 30000;

  static bool get isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
}
