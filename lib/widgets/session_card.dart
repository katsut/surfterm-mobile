import 'package:flutter/material.dart';

import '../models/session.dart';
import '../theme/catppuccin.dart';
import 'state_indicator.dart';

/// A card displaying a session's project name, state, and layer.
class SessionCard extends StatelessWidget {
  final SessionStatus session;
  final VoidCallback? onTap;

  const SessionCard({super.key, required this.session, this.onTap});

  /// Icon for the session layer.
  static IconData iconForLayer(SessionLayer layer) {
    return switch (layer) {
      SessionLayer.foreground => Icons.visibility,
      SessionLayer.background => Icons.visibility_off_outlined,
      SessionLayer.pinned => Icons.push_pin,
    };
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = StateIndicator.colorForState(session.state);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor.withAlpha(102), width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Project icon placeholder
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: borderColor.withAlpha(38),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    session.projectName.isNotEmpty
                        ? session.projectName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: borderColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.projectName,
                      style: const TextStyle(
                        color: CatppuccinMocha.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          iconForLayer(session.layer),
                          size: 14,
                          color: CatppuccinMocha.subtext0,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          session.layer.toJsonString(),
                          style: const TextStyle(
                            color: CatppuccinMocha.subtext0,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              StateIndicator(state: session.state),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right,
                color: CatppuccinMocha.overlay1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
