import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'database/app_database.dart';
import 'screens/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Defer database and heavy app build to avoid "app not responding" / skipped frames on startup
  runApp(const _AppLoader());
}

/// Shows minimal loading UI first, then creates DB after a delay, then builds full app on next frame.
class _AppLoader extends StatefulWidget {
  const _AppLoader();

  @override
  State<_AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<_AppLoader> {
  AppDatabase? _database;
  bool _buildFullApp = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Yield several frames so the loading UI paints before any heavy work
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    final db = AppDatabase();
    if (!mounted) return;
    setState(() => _database = db);
    // Build the full app on the next frame so this frame stays light
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _buildFullApp = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_database == null || !_buildFullApp) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(child: const CircularProgressIndicator()),
        ),
      );
    }
    return ChangeNotifierProvider(
      create: (_) => AppState(_database!),
      child: const MyApp(),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Billing Service',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
