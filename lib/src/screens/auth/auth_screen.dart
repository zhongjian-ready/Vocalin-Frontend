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
                                        color: Colors.white.withValues(alpha: 0.42),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        _authMode == _AuthMode.login
                                            ? '慢一点，也没有关系'
                                            : '把喜欢的生活慢慢装进来',
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
                                          ? '欢迎回家'
                                          : '创建你的温暖角落',
                                      style: theme.textTheme.headlineMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF5C4634),
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 420),
                                      child: Text(
                                        _authMode == _AuthMode.login
                                            ? '愿你在这里放下疲惫，把每一次相遇都过成温柔的日常。'
                                            : '从这里开始，慢慢把彼此的日常收藏成值得回看的时光。',
                                        style: theme.textTheme.bodyLarge?.copyWith(
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
                                padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
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
                                      duration: const Duration(milliseconds: 220),
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
                                              ? '还没有注册？去注册页面'
                                              : '已经注册过了？返回登录',
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
            '选择登录方式',
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
                    label: '昵称密码',
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
                    label: '手机号验证码',
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
                  decoration: _inputDecoration('昵称', Icons.person_outline),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '请输入昵称';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _loginPasswordController,
                  obscureText: _obscureLoginPassword,
                  decoration: _inputDecoration('密码', Icons.lock_outline).copyWith(
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
                      return '请输入密码';
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
                          : const Text('登录'),
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
          decoration: _inputDecoration('手机号', Icons.phone_outlined),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _codeController,
                decoration: _inputDecoration('验证码', Icons.mark_email_read_outlined),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: () {
                _showMessage('验证码登录还在联调中，先用昵称密码登录。');
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(110, 54),
                side: const BorderSide(color: Color(0xFFE5B38F)),
              ),
              child: const Text('获取验证码'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonal(
            onPressed: () {
              _showMessage('手机号验证码登录预留好了，后续接后端接口即可启用。');
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF6E4D6),
              foregroundColor: const Color(0xFF9A5A3D),
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: const Text('暂未开放'),
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
              '填写你的注册信息',
              style: TextStyle(
                color: Color(0xFF9E7963),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextFormField(
            controller: _registerNicknameController,
            decoration: _inputDecoration('昵称', Icons.person_outline),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '请输入昵称';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _registerPhoneController,
            keyboardType: TextInputType.phone,
            decoration: _inputDecoration('手机号', Icons.phone_outlined),
            validator: (value) {
              final normalized = value?.trim() ?? '';
              if (normalized.isEmpty) {
                return '请输入手机号';
              }
              if (normalized.length < 11) {
                return '手机号格式不完整';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _registerPasswordController,
            obscureText: _obscureRegisterPassword,
            decoration: _inputDecoration('密码', Icons.lock_outline).copyWith(
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
                return '请输入密码';
              }
              if (value.trim().length < 6) {
                return '密码至少 6 位';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _registerConfirmPasswordController,
            obscureText: _obscureRegisterConfirmPassword,
            decoration: _inputDecoration('再次确认密码', Icons.verified_user_outlined)
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
                return '请再次输入密码';
              }
              if (value.trim() != _registerPasswordController.text.trim()) {
                return '两次输入的密码不一致';
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
                    : const Text('注册并进入'),
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
        title: '登录没有成功',
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
        title: '注册暂时没通过',
        message: error.message,
        icon: Icons.person_add_alt_1_rounded,
        accentColor: const Color(0xFFD08B62),
      );
    }
  }

  Future<void> _showMessage(String message) {
    return _showFeedbackDialog(
      title: '提示',
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
                      child: const Text('我知道了'),
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
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Center(
            child: Text(
              label,
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
