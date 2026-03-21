/// Session state, matching Rust `SessionState` enum variants.
enum SessionState {
  idle,
  running,
  waitingForInput,
  error;

  /// Parse from the string representation used in the BLE JSON protocol.
  static SessionState fromString(String value) {
    return switch (value.toLowerCase()) {
      'idle' => SessionState.idle,
      'running' => SessionState.running,
      'waitingforinput' || 'waiting_for_input' => SessionState.waitingForInput,
      'error' => SessionState.error,
      _ => SessionState.idle,
    };
  }

  /// Serialize to the string representation used in the BLE JSON protocol.
  String toJsonString() {
    return switch (this) {
      SessionState.idle => 'Idle',
      SessionState.running => 'Running',
      SessionState.waitingForInput => 'WaitingForInput',
      SessionState.error => 'Error',
    };
  }
}

/// Session layer, matching Rust layer system.
enum SessionLayer {
  foreground,
  background,
  pinned;

  static SessionLayer fromString(String value) {
    return switch (value.toLowerCase()) {
      'foreground' => SessionLayer.foreground,
      'background' => SessionLayer.background,
      'pinned' => SessionLayer.pinned,
      _ => SessionLayer.background,
    };
  }

  String toJsonString() {
    return switch (this) {
      SessionLayer.foreground => 'Foreground',
      SessionLayer.background => 'Background',
      SessionLayer.pinned => 'Pinned',
    };
  }
}

/// Session status model matching Rust `SessionStatusData`.
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
      state: SessionState.fromString(json['state'] as String),
      layer: SessionLayer.fromString(json['layer'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_name': projectName,
      'state': state.toJsonString(),
      'layer': layer.toJsonString(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionStatus &&
          runtimeType == other.runtimeType &&
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
