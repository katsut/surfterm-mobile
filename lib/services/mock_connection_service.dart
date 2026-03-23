import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../models/command.dart';
import '../protocol.dart';
import 'connection_service.dart';

/// Mock implementation of [ConnectionService] for testing without hardware.
class MockConnectionService extends ConnectionService {
  SurftermConnectionState _state = SurftermConnectionState.disconnected;
  List<SessionStatus> _sessions = [];
  final Map<String, List<String>> _terminalBySession = {};
  final Map<String, StreamController<Uint8List>> _ptyStreams = {};
  String? _activeSessionId;
  Timer? _outputTimer;

  static const _mockHosts = [
    DiscoveredHost(id: 'mock-mac-1:8080', name: 'Surfterm (MacBook)', detail: 'mock-mac-1:8080'),
    DiscoveredHost(id: 'mock-mac-2:8080', name: 'Surfterm (iMac)', detail: 'mock-mac-2:8080'),
  ];

  static const _mockSessions = [
    SessionStatus(
      id: 'session-001', projectName: 'api-server',
      state: SessionState.running, layer: SessionLayer.background,
    ),
    SessionStatus(
      id: 'session-002', projectName: 'web-frontend',
      state: SessionState.waitingForInput, layer: SessionLayer.foreground,
    ),
    SessionStatus(
      id: 'session-003', projectName: 'mobile-app',
      state: SessionState.idle, layer: SessionLayer.background,
    ),
    SessionStatus(
      id: 'session-004', projectName: 'infra-deploy',
      state: SessionState.error, layer: SessionLayer.pinned,
    ),
  ];

  @override
  SurftermConnectionState get connectionState => _state;
  @override
  List<SessionStatus> get sessions => List.unmodifiable(_sessions);
  @override
  List<DiscoveredHost> get discoveredHosts =>
      _state == SurftermConnectionState.disconnected ? [] : List.of(_mockHosts);

  @override
  Stream<Uint8List> terminalOutputStream(String sessionId) {
    return _getOrCreatePtyStream(sessionId).stream;
  }

  @override
  List<String> terminalLinesFor(String sessionId) {
    return List.unmodifiable(_terminalBySession[sessionId] ?? const []);
  }

  StreamController<Uint8List> _getOrCreatePtyStream(String sessionId) {
    return _ptyStreams.putIfAbsent(
      sessionId,
      () => StreamController<Uint8List>.broadcast(),
    );
  }

  @override
  Future<void> startDiscovery() async {
    _state = SurftermConnectionState.discovering;
    notifyListeners();
    await Future<void>.delayed(const Duration(seconds: 2));
    _state = SurftermConnectionState.disconnected;
    notifyListeners();
  }

  @override
  Future<void> stopDiscovery() async {
    _state = SurftermConnectionState.disconnected;
    notifyListeners();
  }

  @override
  Future<void> connect(String hostId) async {
    _state = SurftermConnectionState.connecting;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 800));
    _state = SurftermConnectionState.connected;
    _sessions = List.of(_mockSessions);
    _activeSessionId = _sessions.first.id;
    _startTerminalSimulation();
    notifyListeners();
  }

  @override
  Future<void> disconnect() async {
    _outputTimer?.cancel();
    _outputTimer = null;
    _sessions = [];
    _terminalBySession.clear();
    for (final controller in _ptyStreams.values) {
      controller.close();
    }
    _ptyStreams.clear();
    _activeSessionId = null;
    _state = SurftermConnectionState.disconnected;
    notifyListeners();
  }

  @override
  Future<void> sendCommand(Command command) async {
    debugPrint('Mock: sendCommand(${command.toJson()})');

    if (command is SwitchSessionCommand) {
      _activeSessionId = command.sessionId;
    }

    if (command is RespondCommand) {
      final lines = _terminalBySession.putIfAbsent(command.sessionId, () => []);
      lines.add('\$ ${command.payload}');
      lines.add('mock: command executed');
      notifyListeners();

      final idx = _sessions.indexWhere((s) => s.id == command.sessionId);
      if (idx >= 0 && _sessions[idx].state == SessionState.waitingForInput) {
        _sessions[idx] = SessionStatus(
          id: _sessions[idx].id, projectName: _sessions[idx].projectName,
          state: SessionState.running, layer: _sessions[idx].layer,
        );
        notifyListeners();

        await Future<void>.delayed(const Duration(seconds: 2));
        if (idx < _sessions.length) {
          _sessions[idx] = SessionStatus(
            id: _sessions[idx].id, projectName: _sessions[idx].projectName,
            state: SessionState.waitingForInput, layer: _sessions[idx].layer,
          );
          notifyListeners();
        }
      }
    }
  }

  @override
  Future<void> refreshSessions() async {
    if (_state == SurftermConnectionState.connected) {
      _sessions = List.of(_mockSessions);
      notifyListeners();
    }
  }

  void _startTerminalSimulation() {
    var tick = 0;
    _outputTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      tick++;
      final sid = _activeSessionId;
      if (sid != null) {
        final lines = _terminalBySession.putIfAbsent(sid, () => []);
        lines.add('[mock:$sid] heartbeat #$tick — ${DateTime.now().toIso8601String()}');
        if (lines.length > 200) {
          lines.removeRange(0, lines.length - 200);
        }
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _outputTimer?.cancel();
    for (final controller in _ptyStreams.values) {
      controller.close();
    }
    super.dispose();
  }
}
