import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../utils/validators.dart';
import '../../screens/dashboard/dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  late AuthService _authService;
  bool _isLoading = false;
  bool _rememberMe = false;
  bool _isBiometricAvailable = false;

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<AppState>(context, listen: false);
    _authService = AuthService(appState.database);
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    final available = await _authService.isBiometricAvailable();
    setState(() {
      _isBiometricAvailable = available;
    });
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _authService.login(
        _usernameController.text.trim(),
        _passwordController.text,
      );

      if (user != null && mounted) {
        final appState = Provider.of<AppState>(context, listen: false);
        appState.setUser(user);
        
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid username or password'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleBiometricLogin() async {
    // Biometric only confirms; login still uses username/password from fields.
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (username.isEmpty || password.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Enter username and password first, then tap fingerprint to log in.',
            ),
          ),
        );
      }
      return;
    }
    final authenticated = await _authService.authenticateWithBiometric();
    if (authenticated && mounted) {
      await _handleLogin();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Biometric failed. Add fingerprint/face in Settings → Security, or log in with password.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.store,
                    size: 80,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Billing Service',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 48),
                  CustomTextField(
                    label: 'Username',
                    controller: _usernameController,
                    validator: Validators.validateUsername,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    label: 'Password',
                    controller: _passwordController,
                    validator: Validators.validatePassword,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _handleLogin(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        onChanged: (value) {
                          setState(() {
                            _rememberMe = value ?? false;
                          });
                        },
                      ),
                      const Text('Remember me'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  CustomButton(
                    text: 'Login',
                    onPressed: _handleLogin,
                    isLoading: _isLoading,
                    width: double.infinity,
                  ),
                  if (_isBiometricAvailable) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Enter credentials above, then tap to log in with fingerprint/face',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    IconButton(
                      icon: const Icon(Icons.fingerprint, size: 48),
                      onPressed: _handleBiometricLogin,
                      tooltip: 'Login with biometric (enter username & password first)',
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
