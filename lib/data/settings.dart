import 'package:shared_preferences/shared_preferences.dart';

/// App settings (quality, crossfade, shuffle default). The ARL is NOT stored
/// here — see [ArlVault].
final class AppSettings {
  AppSettings._(this._prefs);

  final SharedPreferences _prefs;

  static Future<AppSettings> load() async =>
      AppSettings._(await SharedPreferences.getInstance());

  static const _kQuality = 'quality';
  static const _kCrossfade = 'crossfade_ms';
  static const _kShuffle = 'default_shuffle';
  static const _kAutomix = 'automix';

  int get quality => _prefs.getInt(_kQuality) ?? 3;
  Future<void> setQuality(int v) => _prefs.setInt(_kQuality, v);

  int get crossfadeMs => _prefs.getInt(_kCrossfade) ?? 4000;
  Future<void> setCrossfadeMs(int v) => _prefs.setInt(_kCrossfade, v);

  String get defaultShuffle => _prefs.getString(_kShuffle) ?? 'sequential';
  Future<void> setDefaultShuffle(String v) => _prefs.setString(_kShuffle, v);

  bool get automix => _prefs.getBool(_kAutomix) ?? true;
  Future<void> setAutomix(bool v) => _prefs.setBool(_kAutomix, v);
}
