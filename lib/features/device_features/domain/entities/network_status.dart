import 'package:equatable/equatable.dart';

/// The transport the active network uses, with a display [label].
enum ConnectionType {
  wifi('Wi-Fi'),
  cellular('Mobile data'),
  ethernet('Ethernet'),
  other('Other'),
  none('Offline');

  const ConnectionType(this.label);

  final String label;
}

/// Current connectivity of the device (from `ConnectivityManager`).
class NetworkStatus extends Equatable {
  const NetworkStatus({
    required this.connectionType,
    required this.hasInternet,
  });

  /// No active network.
  const NetworkStatus.offline()
    : connectionType = ConnectionType.none,
      hasInternet = false;

  final ConnectionType connectionType;

  /// Whether the network claims internet capability. Being connected does
  /// not always mean internet is reachable (e.g. Wi-Fi without uplink).
  final bool hasInternet;

  bool get isConnected => connectionType != ConnectionType.none;

  @override
  List<Object?> get props => [connectionType, hasInternet];
}
