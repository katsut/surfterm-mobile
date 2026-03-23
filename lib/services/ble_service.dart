import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/command.dart';
import '../models/session.dart';
import 'chunk_service.dart';

/// Surfterm BLE service UUID (must match Swift helper).
const String kSurftermServiceUuid = '5572f001-7846-4d32-a1a4-5f7a4e3b6c10';

/// Characteristic UUIDs.
const String kSessionListCharUuid = '5572f002-7846-4d32-a1a4-5f7a4e3b6c10';
const String kStateNotifyCharUuid = '5572f002-7846-4d32-a1a4-5f7a4e3b6c10'; // same as session list (notify)
const String kCommandCharUuid = '5572f003-7846-4d32-a1a4-5f7a4e3b6c10';

/// BLE connection state.
enum BleConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
}

/// BLE service for communicating with the Surfterm desktop app.
///
/// Extends [ChangeNotifier] so UI can react to connection and session changes
/// via [Provider].
class BleService extends ChangeNotifier {
  BleConnectionState _connectionState = BleConnectionState.disconnected;
  BluetoothDevice? _connectedDevice;
  List<ScanResult> _scanResults = [];
  List<SessionStatus> _sessions = [];
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>? _stateNotifySubscription;

  // GATT characteristics (discovered on connect).
  BluetoothCharacteristic? _sessionListChar;
  BluetoothCharacteristic? _stateNotifyChar;
  BluetoothCharacteristic? _commandChar;

  final ChunkProtocol _chunkProtocol = const ChunkProtocol(mtu: 512);

  // -- Public getters -------------------------------------------------------

  BleConnectionState get connectionState => _connectionState;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  List<ScanResult> get scanResults => List.unmodifiable(_scanResults);
  List<SessionStatus> get sessions => List.unmodifiable(_sessions);

  bool get isConnected => _connectionState == BleConnectionState.connected;

  // -- Scanning -------------------------------------------------------------

  /// Start scanning for BLE devices advertising the Surfterm service.
  Future<void> scanForDevices() async {
    _connectionState = BleConnectionState.scanning;
    _scanResults = [];
    notifyListeners();

    _scanSubscription?.cancel();
    debugPrint('BLE: Starting scan...');
    debugPrint('BLE: Bluetooth adapter state: ${FlutterBluePlus.adapterStateNow}');

    // Wait for Bluetooth adapter to be ready
    if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
      debugPrint('BLE: Waiting for adapter to turn on...');
      await FlutterBluePlus.adapterState
          .where((s) => s == BluetoothAdapterState.on)
          .first
          .timeout(const Duration(seconds: 10), onTimeout: () {
        debugPrint('BLE: Adapter timeout - Bluetooth may be off');
        return BluetoothAdapterState.off;
      });
      if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
        debugPrint('BLE: Bluetooth is not available');
        _connectionState = BleConnectionState.disconnected;
        notifyListeners();
        return;
      }
      debugPrint('BLE: Adapter is on');
    }

    _scanSubscription = FlutterBluePlus.onScanResults.listen(
      (results) {
        _scanResults = results;
        for (final r in results) {
          final services = r.advertisementData.serviceUuids.map((u) => u.toString()).join(', ');
          final name = r.device.platformName.isNotEmpty ? r.device.platformName : r.advertisementData.advName;
          debugPrint('BLE: Found: "$name" (${r.device.remoteId}) RSSI=${r.rssi} services=[$services]');
        }
        notifyListeners();
      },
      onError: (Object error) {
        debugPrint('BLE scan error: $error');
      },
    );

    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 15),
    );

    debugPrint('BLE: Scan complete. Found ${_scanResults.length} devices.');
    _connectionState = _connectedDevice != null
        ? BleConnectionState.connected
        : BleConnectionState.disconnected;
    notifyListeners();
  }

  /// Stop an active scan.
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    if (_connectionState == BleConnectionState.scanning) {
      _connectionState = BleConnectionState.disconnected;
      notifyListeners();
    }
  }

  // -- Connection -----------------------------------------------------------

  /// Connect to a discovered Surfterm device.
  Future<void> connect(BluetoothDevice device) async {
    _connectionState = BleConnectionState.connecting;
    notifyListeners();

    try {
      await device.connect(timeout: const Duration(seconds: 10));
      _connectedDevice = device;
      _connectionState = BleConnectionState.connected;

      // Listen for disconnection.
      _connectionSubscription?.cancel();
      _connectionSubscription =
          device.connectionState.listen((BluetoothConnectionState state) {
        if (state == BluetoothConnectionState.disconnected) {
          _handleDisconnect();
        }
      });

      await _discoverCharacteristics(device);
      await _subscribeToStateChanges();
      await readSessionList();

      notifyListeners();
    } catch (e) {
      debugPrint('BLE connect error: $e');
      _connectionState = BleConnectionState.disconnected;
      _connectedDevice = null;
      notifyListeners();
    }
  }

  /// Disconnect from the current device.
  Future<void> disconnect() async {
    await _stateNotifySubscription?.cancel();
    _stateNotifySubscription = null;
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;

    try {
      await _connectedDevice?.disconnect();
    } catch (_) {
      // Best effort.
    }

    _handleDisconnect();
  }

  void _handleDisconnect() {
    _connectedDevice = null;
    _sessionListChar = null;
    _stateNotifyChar = null;
    _commandChar = null;
    _sessions = [];
    _connectionState = BleConnectionState.disconnected;
    notifyListeners();
  }

  // -- GATT operations ------------------------------------------------------

  Future<void> _discoverCharacteristics(BluetoothDevice device) async {
    final services = await device.discoverServices();
    for (final service in services) {
      if (service.uuid.toString().toLowerCase() ==
          kSurftermServiceUuid.toLowerCase()) {
        for (final char in service.characteristics) {
          final uuid = char.uuid.toString().toLowerCase();
          if (uuid == kSessionListCharUuid.toLowerCase()) {
            _sessionListChar = char;
          } else if (uuid == kStateNotifyCharUuid.toLowerCase()) {
            _stateNotifyChar = char;
          } else if (uuid == kCommandCharUuid.toLowerCase()) {
            _commandChar = char;
          }
        }
      }
    }
  }

  /// Read the full session list from the desktop.
  Future<void> readSessionList() async {
    final char = _sessionListChar;
    if (char == null) return;

    try {
      final rawBytes = await char.read();
      final json = utf8.decode(rawBytes);
      final list = jsonDecode(json) as List<dynamic>;
      _sessions = list
          .map((e) => SessionStatus.fromJson(e as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to read session list: $e');
    }
  }

  Future<void> _subscribeToStateChanges() async {
    // Session list char has notify — use it for state change subscriptions.
    final char = _sessionListChar;
    if (char == null) return;

    try {
      await char.setNotifyValue(true);
      _stateNotifySubscription = char.lastValueStream.listen((value) {
        try {
          final json = utf8.decode(value);
          final list = jsonDecode(json) as List<dynamic>;
          _sessions = list
              .map((e) => SessionStatus.fromJson(e as Map<String, dynamic>))
              .toList();
          notifyListeners();
        } catch (e) {
          debugPrint('Failed to parse state notification: $e');
        }
      });
    } catch (e) {
      debugPrint('Failed to subscribe to state changes: $e');
    }
  }

  /// Send a command to the desktop via BLE.
  Future<void> sendCommand(BleCommand command) async {
    final char = _commandChar;
    if (char == null) {
      debugPrint('BLE: Command char not found, cannot send');
      return;
    }

    try {
      final bytes = command.toBytes();
      debugPrint('BLE: Sending command: ${command.toJson()}');
      await char.write(bytes.toList(), withoutResponse: false);
      debugPrint('BLE: Command sent successfully');
    } catch (e) {
      debugPrint('BLE: Failed to send command: $e');
    }
  }

  /// Find a session by ID.
  SessionStatus? sessionById(String id) {
    for (final session in _sessions) {
      if (session.id == id) return session;
    }
    return null;
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _stateNotifySubscription?.cancel();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Mock service for development without real BLE hardware
// ---------------------------------------------------------------------------

/// A mock BLE service that returns fake session data.
///
/// Use this during development when no real Surfterm desktop is available.
class MockBleService extends BleService {
  static final List<SessionStatus> _mockSessions = [
    const SessionStatus(
      id: 'session-001',
      projectName: 'api-server',
      state: SessionState.running,
      layer: SessionLayer.background,
    ),
    const SessionStatus(
      id: 'session-002',
      projectName: 'web-frontend',
      state: SessionState.waitingForInput,
      layer: SessionLayer.foreground,
    ),
    const SessionStatus(
      id: 'session-003',
      projectName: 'mobile-app',
      state: SessionState.idle,
      layer: SessionLayer.background,
    ),
    const SessionStatus(
      id: 'session-004',
      projectName: 'infra-terraform',
      state: SessionState.error,
      layer: SessionLayer.foreground,
    ),
    const SessionStatus(
      id: 'session-005',
      projectName: 'shared-lib',
      state: SessionState.running,
      layer: SessionLayer.pinned,
    ),
  ];

  @override
  Future<void> scanForDevices() async {
    _connectionState = BleConnectionState.scanning;
    notifyListeners();

    // Simulate scan delay.
    await Future<void>.delayed(const Duration(seconds: 2));

    _connectionState = BleConnectionState.disconnected;
    notifyListeners();
  }

  @override
  Future<void> connect(BluetoothDevice device) async {
    _connectionState = BleConnectionState.connecting;
    notifyListeners();

    await Future<void>.delayed(const Duration(milliseconds: 500));

    _connectionState = BleConnectionState.connected;
    _sessions = List.of(_mockSessions);
    notifyListeners();
  }

  /// Connect using mock data (no real device needed).
  Future<void> connectMock() async {
    _connectionState = BleConnectionState.connecting;
    notifyListeners();

    await Future<void>.delayed(const Duration(milliseconds: 500));

    _connectionState = BleConnectionState.connected;
    _sessions = List.of(_mockSessions);
    notifyListeners();
  }

  @override
  Future<void> disconnect() async {
    _sessions = [];
    _connectionState = BleConnectionState.disconnected;
    notifyListeners();
  }

  @override
  Future<void> readSessionList() async {
    _sessions = List.of(_mockSessions);
    notifyListeners();
  }

  @override
  Future<void> sendCommand(BleCommand command) async {
    debugPrint('MockBleService: sendCommand(${command.toJson()})');

    // Simulate a state change when responding.
    if (command is RespondCommand) {
      final idx = _sessions.indexWhere((s) => s.id == command.sessionId);
      if (idx >= 0) {
        _sessions[idx] = SessionStatus(
          id: _sessions[idx].id,
          projectName: _sessions[idx].projectName,
          state: SessionState.running,
          layer: SessionLayer.background,
        );
        notifyListeners();
      }
    }
  }
}
