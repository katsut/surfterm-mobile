import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../models/command.dart';
import '../protocol.dart';

enum SurftermConnectionState {
  disconnected,
  discovering,
  connecting,
  connected,
}

class DiscoveredHost {
  final String id;
  final String name;
  final String detail;
  const DiscoveredHost({required this.id, required this.name, required this.detail});
}

/// Abstract connection to a Surfterm desktop instance.
abstract class ConnectionService extends ChangeNotifier {
  SurftermConnectionState get connectionState;
  List<SessionStatus> get sessions;
  List<DiscoveredHost> get discoveredHosts;
  bool get isConnected => connectionState == SurftermConnectionState.connected;

  /// Raw PTY output stream for a specific session (base64-decoded bytes).
  Stream<Uint8List> terminalOutputStream(String sessionId);

  /// Terminal output lines for a specific session (for non-xterm views).
  List<String> terminalLinesFor(String sessionId);

  Future<void> startDiscovery();
  Future<void> stopDiscovery();
  Future<void> connect(String hostId);
  Future<void> disconnect();
  Future<void> sendCommand(Command command);
  Future<void> refreshSessions();

  SessionStatus? sessionById(String id) {
    for (final s in sessions) {
      if (s.id == id) return s;
    }
    return null;
  }
}
