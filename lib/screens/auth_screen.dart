import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_state.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _signInEmail = TextEditingController();
  final _signInPassword = TextEditingController();
  final _signUpName = TextEditingController();
  final _signUpEmail = TextEditingController();
  final _signUpPassword = TextEditingController();

  bool _hideSignInPassword = true;
  bool _hideSignUpPassword = true;
  bool _isCreateMode = false;

  @override
  void dispose() {
    _signInEmail.dispose();
    _signInPassword.dispose();
    _signUpName.dispose();
    _signUpEmail.dispose();
    _signUpPassword.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn(BuildContext context) async {
    final auth = context.read<AuthState>();
    final messenger = ScaffoldMessenger.of(context);

    if (_signInEmail.text.trim().isEmpty || _signInPassword.text.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please enter email and password.')),
      );
      return;
    }

    try {
      await auth.signIn(
        email: _signInEmail.text.trim(),
        password: _signInPassword.text,
      );
    } catch (_) {
      if (!mounted) return;
      final message = auth.errorMessage ?? 'Sign in failed';
      debugPrint('Auth sign-in failed: $message');
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _handleSignUp(BuildContext context) async {
    final auth = context.read<AuthState>();
    final messenger = ScaffoldMessenger.of(context);

    if (_signUpName.text.trim().isEmpty ||
        _signUpEmail.text.trim().isEmpty ||
        _signUpPassword.text.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please fill all required fields.')),
      );
      return;
    }

    if (_signUpPassword.text.length < 8) {
      messenger.showSnackBar(
        const SnackBar(
            content: Text('Password must be at least 8 characters.')),
      );
      return;
    }

    try {
      await auth.signUp(
        name: _signUpName.text.trim(),
        email: _signUpEmail.text.trim(),
        password: _signUpPassword.text,
      );
    } catch (_) {
      if (!mounted) return;
      final message = auth.errorMessage ?? 'Sign up failed';
      debugPrint('Auth sign-up failed: $message');
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Consumer<AuthState>(
          builder: (context, auth, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom -
                      48,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primaryContainer,
                            colorScheme.secondaryContainer,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.25),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/Icons/playstore.png',
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Welcome to MediPal',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Secure sign in for personalized health guidance',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _modeButton(
                              title: 'Sign in',
                              selected: !_isCreateMode,
                              onTap: auth.isBusy
                                  ? null
                                  : () => setState(() => _isCreateMode = false),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _modeButton(
                              title: 'Create account',
                              selected: _isCreateMode,
                              onTap: auth.isBusy
                                  ? null
                                  : () => setState(() => _isCreateMode = true),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: _isCreateMode
                          ? _buildCreateCard(
                              context, theme, colorScheme, auth.isBusy)
                          : _buildSignInCard(
                              context, theme, colorScheme, auth.isBusy),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colorScheme.outline.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Guest mode: ${AuthState.guestTokensLimit} tokens per session.',
                            style: theme.textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton(
                            onPressed: auth.isBusy
                                ? null
                                : () =>
                                    context.read<AuthState>().continueAsGuest(),
                            child: const Text('Continue as Guest'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSignInCard(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    bool isBusy,
  ) {
    return _authCard(
      child: Column(
        key: const ValueKey('sign-in'),
        children: [
          _textField(
            controller: _signInEmail,
            label: 'Email Address',
            hint: 'Enter your email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            enabled: !isBusy,
          ),
          const SizedBox(height: 14),
          _passwordField(
            controller: _signInPassword,
            hidden: _hideSignInPassword,
            onToggle: isBusy
                ? null
                : () =>
                    setState(() => _hideSignInPassword = !_hideSignInPassword),
            label: 'Password',
            enabled: !isBusy,
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: isBusy ? null : () => _handleSignIn(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: isBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login),
              label: Text(
                isBusy ? 'Signing in...' : 'Sign in',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateCard(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    bool isBusy,
  ) {
    return _authCard(
      child: Column(
        key: const ValueKey('create-account'),
        children: [
          _textField(
            controller: _signUpName,
            label: 'Full Name',
            hint: 'Enter your name',
            icon: Icons.person_outline,
            keyboardType: TextInputType.name,
            enabled: !isBusy,
          ),
          const SizedBox(height: 14),
          _textField(
            controller: _signUpEmail,
            label: 'Email Address',
            hint: 'Enter your email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            enabled: !isBusy,
          ),
          const SizedBox(height: 14),
          _passwordField(
            controller: _signUpPassword,
            hidden: _hideSignUpPassword,
            onToggle: isBusy
                ? null
                : () =>
                    setState(() => _hideSignUpPassword = !_hideSignUpPassword),
            label: 'Password (8+ chars)',
            enabled: !isBusy,
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: isBusy ? null : () => _handleSignUp(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: isBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.person_add_alt_1),
              label: Text(
                isBusy ? 'Creating...' : 'Create account',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _authCard({required Widget child}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: child,
    );
  }

  Widget _modeButton({
    required String title,
    required bool selected,
    required VoidCallback? onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected
                ? colorScheme.onPrimary
                : colorScheme.onSurface.withValues(alpha: 0.7),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required TextInputType keyboardType,
    required bool enabled,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      textCapitalization: keyboardType == TextInputType.name
          ? TextCapitalization.words
          : TextCapitalization.none,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
      ),
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required bool hidden,
    required VoidCallback? onToggle,
    required String label,
    required bool enabled,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: hidden,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(hidden ? Icons.visibility : Icons.visibility_off),
        ),
      ),
    );
  }
}
