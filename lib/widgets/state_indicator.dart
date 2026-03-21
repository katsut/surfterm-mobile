import 'package:flutter/material.dart';

import '../models/session.dart';
import '../theme/catppuccin.dart';

/// A small color-coded badge showing the session state.
class StateIndicator extends StatelessWidget {
  final SessionState state;

  const StateIndicator({super.key, required this.state});

  /// Map session state to a Catppuccin color.
  static Color colorForState(SessionState state) {
    return switch (state) {
      SessionState.idle => CatppuccinMocha.overlay1,
      SessionState.running => CatppuccinMocha.yellow,
      SessionState.waitingForInput => CatppuccinMocha.green,
      SessionState.error => CatppuccinMocha.red,
    };
  }

  /// Human-readable label for the state.
  static String labelForState(SessionState state) {
    return switch (state) {
      SessionState.idle => 'Idle',
      SessionState.running => 'Running',
      SessionState.waitingForInput => 'Waiting',
      SessionState.error => 'Error',
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = colorForState(state);
    final label = labelForState(state);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(38),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(128)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
