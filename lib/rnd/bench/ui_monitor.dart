import 'dart:async';

import 'package:flutter/scheduler.dart';

/// How an operation affected the UI thread.
class UiImpact<T> {
  const UiImpact({
    required this.result,
    required this.error,
    required this.wallMs,
    required this.maxFrameGapMs,
    required this.framesDuring,
  });

  final T? result;
  final Object? error;

  /// Wall time from starting the operation to getting its result.
  final double wallMs;

  /// Longest time between two consecutive frames around the operation. At
  /// 60 Hz an unblocked UI shows ~16.7 ms (8.3 ms at 120 Hz); a value near
  /// [wallMs] means the UI was frozen for the whole operation.
  final double maxFrameGapMs;

  /// Frames produced while the operation was running.
  final int framesDuring;

  Map<String, Object?> toJson() => {
    'wall_ms': double.parse(wallMs.toStringAsFixed(1)),
    'max_frame_gap_ms': double.parse(maxFrameGapMs.toStringAsFixed(1)),
    'frames_during': framesDuring,
    if (error != null) 'error': '${error.runtimeType}: $error',
  };
}

/// Detects UI-thread stalls with a [Ticker]: it requests a frame on every
/// vsync, so its timestamps stop while the UI thread is blocked.
class UiMonitor {
  UiMonitor() {
    _ticker = Ticker(_onTick)..start();
  }

  final _clock = Stopwatch()..start();
  final _ticksUs = <int>[];
  late final Ticker _ticker;

  void _onTick(Duration _) {
    _ticksUs.add(_clock.elapsedMicroseconds);
    if (_ticksUs.length > 20000) _ticksUs.removeRange(0, 10000);
  }

  /// Median frame interval over the most recent frames (the display's
  /// refresh period when the UI is idle).
  double get recentFrameIntervalMs {
    final n = _ticksUs.length;
    if (n < 3) return double.nan;
    final from = n > 121 ? n - 121 : 0;
    final gaps = [
      for (var i = from + 1; i < n; i++) _ticksUs[i] - _ticksUs[i - 1],
    ]..sort();
    return gaps[gaps.length ~/ 2] / 1000;
  }

  Future<UiImpact<T>> measure<T>(FutureOr<T> Function() operation) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final start = _clock.elapsedMicroseconds;
    T? result;
    Object? error;
    try {
      result = await operation();
    } catch (e) {
      error = e;
    }
    final end = _clock.elapsedMicroseconds;
    // Let frames resume so the gap that spans the end is captured.
    await Future<void>.delayed(const Duration(milliseconds: 150));

    final before = _ticksUs.lastWhere((t) => t <= start, orElse: () => start);
    final after = _ticksUs.firstWhere((t) => t >= end, orElse: () => end);
    final during = [for (final t in _ticksUs) if (t > start && t < end) t];
    final window = [before, ...during, after];
    var maxGap = 0;
    for (var i = 1; i < window.length; i++) {
      final gap = window[i] - window[i - 1];
      if (gap > maxGap) maxGap = gap;
    }
    return UiImpact(
      result: result,
      error: error,
      wallMs: (end - start) / 1000,
      maxFrameGapMs: maxGap / 1000,
      framesDuring: during.length,
    );
  }

  void dispose() => _ticker.dispose();
}
