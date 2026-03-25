import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'home_screen.dart';
import '../utils/theme_provider.dart';

class AuthScreen extends StatefulWidget {
  final ThemeProvider themeProvider;

  const AuthScreen({super.key, required this.themeProvider});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();
  bool _isSettingsLoaded = false;
  bool _isAuthRequired = false;

  @override
  void initState() {
    super.initState();
    _checkAuthSetting();
  }

  Future<void> _checkAuthSetting() async {
    final authRequiredStr = await secureStorage.read(key: 'auth_required');
    final isAuthRequired = authRequiredStr == 'true';

    if (!mounted) return;

    setState(() {
      _isAuthRequired = isAuthRequired;
      _isSettingsLoaded = true;
    });

    if (isAuthRequired) {
      _authenticate();
    } else {
      _navigateToHome();
    }
  }

  Future<void> _authenticate() async {
    try {
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await auth.isDeviceSupported();

      if (!canAuthenticate) {
        _navigateToHome();
        return;
      }

      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Please authenticate to access your documents',
      );

      if (didAuthenticate) {
        _navigateToHome();
      }
    } catch (e) {
      debugPrint('Error during authentication: $e');
      // If error occurs (e.g. user canceled), stay on AuthScreen
    }
  }

  void _navigateToHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HomeScreen(themeProvider: widget.themeProvider),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show a loading screen while checking settings or when auth is required
    return Scaffold(
      body: Center(
        child: _isSettingsLoaded && _isAuthRequired
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline, size: 80),
                  const SizedBox(height: 20),
                  const Text(
                    'App Locked',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton.icon(
                    onPressed: _authenticate,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Unlock'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}
