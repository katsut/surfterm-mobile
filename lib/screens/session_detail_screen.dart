import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/command.dart';
import '../models/session.dart';
import '../services/ble_service.dart';
import '../theme/catppuccin.dart';
import '../widgets/state_indicator.dart';

/// Detail screen for a single session.
class SessionDetailScreen extends StatefulWidget {
  final String sessionId;

  const SessionDetailScreen({super.key, required this.sessionId});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  final _responseController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _responseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleService>();
    final session = ble.sessionById(widget.sessionId);

    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Session')),
        body: const Center(
          child: Text(
            'Session not found',
            style: TextStyle(color: CatppuccinMocha.subtext0),
          ),
        ),
      );
    }

    final isPinned = session.layer == SessionLayer.pinned;

    return Scaffold(
      appBar: AppBar(
        title: Text(session.projectName),
        actions: [
          // Pin / Unpin
          IconButton(
            icon: Icon(
              isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              color: isPinned ? CatppuccinMocha.mauve : null,
            ),
            tooltip: isPinned ? 'Unpin' : 'Pin to foreground',
            onPressed: () {
              ble.sendCommand(BleCommand.pinSession(sessionId: session.id));
            },
          ),
          // Switch to this session
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Switch to this session',
            onPressed: () {
              ble.sendCommand(
                BleCommand.switchSession(sessionId: session.id),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Session info card
            _buildInfoCard(session),

            const SizedBox(height: 24),

            // Response input (only for WaitingForInput)
            if (session.state == SessionState.waitingForInput) ...[
              const Text(
                'Respond',
                style: TextStyle(
                  color: CatppuccinMocha.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _responseController,
                maxLines: 4,
                style: const TextStyle(color: CatppuccinMocha.text),
                decoration: const InputDecoration(
                  hintText: 'Type your response...',
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _sending ? null : () => _sendResponse(ble, session),
                  icon: _sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: CatppuccinMocha.crust,
                          ),
                        )
                      : const Icon(Icons.send),
                  label: Text(_sending ? 'Sending...' : 'Send Response'),
                ),
              ),
            ],

            if (session.state != SessionState.waitingForInput)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _iconForState(session.state),
                        size: 48,
                        color: StateIndicator.colorForState(session.state),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _descriptionForState(session.state),
                        style: const TextStyle(
                          color: CatppuccinMocha.subtext0,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(SessionStatus session) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _infoRow('Project', session.projectName),
            const Divider(height: 24),
            _infoRow('Session ID', session.id),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'State',
                  style: TextStyle(color: CatppuccinMocha.subtext0),
                ),
                StateIndicator(state: session.state),
              ],
            ),
            const Divider(height: 24),
            _infoRow('Layer', session.layer.toJsonString()),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: CatppuccinMocha.subtext0)),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(color: CatppuccinMocha.text),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Future<void> _sendResponse(BleService ble, SessionStatus session) async {
    final text = _responseController.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);

    await ble.sendCommand(
      BleCommand.respond(sessionId: session.id, payload: text),
    );

    _responseController.clear();

    if (mounted) {
      setState(() => _sending = false);
    }
  }

  IconData _iconForState(SessionState state) {
    return switch (state) {
      SessionState.idle => Icons.pause_circle_outline,
      SessionState.running => Icons.play_circle_outline,
      SessionState.waitingForInput => Icons.edit_note,
      SessionState.error => Icons.error_outline,
    };
  }

  String _descriptionForState(SessionState state) {
    return switch (state) {
      SessionState.idle => 'Session is idle.\nNo active tasks.',
      SessionState.running =>
        'Session is running.\nWaiting for completion...',
      SessionState.waitingForInput => 'Session needs your input.',
      SessionState.error =>
        'Session encountered an error.\nCheck the desktop for details.',
    };
  }
}
