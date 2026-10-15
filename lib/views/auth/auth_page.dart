import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/history_viewmodel.dart';
import '../../viewmodels/settings_viewmodel.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _loginFormKey = GlobalKey<FormState>();
  final _signupFormKey = GlobalKey<FormState>();

  // Login controllers
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  bool _loginObscurePassword = true;

  // Sign up controllers
  final _signupNameController = TextEditingController();
  final _signupShopController = TextEditingController(text: 'MK Star');
  final _signupEmailController = TextEditingController();
  final _signupPasswordController = TextEditingController();
  final _signupConfirmPasswordController = TextEditingController();
  bool _signupObscurePassword = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _signupNameController.dispose();
    _signupShopController.dispose();
    _signupEmailController.dispose();
    _signupPasswordController.dispose();
    _signupConfirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;

    final authVm = context.read<AuthViewModel>();
    final success = await authVm.login(
      email: _loginEmailController.text,
      password: _loginPasswordController.text,
    );

    if (success && mounted) {
      final user = authVm.currentUser;
      if (user != null) {
        context.read<HistoryViewModel>().setCurrentUser(user.id);
        context.read<SettingsViewModel>().init(
          userId: user.id,
          initialShopName: user.shopName,
        );
      }
    }
  }

  Future<void> _handleSignup() async {
    if (!_signupFormKey.currentState!.validate()) return;

    final authVm = context.read<AuthViewModel>();
    final success = await authVm.signup(
      name: _signupNameController.text,
      email: _signupEmailController.text,
      password: _signupPasswordController.text,
      shopName: _signupShopController.text,
    );

    if (success && mounted) {
      final user = authVm.currentUser;
      if (user != null) {
        context.read<HistoryViewModel>().setCurrentUser(user.id);
        context.read<SettingsViewModel>().init(
          userId: user.id,
          initialShopName: user.shopName,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A0A20), Color(0xFF14194A), Color(0xFF0D0D2E)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Brand Header
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.cardDark,
                        border: Border.all(color: AppTheme.gold, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.gold.withValues(alpha: 0.25),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Image.asset(
                            'asserts/logo-CWXXw7Ao.png',
                            fit: BoxFit.contain,
                            errorBuilder: (ctx, err, stack) =>
                                const Icon(Icons.star_rounded, color: AppTheme.gold, size: 40),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'MK STAR',
                      style: TextStyle(
                        color: AppTheme.gold,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                      ),
                    ),
                    const Text(
                      'Photography Studio Invoicing System',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Error banner
                    if (authVm.errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.error.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                color: AppTheme.error, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                authVm.errorMessage!,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 16, color: Colors.white70),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: authVm.clearError,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Card container with TabBar
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.cardDark,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.divider),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Tab Bar
                          Container(
                            margin: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceDark,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: TabBar(
                              controller: _tabController,
                              indicatorSize: TabBarIndicatorSize.tab,
                              dividerColor: Colors.transparent,
                              indicator: BoxDecoration(
                                color: AppTheme.gold,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              labelColor: AppTheme.primaryDark,
                              unselectedLabelColor: AppTheme.textSecondary,
                              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              tabs: const [
                                Tab(text: 'Log In'),
                                Tab(text: 'Sign Up'),
                              ],
                            ),
                          ),

                          // Tab Views
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                            child: AnimatedBuilder(
                              animation: _tabController,
                              builder: (context, _) {
                                return _tabController.index == 0
                                    ? _buildLoginForm(authVm)
                                    : _buildSignupForm(authVm);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Cloud & offline feature note
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_sync_rounded, color: AppTheme.gold, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Each user has private, isolated bills & cloud sync',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm(AuthViewModel authVm) {
    return Form(
      key: _loginFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 6),
          TextFormField(
            controller: _loginEmailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Email Address',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Enter your email';
              if (!v.contains('@')) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _loginPasswordController,
            obscureText: _loginObscurePassword,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(
                  _loginObscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: AppTheme.textSecondary,
                ),
                onPressed: () => setState(() => _loginObscurePassword = !_loginObscurePassword),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Enter your password';
              return null;
            },
          ),
          const SizedBox(height: 22),
          ElevatedButton(
            onPressed: authVm.isLoading ? null : _handleLogin,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: AppTheme.gold,
              foregroundColor: AppTheme.primaryDark,
            ),
            child: authVm.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primaryDark,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.login_rounded, size: 20),
                      SizedBox(width: 8),
                      Text('Log In', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignupForm(AuthViewModel authVm) {
    return Form(
      key: _signupFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 6),
          TextFormField(
            controller: _signupNameController,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Your Name',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Enter your name';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _signupShopController,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Studio / Shop Name',
              prefixIcon: Icon(Icons.storefront_rounded),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Enter your studio name';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _signupEmailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Email Address',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Enter your email';
              if (!v.contains('@')) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _signupPasswordController,
            obscureText: _signupObscurePassword,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              labelText: 'Password (min. 6 chars)',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(
                  _signupObscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: AppTheme.textSecondary,
                ),
                onPressed: () => setState(() => _signupObscurePassword = !_signupObscurePassword),
              ),
            ),
            validator: (v) {
              if (v == null || v.length < 6) return 'Password must be at least 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _signupConfirmPasswordController,
            obscureText: _signupObscurePassword,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Confirm Password',
              prefixIcon: Icon(Icons.lock_clock_outlined),
            ),
            validator: (v) {
              if (v != _signupPasswordController.text) return 'Passwords do not match';
              return null;
            },
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: authVm.isLoading ? null : _handleSignup,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: AppTheme.gold,
              foregroundColor: AppTheme.primaryDark,
            ),
            child: authVm.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primaryDark,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_add_rounded, size: 20),
                      SizedBox(width: 8),
                      Text('Create Account',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

