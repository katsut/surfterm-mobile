import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bonsoir/bonsoir.dart';
import 'package:bonsoir_platform_interface/bonsoir_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/command.dart';
import '../protocol.dart' as proto;
import 'connection_service.dart';

/// WebSocket implementation of [ConnectionService].
class WsConnectionService extends ConnectionService {
  SurftermConnectionState _state = SurftermConnectionState.disconnected;
  List<proto.SessionStatus> _sessions = [];
  final Map<String, StreamController<Uint8List>> _ptyStreams = {};
  final Map<String, List<String>> _terminalBySession = {};
  final List<DiscoveredHost> _hosts = [];

  BonsoirDiscovery? _discovery;
  WebSocketChannel? _channel;
  StreamSubscription? _wsSub;

  @override
  SurftermConnectionState get connectionState => _state;
  @override
  List<proto.SessionStatus> get sessions => List.unmodifiable(_sessions);
  @override
  List<DiscoveredHost> get discoveredHosts => List.unmodifiable(_hosts);

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
    if (_state == SurftermConnectionState.discovering) return;

    _state = SurftermConnectionState.discovering;
    _hosts.clear();
    notifyListeners();

    _discovery = BonsoirDiscovery(type: proto.bonjourServiceType);
    await _discovery!.initialize();

    _discovery!.eventStream!.listen((event) {
      if (event is BonsoirDiscoveryServiceResolvedEvent) {
        final service = event.service;
        final host = service.host ?? service.name;
        final port = service.port;
        final id = '$host:$port';

        if (!_hosts.any((h) => h.id == id)) {
          _hosts.add(DiscoveredHost(
            id: id,
            name: service.name,
            detail: '$host:$port',
          ));
          notifyListeners();
        }
      }
    });

    await _discovery!.start();

    // Allow 5 seconds for discovery
    await Future<void>.delayed(const Duration(seconds: 5));
    await _discovery?.stop();

    if (_state == SurftermConnectionState.discovering) {
      _state = SurftermConnectionState.disconnected;
      notifyListeners();
    }
  }

  @override
  Future<void> stopDiscovery() async {
    await _discovery?.stop();
    _discovery = null;
    if (_state == SurftermConnectionState.discovering) {
      _state = SurftermConnectionState.disconnected;
      notifyListeners();
    }
  }

  @override
  Future<void> connect(String hostId) async {
    _state = SurftermConnectionState.connecting;
    notifyListeners();

    try {
      final uri = Uri.parse('ws://$hostId');
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready;

      _state = SurftermConnectionState.connected;
      notifyListeners();

      _wsSub = _channel!.stream.listen(
        (data) => _handleMessage(data as String),
        onDone: () => _handleDisconnect(),
        onError: (Object e) {
          debugPrint('WebSocket error: $e');
          _handleDisconnect();
        },
      );
    } catch (e) {
      debugPrint('WebSocket connect error: $e');
      _state = SurftermConnectionState.disconnected;
      _channel = null;
      notifyListeners();
    }
  }

  @override
  Future<void> disconnect() async {
    await _wsSub?.cancel();
    _wsSub = null;
    await _channel?.sink.close();
    _channel = null;
    _handleDisconnect();
  }

  @override
  Future<void> sendCommand(Command command) async {
    _channel?.sink.add(command.toJsonString());
  }

  @override
  Future<void> refreshSessions() async {
    // Sessions are pushed via WebSocket; no polling needed.
  }

  void _handleMessage(String text) {
    try {
      final json = jsonDecode(text) as Map<String, dynamic>;
      final type = json['type'] as String;

      switch (type) {
        case 'sessions':
          final data = json['data'] as List<dynamic>;
          _sessions = data
              .map((e) => proto.SessionStatus.fromJson(e as Map<String, dynamic>))
              .toList();
          notifyListeners();

        case 'pty_output':
          final sessionId = json['session_id'] as String;
          final b64 = json['data'] as String;
          final bytes = base64Decode(b64);
          _getOrCreatePtyStream(sessionId).add(Uint8List.fromList(bytes));

        case 'session_state_changed':
          final sessionId = json['session_id'] as String;
          final newState = proto.SessionState.fromWire(json['state'] as String);
          final idx = _sessions.indexWhere((s) => s.id == sessionId);
          if (idx >= 0) {
            _sessions[idx] = proto.SessionStatus(
              id: _sessions[idx].id,
              projectName: _sessions[idx].projectName,
              state: newState,
              layer: _sessions[idx].layer,
            );
            notifyListeners();
          }
      }
    } catch (e) {
      debugPrint('WebSocket message parse error: $e');
    }
  }

  void _handleDisconnect() {
    _channel = null;
    _sessions = [];
    for (final controller in _ptyStreams.values) {
      controller.close();
    }
    _ptyStreams.clear();
    _terminalBySession.clear();
    _state = SurftermConnectionState.disconnected;
    notifyListeners();
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _channel?.sink.close();
    _discovery?.stop();
    for (final controller in _ptyStreams.values) {
      controller.close();
    }
    super.dispose();
  }
}
