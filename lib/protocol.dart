/// Bonjour service type for discovering Surfterm WebSocket servers.
const String bonjourServiceType = '_surfterm._tcp';

/// Session states.
enum SessionState {
  idle('Idle'),
  running('Running'),
  waitingForInput('WaitingForInput'),
  error('Error');

  const SessionState(this.wire);
  final String wire;

  static SessionState fromWire(String value) {
    return switch (value) {
      'Idle' => SessionState.idle,
      'Running' => SessionState.running,
      'WaitingForInput' || 'waiting_for_input' => SessionState.waitingForInput,
      'Error' => SessionState.error,
      _ => SessionState.idle,
    };
  }
}

/// Session layers.
enum SessionLayer {
  foreground('Foreground'),
  background('Background'),
  pinned('Pinned');

  const SessionLayer(this.wire);
  final String wire;

  static SessionLayer fromWire(String value) {
    return switch (value) {
      'Foreground' => SessionLayer.foreground,
      'Background' => SessionLayer.background,
      'Pinned' => SessionLayer.pinned,
      _ => SessionLayer.background,
    };
  }
}

/// Session status transmitted over WebSocket.
class SessionStatus {
  final String id;
  final String projectName;
  final SessionState state;
  final SessionLayer layer;

  const SessionStatus({
    required this.id,
    required this.projectName,
    required this.state,
    required this.layer,
  });

  factory SessionStatus.fromJson(Map<String, dynamic> json) {
    return SessionStatus(
      id: json['id'] as String,
      projectName: json['project_name'] as String,
      state: SessionState.fromWire(json['state'] as String),
      layer: SessionLayer.fromWire(json['layer'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'project_name': projectName,
        'state': state.wire,
        'layer': layer.wire,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionStatus &&
          id == other.id &&
          projectName == other.projectName &&
          state == other.state &&
          layer == other.layer;

  @override
  int get hashCode => Object.hash(id, projectName, state, layer);

  @override
  String toString() =>
      'SessionStatus(id: $id, project: $projectName, state: $state, layer: $layer)';
}
