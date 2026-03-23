import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:surfterm_mobile/models/command.dart';

void main() {
  group('Command serialization', () {
    test('respond command toJson', () {
      final cmd = Command.respond(
        sessionId: 'sess-1',
        payload: 'hello world',
      );
      final json = cmd.toJson();
      expect(json['type'], 'respond');
      expect(json['session_id'], 'sess-1');
      expect(json['payload'], 'hello world');
    });

    test('switch_session command toJson', () {
      final cmd = Command.switchSession(sessionId: 'sess-2');
      final json = cmd.toJson();
      expect(json['type'], 'switch_session');
      expect(json['session_id'], 'sess-2');
    });

    test('pin_session command toJson', () {
      final cmd = Command.pinSession(sessionId: 'sess-3');
      final json = cmd.toJson();
      expect(json['type'], 'pin_session');
      expect(json['session_id'], 'sess-3');
    });

    test('pty_input command toJson encodes data as base64', () {
      final cmd = Command.ptyInput(
        sessionId: 'sess-1',
        data: Uint8List.fromList([0x6c, 0x73, 0x0a]), // "ls\n"
      );
      final json = cmd.toJson();
      expect(json['type'], 'pty_input');
      expect(json['session_id'], 'sess-1');
      expect(json['data'], base64Encode([0x6c, 0x73, 0x0a]));
    });

    test('resize command toJson', () {
      final cmd = Command.resize(
        sessionId: 'sess-1',
        cols: 120,
        rows: 40,
      );
      final json = cmd.toJson();
      expect(json['type'], 'resize');
      expect(json['session_id'], 'sess-1');
      expect(json['cols'], 120);
      expect(json['rows'], 40);
    });

    test('toJsonString produces valid JSON', () {
      final cmd = Command.respond(
        sessionId: 'test-id',
        payload: 'ls -la',
      );
      final jsonStr = cmd.toJsonString();
      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
      expect(parsed['type'], 'respond');
      expect(parsed['session_id'], 'test-id');
      expect(parsed['payload'], 'ls -la');
    });

    test('toJsonString handles special characters', () {
      final cmd = Command.respond(
        sessionId: 'id',
        payload: 'echo "hello\nworld"',
      );
      final jsonStr = cmd.toJsonString();
      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
      expect(parsed['payload'], 'echo "hello\nworld"');
    });
  });
}
