import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../protocol.dart';
import '../models/command.dart';
import '../providers/connection_provider.dart';
import '../theme/catppuccin.dart';
import '../widgets/session_card.dart';

class SessionListScreen extends ConsumerWidget {
  const SessionListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conn = ref.watch(connectionProvider);

    if (!conn.isConnected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/scan');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final sessions = conn.sessions;
    final pinned = sessions.where((s) => s.layer == SessionLayer.pinned).toList();
    final foreground = sessions.where((s) => s.layer == SessionLayer.foreground).toList();
    final background = sessions.where((s) => s.layer == SessionLayer.background).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sessions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bluetooth_disabled),
            tooltip: 'Disconnect',
            onPressed: () => conn.disconnect(),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: CatppuccinMocha.mauve,
        onRefresh: () => conn.refreshSessions(),
        child: sessions.isEmpty
            ? const Center(
                child: Text('No active sessions',
                    style: TextStyle(color: CatppuccinMocha.subtext0)),
              )
            : ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (pinned.isNotEmpty) ...[
                    _sectionHeader('Pinned'),
                    ...pinned.map((s) => _card(context, conn, s)),
                  ],
                  if (foreground.isNotEmpty) ...[
                    _sectionHeader('Foreground'),
                    ...foreground.map((s) => _card(context, conn, s)),
                  ],
                  if (background.isNotEmpty) ...[
                    _sectionHeader('Background'),
                    ...background.map((s) => _card(context, conn, s)),
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

  Widget _card(BuildContext context, dynamic conn, SessionStatus session) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SessionCard(
        session: session,
        onTap: () {
          conn.sendCommand(Command.switchSession(sessionId: session.id));
          context.push('/session/${session.id}');
        },
      ),
    );
  }
}
