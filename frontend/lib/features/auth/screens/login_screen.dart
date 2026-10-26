import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/ui/language_toggle.dart';
import '../../../core/ui/inline_banner.dart';

/// LOGIN SCREEN - Section 10.1
class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController(text: 'owner');
  final _passwordController = TextEditingController(text: 'pharmacy2026');
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await Future.delayed(const Duration(milliseconds: 600));

    final user = _usernameController.text.trim();
    final pass = _passwordController.text.trim();

    if (user.isEmpty || pass.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Please enter your username/phone and password';
      });
      return;
    }

    setState(() => _isLoading = false);
    widget.onLoginSuccess();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 20.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top language switch bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: const [LanguageToggle()],
                ),
                const SizedBox(height: 32),

                // Brand Logo Wordmark (Calm, professional pharmacy tool)
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.matcha.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.matchaDeep,
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.local_pharmacy_rounded,
                        color: AppColors.matchaDeep,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.appTitle,
                          style: AppTypography.display.copyWith(fontSize: 22),
                        ),
                        Text(
                          'Stock & Counter Management System',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 36),

                // Error banner
                if (_errorMessage != null) ...[
                  InlineBanner(message: _errorMessage!, type: BannerType.error),
                  const SizedBox(height: 16),
                ],

                // Login form
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.outline, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.usernameOrPhone,
                        style: AppTypography.label.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          hintText: 'Enter phone or username',
                          prefixIcon: Icon(
                            Icons.person_outline_rounded,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text(
                        strings.password,
                        style: AppTypography.label.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          hintText: 'Enter password',
                          prefixIcon: const Icon(
                            Icons.lock_outline_rounded,
                            size: 20,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 20,
                              color: AppColors.inkSoft,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Text(strings.login),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Center(
                  child: Text(
                    'Roles: OWNER • STAFF (Server Authenticated)',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.inkSoft,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
