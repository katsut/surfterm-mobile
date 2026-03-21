import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/ble_service.dart';
import '../theme/catppuccin.dart';
import 'session_list_screen.dart';

/// BLE device scanning screen.
class ScanScreen extends StatelessWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Surfterm')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Status
            _buildStatusCard(ble),
            const SizedBox(height: 16),

            // Scan / Mock connect buttons
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: ble.connectionState ==
                            BleConnectionState.scanning
                        ? null
                        : () => ble.scanForDevices(),
                    icon: const Icon(Icons.bluetooth_searching),
                    label: Text(
                      ble.connectionState == BleConnectionState.scanning
                          ? 'Scanning...'
                          : 'Scan for Surfterm',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (ble is MockBleService)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        await ble.connectMock();
                        if (context.mounted) {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute<void>(
                              builder: (_) => const SessionListScreen(),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.bug_report),
                      label: const Text('Mock Connect'),
                      style: FilledButton.styleFrom(
                        backgroundColor: CatppuccinMocha.teal,
                      ),
                    ),
                  ),
              ],
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
          'Disconnected',
          CatppuccinMocha.overlay1,
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
            Text(
              label,
              style: TextStyle(color: color, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanResults(BuildContext context, BleService ble) {
    if (ble.scanResults.isEmpty) {
      return Center(
        child: Text(
          ble.connectionState == BleConnectionState.scanning
              ? 'Looking for Surfterm devices...'
              : 'Tap "Scan" to find Surfterm devices',
          style: const TextStyle(color: CatppuccinMocha.subtext0),
        ),
      );
    }

    return ListView.builder(
      itemCount: ble.scanResults.length,
      itemBuilder: (context, index) {
        final result = ble.scanResults[index];
        final device = result.device;
        final name = device.platformName.isNotEmpty
            ? device.platformName
            : 'Unknown Device';

        return Card(
          child: ListTile(
            leading:
                const Icon(Icons.computer, color: CatppuccinMocha.lavender),
            title: Text(name, style: const TextStyle(color: CatppuccinMocha.text)),
            subtitle: Text(
              device.remoteId.toString(),
              style: const TextStyle(color: CatppuccinMocha.subtext0),
            ),
            trailing: FilledButton(
              onPressed: () async {
                await ble.connect(device);
                if (context.mounted && ble.isConnected) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) => const SessionListScreen(),
                    ),
                  );
                }
              },
              child: const Text('Connect'),
            ),
          ),
        );
      },
    );
  }
}
