import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'providers/connection_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Set to true to run with mock data (no real connection needed).
  useMockConnection = false;

  runApp(const ProviderScope(child: SurftermApp()));
}
