import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/account_provider.dart';
import 'providers/security_provider.dart';
import 'providers/sync_provider.dart';
import 'theme.dart';
import 'widgets/auth_gate.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SecurityProvider()),
        ChangeNotifierProvider(create: (_) => AccountProvider()),
        ChangeNotifierProvider(create: (_) => SyncProvider()),
      ],
      child: const TotpApp(),
    ),
  );
}

class TotpApp extends StatelessWidget {
  const TotpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TOTP Authenticator',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const AuthGate(),
    );
  }
}
