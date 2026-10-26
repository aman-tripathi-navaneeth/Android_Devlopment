import 'package:flutter/material.dart';

import 'core/theme/theme.dart';
import 'core/localization/language_controller.dart';
import 'core/ui/mobile_viewport.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/shell/screens/main_shell_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PharmacyApp());
}

class PharmacyApp extends StatefulWidget {
  const PharmacyApp({super.key});

  @override
  State<PharmacyApp> createState() => _PharmacyAppState();
}

class _PharmacyAppState extends State<PharmacyApp> {
  final LanguageController _langController = LanguageController();
  bool _isAuthenticated =
      true; // Set to true by default for developer evaluation, easily toggled

  @override
  void initState() {
    super.initState();
    _langController.addListener(_onLocaleChange);
  }

  @override
  void dispose() {
    _langController.removeListener(_onLocaleChange);
    super.dispose();
  }

  void _onLocaleChange() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pharmacy Store • మెడికల్ స్టోర్',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      builder: (context, child) => MobileViewport(child: child!),
      locale: _langController.locale,
      home: _isAuthenticated
          ? MainShellScreen(
              onLogout: () => setState(() => _isAuthenticated = false),
            )
          : LoginScreen(
              onLoginSuccess: () => setState(() => _isAuthenticated = true),
            ),
    );
  }
}
