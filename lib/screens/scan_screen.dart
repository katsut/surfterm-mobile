import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/connection_provider.dart';
import '../services/connection_service.dart' show SurftermConnectionState, ConnectionService;
import '../theme/catppuccin.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  bool _hasScanned = false;

  @override
  Widget build(BuildContext context) {
    final conn = ref.watch(connectionProvider);

    // Navigate to sessions when connected.
    if (conn.isConnected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/sessions');
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Surfterm')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _StatusCard(state: conn.connectionState, hasScanned: _hasScanned, hostCount: conn.discoveredHosts.length),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: conn.connectionState == SurftermConnectionState.discovering
                    ? null
                    : () async {
                        await conn.startDiscovery();
                        if (mounted) setState(() => _hasScanned = true);
                      },
                icon: const Icon(Icons.wifi_find),
                label: Text(
                  conn.connectionState == SurftermConnectionState.discovering
                      ? 'Scanning...'
                      : 'Scan for Surfterm',
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(child: _HostList(conn: conn)),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final SurftermConnectionState state;
  final bool hasScanned;
  final int hostCount;

  const _StatusCard({required this.state, required this.hasScanned, required this.hostCount});

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = switch (state) {
      SurftermConnectionState.disconnected => (
          Icons.wifi_off,
          hasScanned ? 'Scan complete' : 'Disconnected',
          hasScanned ? CatppuccinMocha.text : CatppuccinMocha.overlay1,
        ),
      SurftermConnectionState.discovering => (
          Icons.wifi_find,
          'Scanning...',
          CatppuccinMocha.blue,
        ),
      SurftermConnectionState.connecting => (
          Icons.wifi,
          'Connecting...',
          CatppuccinMocha.yellow,
        ),
      SurftermConnectionState.connected => (
          Icons.wifi,
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
                if (hasScanned && state == SurftermConnectionState.disconnected)
                  Text(
                    '$hostCount devices found',
                    style: const TextStyle(color: CatppuccinMocha.subtext0, fontSize: 12),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HostList extends StatelessWidget {
  final ConnectionService conn;

  const _HostList({required this.conn});

  @override
  Widget build(BuildContext context) {
    final hosts = conn.discoveredHosts;

    if (hosts.isEmpty) {
      return Center(
        child: Text(
          conn.connectionState == SurftermConnectionState.discovering
              ? 'Looking for nearby devices...'
              : 'Tap "Scan" to find Surfterm',
          style: const TextStyle(color: CatppuccinMocha.subtext0),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      itemCount: hosts.length,
      itemBuilder: (context, index) {
        final host = hosts[index];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.computer, color: CatppuccinMocha.lavender),
            title: Text(host.name, style: const TextStyle(color: CatppuccinMocha.text)),
            subtitle: Text(host.detail, style: const TextStyle(color: CatppuccinMocha.subtext0)),
            trailing: FilledButton(
              onPressed: () => conn.connect(host.id),
              child: const Text('Connect'),
            ),
          ),
        );
      },
    );
  }
}
