import 'dart:convert';
import 'dart:typed_data';

/// BLE command model matching Rust `BleCommand` enum.
///
/// Commands are serialized as JSON for transmission over BLE:
/// ```json
/// {"type": "respond", "session_id": "abc", "payload": "yes"}
/// {"type": "switch_session", "session_id": "xyz"}
/// {"type": "pin_session", "session_id": "s1"}
/// ```
sealed class BleCommand {
  const BleCommand();

  /// Send a response to a session waiting for input.
  factory BleCommand.respond({
    required String sessionId,
    required String payload,
  }) = RespondCommand;

  /// Switch the active session.
  factory BleCommand.switchSession({required String sessionId}) =
      SwitchSessionCommand;

  /// Pin/unpin a session to the foreground layer.
  factory BleCommand.pinSession({required String sessionId}) =
      PinSessionCommand;

  /// Serialize to JSON map.
  Map<String, dynamic> toJson();

  /// Serialize to UTF-8 bytes for BLE transmission.
  Uint8List toBytes() {
    return Uint8List.fromList(utf8.encode(jsonEncode(toJson())));
  }
}

final class RespondCommand extends BleCommand {
  final String sessionId;
  final String payload;

  const RespondCommand({required this.sessionId, required this.payload});

  @override
  Map<String, dynamic> toJson() => {
        'type': 'respond',
        'session_id': sessionId,
        'payload': payload,
      };
}

final class SwitchSessionCommand extends BleCommand {
  final String sessionId;

  const SwitchSessionCommand({required this.sessionId});

  @override
  Map<String, dynamic> toJson() => {
        'type': 'switch_session',
        'session_id': sessionId,
      };
}

final class PinSessionCommand extends BleCommand {
  final String sessionId;

  const PinSessionCommand({required this.sessionId});

  @override
  Map<String, dynamic> toJson() => {
        'type': 'pin_session',
        'session_id': sessionId,
      };
}
