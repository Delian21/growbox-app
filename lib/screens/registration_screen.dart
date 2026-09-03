import 'package:flutter/material.dart';
import '../theme.dart';
import 'login_screen.dart';
import 'location_screen.dart';
import '../data/mock_data.dart';
import '../data/placeholder_images.dart';

// ---------------------------------------------------------------------------
// Single multi-step registration wizard (replaces 5 separate screens)
// ---------------------------------------------------------------------------
class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  /// White-art official logo — the green banner keeps its brand color in
  /// both light and dark themes, so the white art is always correct here.
  static String get logoUrl => PlaceholderImages.growboxLogo;

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Collected data across steps
  String _email = '';

  // Step 2 – email validation
  final TextEditingController _emailController = TextEditingController();

  // Step 3 – password
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Step 4 – name
  final TextEditingController _nameController = TextEditingController();

  // Step 5 – confirmation
  bool _isChecking = false;
  bool _isResending = false;

  static const int _totalSteps = 5;

  @override
  void dispose() {
    _pageController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // ── Navigation ──────────────────────────────────────────────────────────

  void _goToStep(int step) {
    if (step >= 0 && step < _totalSteps) {
      _pageController.animateToPage(
        step,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _next() => _goToStep(_currentStep + 1);
  void _back() => _goToStep(_currentStep - 1);

  // ── Step validation & continue handlers ──────────────────────────────────

  void _continueEmail() {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnack('Please enter your email address.');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      _showSnack('Please enter a valid email address.');
      return;
    }
    setState(() => _email = email);
    _next();
  }

  void _continuePassword() {
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;
    if (password.isEmpty) {
      _showSnack('Please create a password.');
      return;
    }
    if (password.length < 6) {
      _showSnack('Password must be at least 6 characters.');
      return;
    }
    if (confirm.isEmpty) {
      _showSnack('Please confirm your password.');
      return;
    }
    if (password != confirm) {
      _showSnack('Passwords do not match.');
      return;
    }
    _next();
  }

  void _continueName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnack('Please enter your name.');
      return;
    }

    // Save customer data and navigate to location screen
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      CustomerData.name = name;
      CustomerData.email = _email;
      if (mounted) Navigator.of(context).pop();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LocationScreen()),
      );
    } catch (error) {
      if (mounted) Navigator.of(context).pop();
      if (!mounted) return;
      _showSnack('Something went wrong. Please try again.');
    }
  }

  Future<void> _checkEmailConfirmation() async {
    setState(() => _isChecking = true);
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _isChecking = false);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LocationScreen()),
    );
  }

  Future<void> _resendConfirmationEmail() async {
    setState(() => _isResending = true);
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _isResending = false);
    _showSnack('Confirmation email sent again. Please check your inbox.');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Stack(
          children: [
            // ── Logo area (always visible, top portion) ──
            // NOTE: children carry stable keys so inserting/removing the
            // back button below never recreates the content-panel Element
            // (which would reset the PageView mid-animation).
            Positioned(
              key: const ValueKey('registration-logo'),
              left: 0,
              right: 0,
              top: 0,
              height: AppSizing.logoAreaHeight(context),
              child: Center(
                child: Image.asset(
                  // Square white-art brand mark: contain (never crop) and
                  // scale to ~70% of the banner height so it floats on the
                  // green instead of filling it like the old photo did.
                  RegistrationScreen.logoUrl,
                  width: AppSizing.logoAreaHeight(context) * 0.7,
                  height: AppSizing.logoAreaHeight(context) * 0.7,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Text(
                    'Growbox',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

            // ── Back button (visible on steps 2+) ──
            if (_currentStep > 0 && _currentStep < _totalSteps - 1)
              Positioned(
                key: const ValueKey('registration-back'),
                left: 12,
                top: 12,
                child: GestureDetector(
                  onTap: _back,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back_ios_new,
                        size: 18, color: AppColors.white),
                  ),
                ),
              ),

            // ── White content panel ──
            Positioned(
              key: const ValueKey('registration-panel'),
              left: 0,
              right: 0,
              top: AppSizing.logoAreaHeight(context) + 20,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: C.surface(context),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(AppRadii.lg),
                    topRight: Radius.circular(AppRadii.lg),
                  ),
                ),
                child: Column(
                  children: [
                    // ── Step indicator dots ──
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: _StepIndicator(
                          current: _currentStep, total: _totalSteps - 1),
                    ),

                    // ── PageView body ──
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        onPageChanged: (index) =>
                            setState(() => _currentStep = index),
                        children: [
                          _WelcomeStep(
                            onContinueWithEmail: _next,
                            onLogin: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const LoginScreen()),
                            ),
                            onSkip: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const LocationScreen()),
                            ),
                          ),
                          _EmailStep(
                            controller: _emailController,
                            onContinue: _continueEmail,
                          ),
                          _PasswordStep(
                            passwordController: _passwordController,
                            confirmPasswordController: _confirmPasswordController,
                            obscurePassword: _obscurePassword,
                            obscureConfirmPassword: _obscureConfirmPassword,
                            onTogglePassword: () =>
                                setState(() => _obscurePassword = !_obscurePassword),
                            onToggleConfirmPassword: () => setState(
                                () =>
                                    _obscureConfirmPassword = !_obscureConfirmPassword),
                            onContinue: _continuePassword,
                          ),
                          _NameStep(
                            controller: _nameController,
                            onContinue: _continueName,
                          ),
                          _EmailConfirmationStep(
                            email: _email,
                            isChecking: _isChecking,
                            isResending: _isResending,
                            onConfirm: _checkEmailConfirmation,
                            onResend: _resendConfirmationEmail,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Step indicator
// ═══════════════════════════════════════════════════════════════════════════

class _StepIndicator extends StatelessWidget {
  final int current;
  final int total;

  const _StepIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final isActive = i == current;
        final isPast = i < current;
        // In dark mode the brand primary is too dark to read on the
        // dark surface, so fall back to the brighter dark-theme green.
        final activeColor = C.isDark(context)
            ? AppDarkColors.primaryDark
            : AppColors.primary;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: isActive ? 28 : 10,
          height: 10,
          decoration: BoxDecoration(
            color: isActive
                ? activeColor
                : isPast
                    ? activeColor.withValues(alpha: 0.4)
                    : AppColors.grey300,
            borderRadius: BorderRadius.circular(5),
          ),
        );
      }),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Step 1 – Welcome
// ═══════════════════════════════════════════════════════════════════════════

class _WelcomeStep extends StatelessWidget {
  final VoidCallback onContinueWithEmail;
  final VoidCallback onLogin;
  final VoidCallback onSkip;

  const _WelcomeStep({
    required this.onContinueWithEmail,
    required this.onLogin,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final sectionSpacing = AppSizing.welcomeFontSize(context) * 0.9;

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.symmetric(
          horizontal: AppSizing.horizontalPadding(context)),
      child: Column(
        children: [
          SizedBox(height: sectionSpacing * 0.4),
          Text(
            'Welcome',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppSizing.welcomeFontSize(context),
              height: 1.0,
              fontWeight: FontWeight.bold,
              color: C.textPrimary(context),
            ),
          ),
          SizedBox(height: sectionSpacing),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm + 2),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: C.divider(context), width: 1)),
            ),
            child: Text(
              'Create your account',
              style: AppTypography.labelLarge.copyWith(color: C.textMuted(context)),
            ),
          ),
          SizedBox(height: sectionSpacing * 0.75),
          SizedBox(
            width: double.infinity,
            height: AppSizing.buttonHeightLarge(context),
            child: ElevatedButton(
              onPressed: onContinueWithEmail,
              style: AppDecorations.primaryButtonStyle(),
              child: const Text(
                'Continue with Email',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg - 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Already have an account? ',
                  style: AppTypography.bodyMedium.copyWith(color: C.textMuted(context))),
              GestureDetector(
                onTap: onLogin,
                child: Text('Log in',
                    style: AppTypography.labelMedium.copyWith(
                        color: C.isDark(context)
                            ? AppDarkColors.primaryDark
                            : AppColors.primary)),
              ),
            ],
          ),
          SizedBox(height: sectionSpacing),
          // Divider with 'or with' text
          Row(
            children: [
              Expanded(child: Divider(color: C.divider(context), thickness: 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('or with',
                  textAlign: TextAlign.center,
                  style: AppTypography.labelLarge.copyWith(color: C.textMuted(context))),
              ),
              Expanded(child: Divider(color: C.divider(context), thickness: 1)),
            ],
          ),
          const SizedBox(height: AppSpacing.md + 4),
          // Google button
          SizedBox(
            width: double.infinity,
            height: AppSizing.buttonHeight(context),
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.white,
                side: const BorderSide(color: AppColors.grey300, width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Official Google 'G' logo (bundled asset)
                  Image.asset(
                    PlaceholderImages.googleLogo,
                    width: 24,
                    height: 24,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.g_mobiledata,
                      size: 24,
                      color: AppColors.grey800,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Button background is always white, so the label must
                  // stay dark even in dark mode (C.textPrimary would be
                  // near-white there and vanish on the white button).
                  Text('Continue with Google',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.black),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md - 2),
          // Apple button
          SizedBox(
            width: double.infinity,
            height: AppSizing.buttonHeight(context),
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.black,
                side: BorderSide(color: C.textPrimary(context), width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.apple, size: 24, color: AppColors.white),
                  SizedBox(width: 12),
                  Text('Continue with Apple',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.white)),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child:          Text(
            'By continuing, you automatically\naccept our Terms & Conditions, Privacy Policy\nand Cookies Policy',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(color: C.textMuted(context)),
          ),
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: onSkip,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Skip',
                      style: AppTypography.labelLarge.copyWith(
                          color: C.textPrimary(context))),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios, size: 18, color: C.textPrimary(context)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Step 2 – Email
// ═══════════════════════════════════════════════════════════════════════════

class _EmailStep extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onContinue;

  const _EmailStep({required this.controller, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final bottomPadding = MediaQuery.viewInsetsOf(context).bottom;

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        AppSizing.horizontalPadding(context),
        24,
        AppSizing.horizontalPadding(context),
        24 + bottomPadding,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: (size.height * 0.35).clamp(200.0, double.infinity),
        ),
        child: IntrinsicHeight(
          child: Column(
            children: [
              Text(
                'Create your account',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppSizing.titleFontSize(context),
                  fontWeight: FontWeight.bold,
                  color: C.textPrimary(context),
                ),
              ),
              const SizedBox(height: AppSpacing.md + 2),
              Text(
                'Enter your email address to get started.',
                textAlign: TextAlign.center,
                style: AppTypography.subtitle
                    .copyWith(color: C.textSecondary(context)),
              ),
              SizedBox(height: size.height < 700 ? 28 : AppSpacing.huge),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Email address',
                    style: AppTypography.labelLarge
                        .copyWith(color: C.textPrimary(context))),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 64,
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  style: TextStyle(color: C.textPrimary(context)),
                  decoration: AppDecorations.inputDecoration(
                    hintText: 'Enter your email address',
                    context: context,
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: AppSizing.buttonHeight(context),
                child: ElevatedButton(
                  onPressed: onContinue,
                  style: AppDecorations.primaryButtonStyle(),
                  child:
                      const Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),              const SizedBox(height: AppSpacing.lg),
              Text(
                'By continuing, you automatically\naccept our Terms & Conditions, Privacy Policy\nand Cookies Policy',
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall
                    .copyWith(color: C.textMuted(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }


}

// ═══════════════════════════════════════════════════════════════════════════
// Step 3 – Password
// ═══════════════════════════════════════════════════════════════════════════

class _PasswordStep extends StatelessWidget {
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool obscurePassword;
  final bool obscureConfirmPassword;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirmPassword;
  final VoidCallback onContinue;

  const _PasswordStep({
    required this.passwordController,
    required this.confirmPasswordController,
    required this.obscurePassword,
    required this.obscureConfirmPassword,
    required this.onTogglePassword,
    required this.onToggleConfirmPassword,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final bottomPadding = MediaQuery.viewInsetsOf(context).bottom;

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        AppSizing.horizontalPadding(context),
        24,
        AppSizing.horizontalPadding(context),
        24 + bottomPadding,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: (size.height * 0.35).clamp(200.0, double.infinity),
        ),
        child: IntrinsicHeight(
          child: Column(
            children: [
              Text(
                'Create a password',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppSizing.titleFontSize(context),
                  fontWeight: FontWeight.bold,
                  color: C.textPrimary(context),
                ),
              ),
              const SizedBox(height: AppSpacing.md + 2),
              Text(
                'Create a password to keep your GROWBOX account secure.',
                textAlign: TextAlign.center,
                style: AppTypography.subtitle
                    .copyWith(color: C.textSecondary(context)),
              ),
              SizedBox(height: size.height < 700 ? 26 : 34),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Password',
                    style: AppTypography.labelLarge
                        .copyWith(color: C.textPrimary(context))),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 64,
                child: TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  keyboardType: TextInputType.visiblePassword,
                  textInputAction: TextInputAction.next,
                  style: TextStyle(color: C.textPrimary(context)),
                  decoration: AppDecorations.inputDecoration(
                    hintText: 'Enter your password',
                    context: context,
                  ).copyWith(
                    suffixIcon: IconButton(
                      onPressed: onTogglePassword,
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: C.textPrimary(context),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl - 2),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Confirm password',
                    style: AppTypography.labelLarge
                        .copyWith(color: C.textPrimary(context))),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 64,
                child: TextField(
                  controller: confirmPasswordController,
                  obscureText: obscureConfirmPassword,
                  keyboardType: TextInputType.visiblePassword,
                  textInputAction: TextInputAction.done,
                  style: TextStyle(color: C.textPrimary(context)),
                  decoration: AppDecorations.inputDecoration(
                    hintText: 'Re-enter your password',
                    context: context,
                  ).copyWith(
                    suffixIcon: IconButton(
                      onPressed: onToggleConfirmPassword,
                      icon: Icon(
                        obscureConfirmPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: C.textPrimary(context),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md - 2),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Password must be at least 6 characters.',
                  style: AppTypography.caption
                      .copyWith(color: C.textSecondary(context)),
                ),
              ),
              SizedBox(height: size.height < 700 ? 30 : 50),
              SizedBox(
                width: double.infinity,
                height: AppSizing.buttonHeight(context),
                child: ElevatedButton(
                  onPressed: onContinue,
                  style: AppDecorations.primaryButtonStyle(),
                  child: const Text('Continue',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),              const SizedBox(height: AppSpacing.lg),
              Text(
                'By continuing, you automatically\naccept our Terms & Conditions, Privacy Policy\nand Cookies Policy',
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall
                    .copyWith(color: C.textMuted(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }


}

// ═══════════════════════════════════════════════════════════════════════════
// Step 4 – Name
// ═══════════════════════════════════════════════════════════════════════════

class _NameStep extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onContinue;

  const _NameStep({required this.controller, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final bottomPadding = MediaQuery.viewInsetsOf(context).bottom;

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        AppSizing.horizontalPadding(context),
        24,
        AppSizing.horizontalPadding(context),
        24 + bottomPadding,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: (size.height * 0.35).clamp(200.0, double.infinity),
        ),
        child: IntrinsicHeight(
          child: Column(
            children: [
              Text(
                'What is your name?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppSizing.titleFontSize(context),
                  fontWeight: FontWeight.bold,
                  color: C.textPrimary(context),
                ),
              ),
              const SizedBox(height: AppSpacing.md + 2),
              Text(
                'Enter your full name to personalize your GROWBOX experience.',
                textAlign: TextAlign.center,
                style: AppTypography.subtitle
                    .copyWith(color: C.textSecondary(context)),
              ),
              SizedBox(height: size.height < 700 ? 26 : 34),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Full name',
                    style: AppTypography.labelLarge
                        .copyWith(color: C.textPrimary(context))),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 64,
                child: TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  style: TextStyle(color: C.textPrimary(context)),
                  decoration: AppDecorations.inputDecoration(
                    hintText: 'Enter your full name',
                    context: context,
                  ),
                ),
              ),
              SizedBox(height: size.height < 700 ? 30 : 50),
              SizedBox(
                width: double.infinity,
                height: AppSizing.buttonHeight(context),
                child: ElevatedButton(
                  onPressed: onContinue,
                  style: AppDecorations.primaryButtonStyle(),
                  child: const Text('Continue',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),              const SizedBox(height: AppSpacing.lg),
              Text(
                'By continuing, you automatically\naccept our Terms & Conditions, Privacy Policy\nand Cookies Policy',
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall
                    .copyWith(color: C.textMuted(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }


}

// ═══════════════════════════════════════════════════════════════════════════
// Step 5 – Email Confirmation
// ═══════════════════════════════════════════════════════════════════════════

class _EmailConfirmationStep extends StatelessWidget {
  final String email;
  final bool isChecking;
  final bool isResending;
  final VoidCallback onConfirm;
  final VoidCallback onResend;

  const _EmailConfirmationStep({
    required this.email,
    required this.isChecking,
    required this.isResending,
    required this.onConfirm,
    required this.onResend,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 0),
      child: Column(
        children: [
          Text(
            'Confirm your email',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppSizing.titleFontSize(context),
              fontWeight: FontWeight.bold,
              color: C.textPrimary(context),
            ),
          ),
          const SizedBox(height: AppSpacing.md + 2),
          Text(
            "We've sent a confirmation email to\n$email",
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 16, height: 1.5, color: C.textPrimary(context)),
          ),
          const SizedBox(height: AppSpacing.xxxl + 8),
          Icon(Icons.mark_email_read_outlined,
              size: 64,
              color: C.isDark(context)
                  ? AppDarkColors.primaryDark
                  : AppColors.primary),
          const SizedBox(height: AppSpacing.xxxl + 8),
          SizedBox(
            width: double.infinity,
            height: AppSizing.buttonHeight(context),
            child: ElevatedButton(
              onPressed: isChecking ? null : onConfirm,
              style: AppDecorations.primaryButtonStyle(),
              child: isChecking
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.black),
                    )
                  : const Text(
                      "I've confirmed my email",
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          GestureDetector(
            onTap: isResending ? null : onResend,
            child: Text(
              isResending ? 'Sending...' : 'Resend confirmation email',
              style: AppTypography.link.copyWith(color: C.accent(context)),
            ),
          ),
        ],
      ),
    );
  }
}
