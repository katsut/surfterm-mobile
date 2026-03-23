import 'dart:convert';
import 'dart:typed_data';

/// Commands sent from mobile to desktop over WebSocket.
sealed class Command {
  const Command();

  factory Command.respond({
    required String sessionId,
    required String payload,
  }) = RespondCommand;

  factory Command.switchSession({required String sessionId}) =
      SwitchSessionCommand;

  factory Command.pinSession({required String sessionId}) =
      PinSessionCommand;

  factory Command.ptyInput({
    required String sessionId,
    required Uint8List data,
  }) = PtyInputCommand;

  factory Command.resize({
    required String sessionId,
    required int cols,
    required int rows,
  }) = ResizeCommand;

  Map<String, dynamic> toJson();

  String toJsonString() => jsonEncode(toJson());
}

final class RespondCommand extends Command {
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

final class SwitchSessionCommand extends Command {
  final String sessionId;
  const SwitchSessionCommand({required this.sessionId});

  @override
  Map<String, dynamic> toJson() => {
        'type': 'switch_session',
        'session_id': sessionId,
      };
}

final class PinSessionCommand extends Command {
  final String sessionId;
  const PinSessionCommand({required this.sessionId});

  @override
  Map<String, dynamic> toJson() => {
        'type': 'pin_session',
        'session_id': sessionId,
      };
}

final class PtyInputCommand extends Command {
  final String sessionId;
  final Uint8List data;
  const PtyInputCommand({required this.sessionId, required this.data});

  @override
  Map<String, dynamic> toJson() => {
        'type': 'pty_input',
        'session_id': sessionId,
        'data': base64Encode(data),
      };
}

final class ResizeCommand extends Command {
  final String sessionId;
  final int cols;
  final int rows;
  const ResizeCommand({
    required this.sessionId,
    required this.cols,
    required this.rows,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'resize',
        'session_id': sessionId,
        'cols': cols,
        'rows': rows,
      };
}
