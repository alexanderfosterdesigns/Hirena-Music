import 'package:logging/logging.dart';

/// Central logger. Set `HLog.level` at startup to control verbosity.
abstract final class HLog {
  static final Logger _logger = Logger('hirena');

  static Level level = Level.INFO;

  static void init() {
    Logger.root.level = level;
    Logger.root.onRecord.listen((r) {
      // Intentionally avoid `print` in release; here we route to the VM log.
      // ignore: avoid_print
      print('${r.time} [${r.level.name}] ${r.loggerName}: ${r.message}');
    });
  }

  static void d(Object msg) => _logger.fine(msg);
  static void i(Object msg) => _logger.info(msg);
  static void w(Object msg) => _logger.warning(msg);
  static void e(Object msg, [Object? error, StackTrace? st]) =>
      _logger.severe(msg, error, st);
}
