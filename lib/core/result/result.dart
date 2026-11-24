import '../error/failure.dart';

/// The outcome of a repository call: either [Success] or [Failed].
///
/// Being `sealed`, callers can `switch` over it and the compiler ensures
/// both cases are handled.
sealed class Result<T> {
  const Result();
}

/// A successful result carrying [data].
final class Success<T> extends Result<T> {
  const Success(this.data);

  final T data;
}

/// A failed result carrying the [failure] that describes what went wrong.
final class Failed<T> extends Result<T> {
  const Failed(this.failure);

  final Failure failure;
}
