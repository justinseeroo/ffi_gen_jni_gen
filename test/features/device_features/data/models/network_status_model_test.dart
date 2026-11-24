import 'package:ffi_gen_jni_gen/features/device_features/data/models/network_status_model.dart';
import 'package:ffi_gen_jni_gen/features/device_features/domain/entities/network_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NetworkStatusModel.fromReachabilityFlags', () {
    const reachable = NetworkStatusModel.reachabilityFlagReachable;
    const connectionRequired =
        NetworkStatusModel.reachabilityFlagConnectionRequired;
    const wwan = NetworkStatusModel.reachabilityFlagIsWWAN;

    test('no flags is offline', () {
      expect(
        NetworkStatusModel.fromReachabilityFlags(0),
        const NetworkStatusModel.offline(),
      );
    });

    test('cellular flag without reachable is still offline', () {
      expect(
        NetworkStatusModel.fromReachabilityFlags(wwan),
        const NetworkStatusModel.offline(),
      );
    });

    test('reachable without WWAN is Wi-Fi with internet', () {
      expect(
        NetworkStatusModel.fromReachabilityFlags(reachable),
        const NetworkStatusModel(
          connectionType: ConnectionType.wifi,
          hasInternet: true,
        ),
      );
    });

    test('reachable over WWAN is cellular with internet', () {
      expect(
        NetworkStatusModel.fromReachabilityFlags(reachable | wwan),
        const NetworkStatusModel(
          connectionType: ConnectionType.cellular,
          hasInternet: true,
        ),
      );
    });

    test('connection required means no internet yet', () {
      expect(
        NetworkStatusModel.fromReachabilityFlags(
          reachable | connectionRequired,
        ),
        const NetworkStatusModel(
          connectionType: ConnectionType.wifi,
          hasInternet: false,
        ),
      );
    });
  });
}
