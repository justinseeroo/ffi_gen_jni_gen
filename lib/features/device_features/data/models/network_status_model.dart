import '../../../../jni/android_bindings.g.dart';
import '../../domain/entities/network_status.dart';

/// Data-layer version of [NetworkStatus] built from `NetworkCapabilities`.
class NetworkStatusModel extends NetworkStatus {
  const NetworkStatusModel({
    required super.connectionType,
    required super.hasInternet,
  });

  const NetworkStatusModel.offline() : super.offline();

  /// Maps the active network's capabilities to a [ConnectionType].
  /// A `null` [capabilities] means there is no active network.
  factory NetworkStatusModel.fromNative(NetworkCapabilities? capabilities) {
    if (capabilities == null) return const NetworkStatusModel.offline();

    return NetworkStatusModel(
      connectionType: _resolveConnectionType(capabilities),
      hasInternet: capabilities.hasCapability(
        NetworkCapabilities.NET_CAPABILITY_INTERNET,
      ),
    );
  }

  /// Checked in priority order: a device on Wi-Fi and mobile data at once is
  /// reported as Wi-Fi, matching what Android routes traffic through.
  static ConnectionType _resolveConnectionType(NetworkCapabilities caps) {
    if (caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) {
      return ConnectionType.wifi;
    }
    if (caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)) {
      return ConnectionType.cellular;
    }
    if (caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET)) {
      return ConnectionType.ethernet;
    }
    return ConnectionType.other;
  }

  /// Maps `SCNetworkReachabilityFlags` for the default route (`0.0.0.0`) to a
  /// [NetworkStatusModel].
  ///
  /// iOS only distinguishes cellular (`IsWWAN`) from everything else, and on
  /// an iPhone or iPad everything else is Wi-Fi.
  factory NetworkStatusModel.fromReachabilityFlags(int flags) {
    final reachable = flags & reachabilityFlagReachable != 0;
    final needsConnection = flags & reachabilityFlagConnectionRequired != 0;
    if (!reachable) return const NetworkStatusModel.offline();

    return NetworkStatusModel(
      connectionType: flags & reachabilityFlagIsWWAN != 0
          ? ConnectionType.cellular
          : ConnectionType.wifi,
      hasInternet: !needsConnection,
    );
  }

  /// `kSCNetworkReachabilityFlagsReachable`.
  static const reachabilityFlagReachable = 1 << 1;

  /// `kSCNetworkReachabilityFlagsConnectionRequired`.
  static const reachabilityFlagConnectionRequired = 1 << 2;

  /// `kSCNetworkReachabilityFlagsIsWWAN`.
  static const reachabilityFlagIsWWAN = 1 << 18;
}
