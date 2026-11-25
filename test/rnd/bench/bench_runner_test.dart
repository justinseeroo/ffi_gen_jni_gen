import 'package:ffi_gen_jni_gen/rnd/bench/bench_runner.dart';
import 'package:ffi_gen_jni_gen/rnd/exp01_call_overhead.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('median', () {
    test('odd count picks the middle value', () {
      expect(median([5, 1, 3]), 3);
    });

    test('even count averages the two middle values', () {
      expect(median([4, 1, 3, 2]), 2); // (2 + 3) ~/ 2
    });

    test('empty list throws', () {
      expect(() => median([]), throwsArgumentError);
    });
  });

  group('ticksToNanoseconds', () {
    test('long runs on a nanosecond clock do not overflow', () {
      // 35 s at 1 GHz: the naive ticks * 1e9 would overflow int64.
      expect(ticksToNanoseconds(35000000000, 1000000000), 35000000000);
    });

    test('microsecond clock converts exactly', () {
      expect(ticksToNanoseconds(1500001, 1000000), 1500001000);
    });

    test('sub-tick remainder is kept', () {
      expect(ticksToNanoseconds(7, 3), 2333333333);
    });
  });

  group('BenchRunner', () {
    const runner = BenchRunner(runs: 3, warmupCalls: 2);

    test('measureSync times every run and counts mismatches', () {
      var invocations = 0;
      final result = runner.measureSync(
        approach: 'fake',
        operation: 'op',
        calls: 10,
        call: (i) {
          invocations++;
          return i != 0; // index 0 "fails" once per run
        },
      );
      expect(invocations, 2 + 3 * 10);
      expect(result.runsNs, hasLength(3));
      expect(result.mismatches, 3);
      expect(result.toJson()['calls'], 10);
    });

    test('measureAsync awaits each call', () async {
      var inFlight = 0;
      var maxInFlight = 0;
      final result = await runner.measureAsync(
        approach: 'fake',
        operation: 'op',
        calls: 5,
        call: (_) async {
          inFlight++;
          if (inFlight > maxInFlight) maxInFlight = inFlight;
          await Future<void>.delayed(Duration.zero);
          inFlight--;
          return true;
        },
      );
      expect(maxInFlight, 1);
      expect(result.mismatches, 0);
    });
  });

  group('describe', () {
    test('escapes NUL, non-ASCII and lone surrogates', () {
      expect(describe('a\u0000b'), r'"a\u0000b"');
      expect(describe('x\uD800y'), r'"x\ud800y"');
      expect(describe(String.fromCharCode(0xF1)), r'"\u00f1"');
    });

    test('summarises long strings', () {
      expect(describeValue('a' * 100), startsWith('String(length: 100'));
    });
  });
}
