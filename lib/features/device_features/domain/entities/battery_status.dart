import 'package:equatable/equatable.dart';

/// Current battery charge and charging state.
class BatteryStatus extends Equatable {
  const BatteryStatus({required this.level, required this.isCharging});

  /// Charge percentage, 0–100.
  final int level;
  final bool isCharging;

  /// [level] as a 0.0–1.0 value, ready for progress indicators.
  double get levelRatio => (level / 100).clamp(0, 1).toDouble();

  @override
  List<Object?> get props => [level, isCharging];
}
