import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/ble_service.dart';
import '../theme/catppuccin.dart';
import 'session_list_screen.dart';

/// BLE device scanning screen.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _hasScanned = false;

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleService>();

    // Navigate to session list when connected
    if (ble.isConnected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => const SessionListScreen(),
            ),
          );
        }
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Surfterm')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Status
            _buildStatusCard(ble),
            const SizedBox(height: 16),

            // Scan button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: ble.connectionState == BleConnectionState.scanning
                    ? null
                    : () async {
                        await ble.scanForDevices();
                        if (mounted) setState(() => _hasScanned = true);
                      },
                icon: const Icon(Icons.bluetooth_searching),
                label: Text(
                  ble.connectionState == BleConnectionState.scanning
                      ? 'Scanning...'
                      : 'Scan for Surfterm',
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Scan results
            Expanded(child: _buildScanResults(context, ble)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(BleService ble) {
    final (icon, label, color) = switch (ble.connectionState) {
      BleConnectionState.disconnected => (
          Icons.bluetooth_disabled,
          _hasScanned ? 'Scan complete' : 'Disconnected',
          _hasScanned ? CatppuccinMocha.text : CatppuccinMocha.overlay1,
        ),
      BleConnectionState.scanning => (
          Icons.bluetooth_searching,
          'Scanning...',
          CatppuccinMocha.blue,
        ),
      BleConnectionState.connecting => (
          Icons.bluetooth_connected,
          'Connecting...',
          CatppuccinMocha.yellow,
        ),
      BleConnectionState.connected => (
          Icons.bluetooth_connected,
          'Connected',
          CatppuccinMocha.green,
        ),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: color, fontSize: 16)),
                if (_hasScanned && ble.connectionState == BleConnectionState.disconnected)
                  Text(
                    '${ble.scanResults.length} devices found',
                    style: const TextStyle(color: CatppuccinMocha.subtext0, fontSize: 12),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanResults(BuildContext context, BleService ble) {
    // Only show devices with a name or strong signal (likely nearby)
    final filtered = ble.scanResults.where((r) {
      final hasName = r.device.platformName.isNotEmpty ||
          r.advertisementData.advName.isNotEmpty;
      return hasName || r.rssi > -50;
    }).toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          ble.connectionState == BleConnectionState.scanning
              ? 'Looking for nearby devices...'
              : _hasScanned
                  ? 'No nearby devices found.\nMake sure BLE is ON on Mac (Cmd+Shift+B)'
                  : 'Tap "Scan" to find Surfterm',
          style: const TextStyle(color: CatppuccinMocha.subtext0),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final result = filtered[index];
        final device = result.device;
        final name = device.platformName.isNotEmpty
            ? device.platformName
            : result.advertisementData.advName.isNotEmpty
                ? result.advertisementData.advName
                : 'Unknown Device';

        return Card(
          child: ListTile(
            leading: const Icon(Icons.computer, color: CatppuccinMocha.lavender),
            title: Text(name, style: const TextStyle(color: CatppuccinMocha.text)),
            subtitle: Text(
              'RSSI: ${result.rssi} dBm',
              style: const TextStyle(color: CatppuccinMocha.subtext0),
            ),
            trailing: FilledButton(
              onPressed: () async {
                await ble.connect(device);
              },
              child: const Text('Connect'),
            ),
          ),
        );
      },
    );
  }
}
