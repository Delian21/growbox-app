import 'package:flutter/material.dart';
import '../theme.dart';
import '../data/placeholder_images.dart';
import '../widgets/app_snack_bar.dart';
import '../widgets/app_button.dart';
import '../widgets/social_auth_buttons.dart';
import '../widgets/app_entry_gate.dart';
import '../data/session.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.notice});

  /// Optional banner, e.g. the "signed out after 30 minutes away" message the
  /// away-timer hands over when it drops an expired session.
  final String? notice;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;
    if (email.isEmpty) {
      showAppSnackBar(context, 'Please enter your email address.', isError: true);
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      showAppSnackBar(context, 'Please enter a valid email address.',
          isError: true);
      return;
    }
    if (password.isEmpty) {
      showAppSnackBar(context, 'Please enter your password.', isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      // Identity only — the mock backend has no password to remember.
      await SessionStore.start(email: email);
      if (!mounted) return;
      showAppSnackBar(context, 'Welcome back to Growbox!');
      // Through the gate, so a customer who has not set an address yet is
      // asked for one, and the stack forgets this form (Back cannot return
      // to a signed-in user's login screen). Zero dwell: no second splash.
      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  const AppEntryGate(minimumSplash: Duration.zero)),
          (route) => false);
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(context, 'Something went wrong. Please try again.',
          isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hp = AppSizing.horizontalPadding(context);

    return Scaffold(
      backgroundColor: C.background(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(hp, 40, hp, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Logo ──────────────────────────────────────
              // Official Growbox logo. The surface behind it follows the
              // theme (white in light mode, near-black in dark mode), so the
              // matching logo variant is picked automatically: dark art on
              // light surfaces, white art on dark surfaces.
              Center(
                child: Image.asset(
                  Theme.of(context).brightness == Brightness.dark
                      ? PlaceholderImages.growboxLogo
                      : PlaceholderImages.growboxLogoLight,
                  width: 128,
                  height: 128,
                  fit: BoxFit.contain,
                  // Fallback: keep the old eco tile if the asset ever fails.
                  errorBuilder: (_, _, _) => Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: C.primary(context),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.eco,
                      size: 32,
                      color: C.onPrimary(context),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // ── Title ─────────────────────────────────────
              Text(
                'Welcome back',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: C.textPrimary(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in to your Growbox account',
                style: TextStyle(
                  fontSize: 15,
                  color: C.textMuted(context),
                ),
              ),
              // Shown when the away-timer dropped an expired session, so the
              // customer knows why they are back on this form.
              if (widget.notice != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: C.warningSoft(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lock_clock_outlined,
                          size: 18, color: C.onWarningSoft(context)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.notice!,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            color: C.onWarningSoft(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 40),

              // ── Email Field ───────────────────────────────
              _buildFieldLabel('Email address'),
              const SizedBox(height: 8),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                style: TextStyle(color: C.textPrimary(context)),
                decoration: InputDecoration(
                  hintText: 'Enter your email address',
                  hintStyle: TextStyle(color: C.textMuted(context)),
                  prefixIcon: Icon(Icons.email_outlined,
                      size: 20, color: C.textMuted(context)),
                  filled: true,
                  fillColor: C.surface(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: C.divider(context), width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: C.primary(context), width: 1.5),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
              const SizedBox(height: 20),

              // ── Password Field ────────────────────────────
              _buildFieldLabel('Password'),
              const SizedBox(height: 8),
              TextField(
                controller: passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                style: TextStyle(color: C.textPrimary(context)),
                decoration: InputDecoration(
                  hintText: 'Enter your password',
                  hintStyle: TextStyle(color: C.textMuted(context)),
                  prefixIcon: Icon(Icons.lock_outline,
                      size: 20, color: C.textMuted(context)),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: C.textMuted(context),
                    ),
                  ),
                  filled: true,
                  fillColor: C.surface(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: C.divider(context), width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: C.primary(context), width: 1.5),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
              const SizedBox(height: 12),

              // ── Forgot Password ───────────────────────────
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ForgotPasswordScreen()),
                  ),
                  child: Text(
                    'Forgot password?',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: C.primary(context),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // ── Login Button ──────────────────────────────
              AppButton(
                label: 'Log in',
                onPressed: _isLoading ? null : _login,
                expand: true,
                height: 52,
                child: _isLoading
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: C.onPrimary(context),
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 24),

              // ── Divider ───────────────────────────────────
              Row(
                children: [
                  Expanded(child: Divider(color: C.divider(context))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'or continue with',
                      style: TextStyle(
                        fontSize: 12,
                        color: C.textMuted(context),
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: C.divider(context))),
                ],
              ),
              const SizedBox(height: 24),

              // ── Social login ──────────────────────────────
              // The same stacked Google/Apple pair the sign-up screen shows.
              SocialAuthButtons(onGoogle: () {}, onApple: () {}),
              const SizedBox(height: 32),

              // ── Sign up link ──────────────────────────────
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: TextStyle(
                        fontSize: 14,
                        color: C.textMuted(context),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Text(
                        'Sign up',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: C.primary(context),
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
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: C.textPrimary(context),
      ),
    );
  }
}
