import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/command.dart';
import '../models/session.dart';
import '../services/ble_service.dart';
import '../theme/catppuccin.dart';
import '../widgets/session_card.dart';
import 'scan_screen.dart';
import 'session_detail_screen.dart';

/// Displays all sessions grouped by layer.
class SessionListScreen extends StatelessWidget {
  const SessionListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleService>();

    if (!ble.isConnected) {
      // Disconnected -- go back to scan.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(builder: (_) => const ScanScreen()),
          );
        }
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final sessions = ble.sessions;
    final pinned =
        sessions.where((s) => s.layer == SessionLayer.pinned).toList();
    final foreground =
        sessions.where((s) => s.layer == SessionLayer.foreground).toList();
    final background =
        sessions.where((s) => s.layer == SessionLayer.background).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sessions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bluetooth_disabled),
            tooltip: 'Disconnect',
            onPressed: () async {
              await ble.disconnect();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: CatppuccinMocha.mauve,
        onRefresh: () => ble.readSessionList(),
        child: sessions.isEmpty
            ? const Center(
                child: Text(
                  'No active sessions',
                  style: TextStyle(color: CatppuccinMocha.subtext0),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (pinned.isNotEmpty) ...[
                    _sectionHeader('Pinned'),
                    ...pinned.map(
                      (s) => _sessionCard(context, ble, s),
                    ),
                  ],
                  if (foreground.isNotEmpty) ...[
                    _sectionHeader('Foreground'),
                    ...foreground.map(
                      (s) => _sessionCard(context, ble, s),
                    ),
                  ],
                  if (background.isNotEmpty) ...[
                    _sectionHeader('Background'),
                    ...background.map(
                      (s) => _sessionCard(context, ble, s),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 12, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: CatppuccinMocha.subtext0,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _sessionCard(
    BuildContext context,
    BleService ble,
    SessionStatus session,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SessionCard(
        session: session,
        onTap: () {
          // Switch to this session on Mac
          ble.sendCommand(
            BleCommand.switchSession(sessionId: session.id),
          );
          // Then open detail screen
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SessionDetailScreen(sessionId: session.id),
            ),
          );
        },
      ),
    );
  }
}
