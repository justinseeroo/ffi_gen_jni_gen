import 'package:equatable/equatable.dart';

/// A user-facing error returned by repositories instead of throwing.
///
/// The presentation layer only ever sees [Failure]s, never raw native
/// exceptions.
class Failure extends Equatable {
  const Failure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
