import 'package:ffi_gen_jni_gen/features/device_features/domain/entities/storage_usage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('computes used bytes and ratio', () {
    const usage = StorageUsage(totalBytes: 1000, availableBytes: 250);

    expect(usage.usedBytes, 750);
    expect(usage.usedRatio, 0.75);
  });

  test('ratio is zero when total is unknown', () {
    const usage = StorageUsage(totalBytes: 0, availableBytes: 0);

    expect(usage.usedRatio, 0);
  });
}
