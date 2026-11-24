import 'package:ffi_gen_jni_gen/core/utils/byte_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('toReadableBytes', () {
    test('returns 0 B for zero or negative values', () {
      expect(0.toReadableBytes(), '0 B');
      expect((-5).toReadableBytes(), '0 B');
    });

    test('keeps bytes without decimals', () {
      expect(512.toReadableBytes(), '512 B');
    });

    test('scales to the largest fitting unit', () {
      expect(1536.toReadableBytes(), '1.5 KB');
      expect((3 * 1024 * 1024 * 1024).toReadableBytes(), '3.0 GB');
    });
  });
}
