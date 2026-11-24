import 'package:equatable/equatable.dart';

/// The state of one dashboard card: [SectionLoading], [SectionLoaded] or
/// [SectionError].
///
/// Each card has its own state, so one failing native call shows an error on
/// that card only.
sealed class SectionState<T> extends Equatable {
  const SectionState();

  @override
  List<Object?> get props => const [];
}

/// Data has not been read yet.
final class SectionLoading<T> extends SectionState<T> {
  const SectionLoading();
}

/// Data was read successfully.
final class SectionLoaded<T> extends SectionState<T> {
  const SectionLoaded(this.data);

  final T data;

  @override
  List<Object?> get props => [data];
}

/// Reading failed; [message] is shown on the card.
final class SectionError<T> extends SectionState<T> {
  const SectionError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
