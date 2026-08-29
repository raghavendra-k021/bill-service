import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';
import '../login/login_screen.dart';

/// Splash screen shown until the app (and database) is ready.
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeAndNavigate();
  }

  Future<void> _initializeAndNavigate() async {
    // Brief delay so the splash is visible and the first frame can render
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;

    final appState = Provider.of<AppState>(context, listen: false);

    // Ensure database is ready (triggers connection if lazy)
    try {
      await appState.database.select(appState.database.shopSettings).getSingleOrNull();
    } catch (_) {
      // Continue even if query fails (e.g. first run); DB will be ready on next use
    }

    if (!mounted) return;

    await Future.delayed(const Duration(milliseconds: 400));

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              Icon(
                Icons.store,
                size: 80,
                color: Colors.white.withValues(alpha: 0.95),
              ),
              const SizedBox(height: 24),
              Text(
                'Billing Service',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white.withValues(alpha: 0.98),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Loading...',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const Spacer(flex: 2),
              const Padding(
                padding: EdgeInsets.only(bottom: 48),
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
