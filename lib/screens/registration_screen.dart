import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import '../theme.dart';
import 'cookies_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_screen.dart';
import 'login_screen.dart';
import '../data/mock_data.dart';
import '../data/placeholder_images.dart';
import '../data/session.dart';
import '../widgets/app_entry_gate.dart';
import '../widgets/app_snack_bar.dart';
import '../widgets/app_button.dart';
import '../widgets/social_auth_buttons.dart';

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

  /// Captured so [dispose] can restore the app's default chrome without
  /// touching Theme.of in a deactivated context.
  bool _isDark = false;

  /// Whether the overlay style has been applied for the current brightness.
  bool _chromeApplied = false;

  @override
  void initState() {
    super.initState();
    // Edge-to-edge: the system bars stop reserving opaque space, so the brand
    // green behind the body reaches the top (and bottom) of the screen.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_chromeApplied && isDark == _isDark) return;
    _isDark = isDark;
    _chromeApplied = true;
    // Transparent bars with light status icons. The bottom of this screen is
    // the light surface panel, so nav-bar icons follow the theme instead.
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: AppColors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark, // iOS: dark bg → light icons
      systemNavigationBarColor: AppColors.transparent,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
    ));
  }

  @override
  void dispose() {
    // Restore the system chrome to match the selected appearance after leaving
    // the branded welcome/signup surface.
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor:
          _isDark ? AppDarkColors.background : AppColors.background,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor:
          _isDark ? AppDarkColors.background : AppColors.background,
      systemNavigationBarIconBrightness:
          _isDark ? Brightness.light : Brightness.dark,
    ));
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
      await _enterApp(guest: false);
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
    await _enterApp(guest: false);
  }

  /// Signs the customer in and hands over to [AppEntryGate], which decides
  /// between location setup and Home and replaces the whole stack — Back can
  /// never walk back into the sign-up wizard.
  ///
  /// [guest] is the "Skip" path: a session with no email, so the next cold
  /// start does not throw the customer back to the welcome screen.
  Future<void> _enterApp({required bool guest}) async {
    if (guest) {
      await SessionStore.startGuest();
    } else {
      await SessionStore.start(email: _email);
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const AppEntryGate(minimumSplash: Duration.zero),
      ),
      (route) => false,
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
    showAppSnackBar(context, message);
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Short phones give the brand band less height so the welcome step's
    // content — the consent notice and Skip included — fits without scrolling.
    // Decided once here, above the SafeArea, and passed down: inside it the
    // consumed padding is zero, so the same question has a different answer.
    final compact = AppSizing.compactSignUp(context);
    final bandHeight = AppSizing.signUpLogoAreaHeight(context);
    final panelGap = AppSizing.signUpPanelGap(context);

    return Scaffold(
      // Pinned brand green, not C.primary(context): this band is the sign-up
      // hero and carries the white logo and white-on-green tagline, so it must
      // be the same forest green in light and dark mode. In dark mode the
      // theme-aware token lifted it to #7ED36B, which made the white artwork
      // unreadable (1.7:1) and the hero look mint instead of branded.
      backgroundColor: AppColors.brand,
      resizeToAvoidBottomInset: false,
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
              height: bandHeight,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      // Square white-art brand mark: contain (never crop) and
                      // scale to ~80% of the banner height so it floats on the
                      // green instead of filling it like the old photo did.
                      RegistrationScreen.logoUrl,
                      width: bandHeight * 0.8,
                      height: bandHeight * 0.8,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Text(
                        'Growbox',
                        style: TextStyle(
                          // White on [AppColors.brand] in every theme; the
                          // theme-aware equivalent turns near-black in dark
                          // mode for the lifted green and would vanish here.
                          color: AppColors.onBrand,
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Every day is a market day',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.onBrand.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
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
                      color: AppColors.white24,
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
              top: bandHeight + panelGap,
              bottom: MediaQuery.viewInsetsOf(context).bottom,
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
                    // Step dots removed: the wizard advances only through
                    // Continue, so a carousel-style indicator was misleading.
                    SizedBox(
                      height: compact ? 6 : AppSpacing.xl,
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
                            compact: compact,
                            onContinue: _next,
                            onLogin: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const LoginScreen()),
                            ),
                            onSkip: () => _enterApp(guest: true),
                          ),
                          _EmailStep(controller: _emailController),
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
                          ),
                          _NameStep(controller: _nameController),
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
                    // Steps 2 and up keep the pinned footer. The welcome step
                    // puts its own "Continue with Email" inside the scrolling
                    // content, directly under the heading, so it is not
                    // separated from the words it continues from.
                    if (_currentStep >= 1 && _currentStep <= 3)
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            AppSizing.horizontalPadding(context),
                            AppSpacing.sm,
                            AppSizing.horizontalPadding(context),
                            AppSpacing.md,
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            height: AppSizing.buttonHeight(context),
                            child: AppButton(
                              label: _currentStep == 0
                                  ? 'Continue with Email'
                                  : 'Continue',
                              onPressed: switch (_currentStep) {
                                0 => _next,
                                1 => _continueEmail,
                                2 => _continuePassword,
                                _ => _continueName,
                              },
                              expand: true,
                              height: AppSizing.buttonHeight(context),
                              radius: AppRadii.pill,
                            ),
                          ),
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
// Step 1 – Welcome
// ═══════════════════════════════════════════════════════════════════════════

class _WelcomeStep extends StatelessWidget {
  /// Whether this is a short phone: tighter gaps and buttons, same content.
  final bool compact;
  final VoidCallback onContinue;
  final VoidCallback onLogin;
  final VoidCallback onSkip;

  const _WelcomeStep({
    required this.compact,
    required this.onContinue,
    required this.onLogin,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    // One column, in the order the decision is made: heading, primary action,
    // consent, then the alternatives, then the escape hatch back to logging in.
    // Short phones only shrink the gaps and buttons — the order never changes —
    // and the whole column scrolls, so nothing is unreachable at 360×640.
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        AppSizing.horizontalPadding(context),
        AppSpacing.xs,
        AppSizing.horizontalPadding(context),
        AppSpacing.lg,
      ),
      child: Column(
        children: [
          // Guest shortcut, kept out of the sign-up flow's own order (and out
          // of the scroll's tail) so "Log in" can stay the last row.
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: onSkip,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Skip',
                        style: AppTypography.labelLarge
                            .copyWith(color: C.textPrimary(context))),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios,
                        size: 16, color: C.textPrimary(context)),
                  ],
                ),
              ),
            ),
          ),
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
          SizedBox(height: compact ? 4 : AppSpacing.sm),
          // Plain subtitle — the rule that used to underline this line made
          // a static sentence read like a text field.
          SizedBox(
            width: double.infinity,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.sm + 2,
                vertical: compact ? 2 : 4,
              ),
              child: Text(
                'Create your account',
                style: AppTypography.labelLarge
                    .copyWith(color: C.textMuted(context)),
              ),
            ),
          ),
          SizedBox(height: compact ? 8 : AppSpacing.sm + 2),
          // The primary action, directly under the heading it acts on: one
          // full-width button, the same widget the other steps pin.
          SizedBox(
            width: double.infinity,
            height: AppSizing.buttonHeight(context),
            child: AppButton(
              label: 'Continue with Email',
              onPressed: onContinue,
              expand: true,
              height: AppSizing.buttonHeight(context),
              radius: AppRadii.pill,
            ),
          ),
          // Consent sits directly under the action it accompanies.
          SizedBox(height: compact ? 10 : AppSpacing.sm + 2),
          _LegalNotice(compact: compact),
          SizedBox(height: compact ? 14 : AppSpacing.lg),
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
          SizedBox(height: compact ? 12 : AppSpacing.md + 4),
          // The same stacked Google/Apple pair the login screen shows.
          SocialAuthButtons(compact: compact),
          SizedBox(height: compact ? 14 : AppSpacing.lg),
          // Log in is the last row: the customer who already has an account
          // reaches it after the alternatives, not before them.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Already have an account? ',
                  style: AppTypography.bodyMedium
                      .copyWith(color: C.textMuted(context))),
              GestureDetector(
                onTap: onLogin,
                child: Text('Log in',
                    style: AppTypography.labelMedium
                        .copyWith(color: C.primary(context))),
              ),
            ],
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

  const _EmailStep({required this.controller});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        AppSizing.horizontalPadding(context),
        24,
        AppSizing.horizontalPadding(context),
        24,
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

  const _PasswordStep({
    required this.passwordController,
    required this.confirmPasswordController,
    required this.obscurePassword,
    required this.obscureConfirmPassword,
    required this.onTogglePassword,
    required this.onToggleConfirmPassword,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        AppSizing.horizontalPadding(context),
        24,
        AppSizing.horizontalPadding(context),
        24,
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
                'Create a password to keep your Growbox account secure.',
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
              const SizedBox(height: AppSpacing.md),
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

  const _NameStep({required this.controller});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        AppSizing.horizontalPadding(context),
        24,
        AppSizing.horizontalPadding(context),
        24,
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
                'Enter your full name to personalize your Growbox experience.',
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
              const SizedBox(height: AppSpacing.md),
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
              color: C.primary(context)),
          const SizedBox(height: AppSpacing.xxxl + 8),
          SizedBox(
            width: double.infinity,
            height: AppSizing.buttonHeight(context),
            child: AppButton(
              label: "I've confirmed my email",
              onPressed: isChecking ? null : onConfirm,
              expand: true,
              height: AppSizing.buttonHeight(context),
              radius: AppRadii.pill,
              child: isChecking
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
          ),
          const SizedBox(height: AppSpacing.lg),
          GestureDetector(
            onTap: isResending ? null : onResend,
            child: Text(
              isResending ? 'Sending...' : 'Resend confirmation email',
              style: AppTypography.link.copyWith(color: C.accentOrange(context)),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Legal notice – shared by every step that ends in a CTA
// ═══════════════════════════════════════════════════════════════════════════

/// "By continuing, you agree to our …" — the same sentence checkout shows
/// before an order, so sign-up and checkout accept the same three documents in
/// the same words: [TermsScreen], [PrivacyPolicyScreen] and [CookiesScreen] are
/// the links into the real documents.
///
/// Shown once, on the welcome step: that is where the account is actually
/// created (including the Google and Apple buttons just above this notice), so
/// the email, password and name steps are one continuous form the user already
/// agreed to enter and repeat nothing here. A [TextSpan] recognizer is not
/// owned by the framework, so it needs a [State] that can dispose it.
class _LegalNotice extends StatefulWidget {
  /// Tighter line height on short phones, where the whole step must fit.
  final bool compact;

  const _LegalNotice({required this.compact});

  @override
  State<_LegalNotice> createState() => _LegalNoticeState();
}

class _LegalNoticeState extends State<_LegalNotice> {
  late final TapGestureRecognizer _terms;
  late final TapGestureRecognizer _privacy;
  late final TapGestureRecognizer _cookies;

  @override
  void initState() {
    super.initState();
    _terms = TapGestureRecognizer()..onTap = () => _open(const TermsScreen());
    _privacy = TapGestureRecognizer()
      ..onTap = () => _open(const PrivacyPolicyScreen());
    _cookies = TapGestureRecognizer()
      ..onTap = () => _open(const CookiesScreen());
  }

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    _cookies.dispose();
    super.dispose();
  }

  void _open(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    // Shorter leading on short phones: two lines instead of three eats into the
    // step's height budget, and the sentence still reads as one block.
    final body = AppTypography.bodySmall.copyWith(
      color: C.textSecondary(context),
      height: widget.compact ? 1.15 : null,
    );
    final link = body.copyWith(
      color: C.primary(context),
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: C.primary(context),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text.rich(
        TextSpan(
          children: [
            const TextSpan(
                text: 'By continuing, you agree to our '),
            TextSpan(
                text: 'Terms & Conditions', recognizer: _terms, style: link),
            const TextSpan(text: ', '),
            TextSpan(
                text: 'Privacy Policy', recognizer: _privacy, style: link),
            const TextSpan(text: ' and '),
            TextSpan(
                text: 'Cookies Policy', recognizer: _cookies, style: link),
            const TextSpan(text: '.'),
          ],
        ),
        textAlign: TextAlign.center,
        style: body,
      ),
    );
  }
}
