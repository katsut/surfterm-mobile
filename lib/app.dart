import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/scan_screen.dart';
import 'services/ble_service.dart';
import 'theme/catppuccin.dart';

/// Root widget of the Surfterm mobile app.
class SurftermApp extends StatelessWidget {
  /// Set to `true` to use [MockBleService] for development.
  final bool useMock;

  const SurftermApp({super.key, this.useMock = true});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<BleService>(
      create: (_) => useMock ? MockBleService() : BleService(),
      child: MaterialApp(
        title: 'Surfterm',
        debugShowCheckedModeBanner: false,
        theme: CatppuccinMocha.themeData(),
        home: const ScanScreen(),
      ),
    );
  }
}
