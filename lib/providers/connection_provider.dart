import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/connection_service.dart';
import '../services/mock_connection_service.dart';
import '../services/ws_connection_service.dart';

/// Whether to use mock service (set before app starts).
bool useMockConnection = false;

/// The connection service provider.
final connectionProvider = ChangeNotifierProvider<ConnectionService>((ref) {
  if (useMockConnection) {
    return MockConnectionService();
  }
  return WsConnectionService();
});
