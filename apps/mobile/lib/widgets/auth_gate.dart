import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/security_provider.dart';
import '../screens/home_screen.dart';
import '../screens/lock_screen.dart';

/// Top-level routing gate and privacy shield for biometric authentication.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  bool _isInBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      if (!_isInBackground) {
        setState(() {
          _isInBackground = true;
        });
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_isInBackground) {
        setState(() {
          _isInBackground = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final security = context.watch<SecurityProvider>();
    final theme = Theme.of(context);

    // Initial loading state while reading storage
    if (!security.isInitialized) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final Widget activeScreen = (security.isBiometricEnabled && security.isLocked)
        ? const LockScreen()
        : const HomeScreen();

    // Multitasking Privacy Shield:
    // If the app is in the background and biometrics is enabled, obscure sensitive TOTP codes
    if (_isInBackground && security.isBiometricEnabled) {
      return Stack(
        children: [
          activeScreen,
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(
                color: theme.scaffoldBackgroundColor.withValues(alpha: 0.9),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_outlined, size: 64, color: theme.colorScheme.primary),
                      const SizedBox(height: 16),
                      Text(
                        'TOTP Authenticator',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return activeScreen;
  }
}
