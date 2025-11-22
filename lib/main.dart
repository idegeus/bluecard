import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'screens/role_selection_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enable wakelock om scherm aan te houden tijdens spelen
  WakelockPlus.enable();

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Disable wakelock when app is disposed
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // Re-enable wakelock when app returns to foreground
        WakelockPlus.enable();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // Disable wakelock when app goes to background or is closed
        WakelockPlus.disable();
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BlueCard',
      theme: ThemeData(primarySwatch: Colors.blue, brightness: Brightness.dark),
      home: RoleSelectionScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
