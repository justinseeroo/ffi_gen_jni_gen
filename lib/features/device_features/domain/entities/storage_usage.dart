import 'capacity_usage.dart';

/// Internal storage usage of the volume holding app data (`StatFs` on
/// Android, `NSURL` volume capacity on iOS).
class StorageUsage extends CapacityUsage {
  const StorageUsage({
    required super.totalBytes,
    required super.availableBytes,
  });
}
