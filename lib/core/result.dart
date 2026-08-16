/// A small result type so errors are values, not uncaught exceptions, across
/// the gateway and repositories.
sealed class Result<T> {
  const Result();

  R fold<R>(R Function(T value) onOk, R Function(AppError error) onErr) {
    return switch (this) {
      Ok(:final value) => onOk(value),
      Err(:final error) => onErr(error),
    };
  }

  T? get valueOrNull => switch (this) { Ok(:final value) => value, Err() => null };

  bool get isOk => this is Ok<T>;
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.error);
  final AppError error;
}

/// A structured error with an optional user-facing message.
final class AppError {
  const AppError(this.code, {this.message, this.cause});

  final String code;
  final String? message;
  final Object? cause;

  static AppError from(Object e, {String code = 'unknown'}) =>
      AppError(code, message: e.toString(), cause: e);

  @override
  String toString() => 'AppError($code): ${message ?? ''}';
}
