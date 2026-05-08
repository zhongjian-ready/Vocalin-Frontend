import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../widgets/vocalin_logo.dart';
import '../main_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, this.initialRoute});

  final String? initialRoute;

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        if (authService.isRestoringSession) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (authService.isAuthenticated) {
          return MainScreen(initialRoute: initialRoute ?? '/home');
        }

        return const AuthScreen();
      },
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

enum _AuthMode { login, register }

enum _LoginMethod { nickname, phone }

class _AuthScreenState extends State<AuthScreen> {
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  final _loginNicknameController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _registerNicknameController = TextEditingController();
  final _registerPhoneController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _registerConfirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  _AuthMode _authMode = _AuthMode.login;
  _LoginMethod _loginMethod = _LoginMethod.nickname;
  bool _obscureLoginPassword = true;
  bool _obscureRegisterPassword = true;
  bool _obscureRegisterConfirmPassword = true;

  @override
  void dispose() {
    _loginNicknameController.dispose();
    _loginPasswordController.dispose();
    _registerNicknameController.dispose();
    _registerPhoneController.dispose();
    _registerPasswordController.dispose();
    _registerConfirmPasswordController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFF4E7), Color(0xFFFCE7E1), Color(0xFFF6EEDF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: -40,
                right: -20,
                child: _GlowBlob(
                  size: 180,
                  color: const Color(0xFFFFD7B8).withValues(alpha: 0.85),
                ),
              ),
              Positioned(
                left: -30,
                bottom: 60,
                child: _GlowBlob(
                  size: 220,
                  color: const Color(0xFFFFE9C9).withValues(alpha: 0.6),
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 18,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 36,
                      ),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(6, 12, 6, 0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const VocalinLogo(
                                      size: 62,
                                      textGradient: LinearGradient(
                                        colors: [
                                          Color(0xFFF1B06C),
                                          Color(0xFFD88B63),
                                          Color(0xFFC1724D),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                    const SizedBox(height: 30),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white
                                            .withValues(alpha: 0.42),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        _authMode == _AuthMode.login
                                            ? 'It is okay to slow down'
                                            : 'Gather the life you love, gently',
                                        style: const TextStyle(
                                          color: Color(0xFFB67857),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _authMode == _AuthMode.login
                                          ? 'Welcome back'
                                          : 'Create your cozy corner',
                                      style: theme.textTheme.headlineMedium
                                          ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF5C4634),
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(maxWidth: 420),
                                      child: Text(
                                        _authMode == _AuthMode.login
                                            ? 'Set your worries down here, and let each moment feel a little softer.'
                                            : 'Start here and turn everyday moments into memories worth revisiting.',
                                        style:
                                            theme.textTheme.bodyLarge?.copyWith(
                                          color: const Color(0xFF8A6B58),
                                          height: 1.65,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 26),
                              Container(
                                width: double.infinity,
                                padding:
                                    const EdgeInsets.fromLTRB(18, 18, 18, 14),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(32),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x1E9E6A47),
                                      blurRadius: 28,
                                      offset: Offset(0, 14),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AnimatedSwitcher(
                                      duration:
                                          const Duration(milliseconds: 220),
                                      child: _authMode == _AuthMode.login
                                          ? _buildLoginPanel(context)
                                          : _buildRegisterPanel(context),
                                    ),
                                    const SizedBox(height: 14),
                                    Center(
                                      child: TextButton(
                                        onPressed: _toggleAuthMode,
                                        child: Text(
                                          _authMode == _AuthMode.login
                                              ? 'Don\'t have an account? Create one'
                                              : 'Already registered? Back to sign in',
                                          style: const TextStyle(
                                            color: Color(0xFFB36A48),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginPanel(BuildContext context) {
    final authService = context.watch<AuthService>();

    return Column(
      key: const ValueKey('login-panel'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'Choose a sign-in method',
            style: TextStyle(
              color: Color(0xFF9E7963),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8F0),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Row(
              children: [
                Expanded(
                  child: _MethodButton(
                    label: 'Nickname & Password',
                    selected: _loginMethod == _LoginMethod.nickname,
                    onTap: () {
                      setState(() {
                        _loginMethod = _LoginMethod.nickname;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: _MethodButton(
                    label: 'Phone & Code',
                    selected: _loginMethod == _LoginMethod.phone,
                    onTap: () {
                      setState(() {
                        _loginMethod = _LoginMethod.phone;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (_loginMethod == _LoginMethod.nickname)
          Form(
            key: _loginFormKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _loginNicknameController,
                  decoration:
                      _inputDecoration('Nickname', Icons.person_outline),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your nickname';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _loginPasswordController,
                  obscureText: _obscureLoginPassword,
                  decoration:
                      _inputDecoration('Password', Icons.lock_outline).copyWith(
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _obscureLoginPassword = !_obscureLoginPassword;
                        });
                      },
                      icon: Icon(
                        _obscureLoginPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: authService.isSubmitting ? null : _submitLogin,
                    style: _primaryButtonStyle(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: authService.isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Sign In'),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          _buildPhonePlaceholder(context),
      ],
    );
  }

  Widget _buildPhonePlaceholder(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: _inputDecoration('Phone Number', Icons.phone_outlined),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _codeController,
                decoration: _inputDecoration(
                    'Verification Code', Icons.mark_email_read_outlined),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: () {
                _showMessage(
                  'Phone verification sign-in is still being integrated. Please use nickname and password for now.',
                );
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(110, 54),
                side: const BorderSide(color: Color(0xFFE5B38F)),
              ),
              child: const Text('Send Code'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonal(
            onPressed: () {
              _showMessage(
                'Phone verification sign-in is reserved and can be enabled once the backend API is ready.',
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF6E4D6),
              foregroundColor: const Color(0xFF9A5A3D),
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: const Text('Coming Soon'),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterPanel(BuildContext context) {
    final authService = context.watch<AuthService>();

    return Form(
      key: _registerFormKey,
      child: Column(
        key: const ValueKey('register-panel'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              'Enter your registration details',
              style: TextStyle(
                color: Color(0xFF9E7963),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextFormField(
            controller: _registerNicknameController,
            decoration: _inputDecoration('Nickname', Icons.person_outline),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your nickname';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _registerPhoneController,
            keyboardType: TextInputType.phone,
            decoration: _inputDecoration('Phone Number', Icons.phone_outlined),
            validator: (value) {
              final normalized = value?.trim() ?? '';
              if (normalized.isEmpty) {
                return 'Please enter your phone number';
              }
              if (normalized.length < 11) {
                return 'Phone number looks incomplete';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _registerPasswordController,
            obscureText: _obscureRegisterPassword,
            decoration:
                _inputDecoration('Password', Icons.lock_outline).copyWith(
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    _obscureRegisterPassword = !_obscureRegisterPassword;
                  });
                },
                icon: Icon(
                  _obscureRegisterPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your password';
              }
              if (value.trim().length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _registerConfirmPasswordController,
            obscureText: _obscureRegisterConfirmPassword,
            decoration: _inputDecoration(
                    'Confirm Password', Icons.verified_user_outlined)
                .copyWith(
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    _obscureRegisterConfirmPassword =
                        !_obscureRegisterConfirmPassword;
                  });
                },
                icon: Icon(
                  _obscureRegisterConfirmPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please confirm your password';
              }
              if (value.trim() != _registerPasswordController.text.trim()) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: authService.isSubmitting ? null : _submitRegister,
              style: _primaryButtonStyle(),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: authService.isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create Account'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFFB67957)),
      filled: true,
      fillColor: const Color(0xFFFFFBF7),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFF1D7C6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFD58C62), width: 1.4),
      ),
    );
  }

  ButtonStyle _primaryButtonStyle() {
    return FilledButton.styleFrom(
      backgroundColor: const Color(0xFFCA7C56),
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
    );
  }

  void _toggleAuthMode() {
    setState(() {
      _authMode =
          _authMode == _AuthMode.login ? _AuthMode.register : _AuthMode.login;
    });
  }

  Future<void> _submitLogin() async {
    if (!_loginFormKey.currentState!.validate()) {
      return;
    }

    try {
      await context.read<AuthService>().loginWithNickname(
            nickname: _loginNicknameController.text,
            password: _loginPasswordController.text,
          );
    } on AuthException catch (error) {
      await _showFeedbackDialog(
        title: 'Sign-in failed',
        message: error.message,
        icon: Icons.lock_outline_rounded,
        accentColor: const Color(0xFFCA7C56),
      );
    }
  }

  Future<void> _submitRegister() async {
    if (!_registerFormKey.currentState!.validate()) {
      return;
    }

    try {
      await context.read<AuthService>().register(
            nickname: _registerNicknameController.text,
            phoneNumber: _registerPhoneController.text,
            password: _registerPasswordController.text,
            confirmPassword: _registerConfirmPasswordController.text,
          );
    } on AuthException catch (error) {
      await _showFeedbackDialog(
        title: 'Registration failed',
        message: error.message,
        icon: Icons.person_add_alt_1_rounded,
        accentColor: const Color(0xFFD08B62),
      );
    }
  }

  Future<void> _showMessage(String message) {
    return _showFeedbackDialog(
      title: 'Notice',
      message: message,
      icon: Icons.info_outline_rounded,
      accentColor: const Color(0xFFB67957),
    );
  }

  Future<void> _showFeedbackDialog({
    required String title,
    required String message,
    required IconData icon,
    required Color accentColor,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color(0x665C4634),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFFCF8), Color(0xFFFFF3E8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x2A7E543D),
                  blurRadius: 30,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: accentColor, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF5C4634),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFF0D7C1),
                      ),
                    ),
                    child: Text(
                      message,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        color: Color(0xFF7A6251),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('OK'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MethodButton extends StatelessWidget {
  const _MethodButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFFFE4CF) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  color: selected
                      ? const Color(0xFFA55E3C)
                      : const Color(0xFF987867),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0.08)],
          ),
        ),
      ),
    );
  }
}
