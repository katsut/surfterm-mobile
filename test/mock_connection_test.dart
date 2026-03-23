import 'package:flutter_test/flutter_test.dart';
import 'package:surfterm_mobile/models/command.dart';
import 'package:surfterm_mobile/protocol.dart';
import 'package:surfterm_mobile/services/connection_service.dart';
import 'package:surfterm_mobile/services/mock_connection_service.dart';

void main() {
  late MockConnectionService svc;

  setUp(() {
    svc = MockConnectionService();
  });

  tearDown(() {
    svc.dispose();
  });

  test('initial state is disconnected', () {
    expect(svc.connectionState, SurftermConnectionState.disconnected);
    expect(svc.isConnected, false);
    expect(svc.sessions, isEmpty);
    expect(svc.discoveredHosts, isEmpty);
  });

  test('discovery cycle', () async {
    final states = <SurftermConnectionState>[];
    svc.addListener(() => states.add(svc.connectionState));

    await svc.startDiscovery();

    expect(states, contains(SurftermConnectionState.discovering));
    expect(svc.connectionState, SurftermConnectionState.disconnected);
  });

  test('connect populates sessions', () async {
    await svc.connect('mock-mac-1:8080');

    expect(svc.isConnected, true);
    expect(svc.sessions.length, 4);
    expect(svc.sessions.any((s) => s.projectName == 'api-server'), true);
    expect(svc.sessions.any((s) => s.state == SessionState.waitingForInput), true);
  });

  test('disconnect clears state', () async {
    await svc.connect('mock-mac-1:8080');
    expect(svc.isConnected, true);

    await svc.disconnect();
    expect(svc.isConnected, false);
    expect(svc.sessions, isEmpty);
  });

  test('sessionById finds existing session', () async {
    await svc.connect('mock-mac-1:8080');

    final session = svc.sessionById('session-001');
    expect(session, isNotNull);
    expect(session!.projectName, 'api-server');
  });

  test('sessionById returns null for missing', () async {
    await svc.connect('mock-mac-1:8080');
    expect(svc.sessionById('nonexistent'), isNull);
  });

  test('terminalLinesFor is per-session', () async {
    await svc.connect('mock-mac-1:8080');

    expect(svc.terminalLinesFor('session-001'), isEmpty);
    expect(svc.terminalLinesFor('session-002'), isEmpty);

    await svc.sendCommand(Command.respond(
      sessionId: 'session-002',
      payload: 'ls',
    ));

    expect(svc.terminalLinesFor('session-002'), isNotEmpty);
    expect(svc.terminalLinesFor('session-001'), isEmpty);
  });

  test('respond command adds to terminal lines', () async {
    await svc.connect('mock-mac-1:8080');

    await svc.sendCommand(Command.respond(
      sessionId: 'session-001',
      payload: 'echo hello',
    ));

    final lines = svc.terminalLinesFor('session-001');
    expect(lines, contains('\$ echo hello'));
    expect(lines, contains('mock: command executed'));
  });

  test('respond to waitingForInput session changes state', () async {
    await svc.connect('mock-mac-1:8080');

    final before = svc.sessionById('session-002');
    expect(before!.state, SessionState.waitingForInput);

    // Don't await — sendCommand triggers a delayed state change
    svc.sendCommand(Command.respond(
      sessionId: 'session-002',
      payload: 'yes',
    ));

    // Give time for the immediate state change
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final during = svc.sessionById('session-002');
    expect(during!.state, SessionState.running);

    // Wait for it to go back to waitingForInput
    await Future<void>.delayed(const Duration(seconds: 3));
    final after = svc.sessionById('session-002');
    expect(after!.state, SessionState.waitingForInput);
  });

  test('terminal simulation adds heartbeat lines', () async {
    await svc.connect('mock-mac-1:8080');

    // Switch to session-001 so heartbeats go there
    await svc.sendCommand(Command.switchSession(sessionId: 'session-001'));

    // Wait for at least one heartbeat (every 3s)
    await Future<void>.delayed(const Duration(seconds: 4));

    final lines = svc.terminalLinesFor('session-001');
    expect(lines.any((l) => l.contains('[mock:session-001] heartbeat')), true);
  });
}
