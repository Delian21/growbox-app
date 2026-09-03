import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import 'login_screen.dart';

/// Multi-step forgot password flow.
///
/// Step 1: Enter email address → sends a mock reset code.
/// Step 2: Enter the 6-digit verification code.
/// Step 3: Create and confirm a new password.
/// Done: Success message → navigate back to login.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Step 1 – email
  final TextEditingController _emailController = TextEditingController();

  // Step 2 – verification code
  final List<TextEditingController> _codeControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _codeFocusNodes =
      List.generate(6, (_) => FocusNode());
  int _resendSeconds = 60;
  Timer? _resendTimer;

  // Step 3 – new password
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  // Loading states
  bool _isSendingCode = false;
  bool _isVerifying = false;
  bool _isResetting = false;

  static const int _totalSteps = 3;

  @override
  void initState() {
    super.initState();
    // Auto-focus the email field.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FocusScope.of(context).requestFocus(FocusNode());
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _emailController.dispose();
    for (final c in _codeControllers) {
      c.dispose();
    }
    for (final f in _codeFocusNodes) {
      f.dispose();
    }
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  // ── Navigation ─────────────────────────────────────────────────────

  void _goToStep(int step) {
    if (step >= 0 && step < _totalSteps) {
      _pageController.animateToPage(
        step,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // ── Step 1: Send reset code ────────────────────────────────────────

  Future<void> _sendResetCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnack('Please enter your email address.');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      _showSnack('Please enter a valid email address.');
      return;
    }

    setState(() => _isSendingCode = true);
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _isSendingCode = false);

    _showSnack('Reset code sent to $email');
    _startResendTimer();
    _goToStep(1);

    // Auto-focus first code field after transition.
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) _codeFocusNodes[0].requestFocus();
  }

  // ── Step 2: Verify code ────────────────────────────────────────────

  String get _code => _codeControllers.map((c) => c.text).join();

  Future<void> _verifyCode() async {
    if (_code.length < 6) {
      _showSnack('Please enter the full 6-digit code.');
      return;
    }

    setState(() => _isVerifying = true);
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _isVerifying = false);

    _showSnack('Code verified!');
    _goToStep(2);
  }

  void _startResendTimer() {
    _resendSeconds = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendSeconds--;
        if (_resendSeconds <= 0) {
          timer.cancel();
          _resendSeconds = 0;
        }
      });
    });
  }

  Future<void> _resendCode() async {
    if (_resendSeconds > 0) return;
    _showSnack('New code sent!');
    _startResendTimer();
  }

  // ── Step 3: Reset password ─────────────────────────────────────────

  Future<void> _resetPassword() async {
    final password = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;

    if (password.isEmpty) {
      _showSnack('Please enter a new password.');
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

    setState(() => _isResetting = true);
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _isResetting = false);

    _showSuccessAndNavigate();
  }

  void _showSuccessAndNavigate() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  size: 32,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'Password Reset!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Your password has been updated successfully. You can now log in with your new password.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.grey700,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => const LoginScreen(),
                      ),
                      (route) => false,
                    );
                  },
                  style: AppDecorations.primaryButtonStyle(),
                  child: const Text(
                    'Back to Login',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _goToStep(_currentStep - 1),
                      child: const SizedBox(
                        width: 40,
                        height: 40,
                        child: Center(
                          child: Icon(
                            Icons.chevron_left,
                            size: 28,
                            color: AppColors.info,
                          ),
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 40),
                  Expanded(
                    child: Text(
                      'Reset Password',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: C.textPrimary(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            // ── Step indicator ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: _buildStepIndicator(),
            ),

            // ── Page content ──────────────────────────────────────
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentStep = i),
                children: [
                  _buildEmailStep(),
                  _buildCodeStep(),
                  _buildNewPasswordStep(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step indicator ──────────────────────────────────────────────────

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalSteps, (i) {
        final isActive = i == _currentStep;
        final isDone = i < _currentStep;
        return Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: isActive ? 32 : 10,
              height: 10,
              decoration: BoxDecoration(
                color: isDone
                    ? AppColors.primaryDark
                    : isActive
                        ? AppColors.primary
                        : AppColors.grey300,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            if (i < _totalSteps - 1) const SizedBox(width: 8),
          ],
        );
      }),
    );
  }

  // ── Step 1: Email ──────────────────────────────────────────────────

  Widget _buildEmailStep() {
    final bottomPadding = MediaQuery.viewInsetsOf(context).bottom;

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lock_reset,
            size: 48,
            color: AppColors.primary,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Forgot your password?',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: C.textPrimary(context),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            "No worries! Enter your email address and we'll send you a verification code to reset your password.",
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppColors.grey700,
            ),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          Text(
            'Email address',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: C.textPrimary(context),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _sendResetCode(),
            decoration: AppDecorations.inputDecoration(
              hintText: 'Enter your email address',
              context: context,
            ),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          SizedBox(
            width: double.infinity,
            height: AppSizing.buttonHeight(context),
            child: ElevatedButton(
              onPressed: _isSendingCode ? null : _sendResetCode,
              style: AppDecorations.primaryButtonStyle(context: context),
              child: _isSendingCode
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.black,
                      ),
                    )
                  : const Text(
                      'Send Reset Code',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 2: Verification code ──────────────────────────────────────

  Widget _buildCodeStep() {
    final bottomPadding = MediaQuery.viewInsetsOf(context).bottom;
    final email = _emailController.text.trim();

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.mail_outline,
            size: 48,
            color: AppColors.primary,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Check your email',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: C.textPrimary(context),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            "We've sent a 6-digit code to\n$email",
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppColors.grey700,
            ),
          ),
          const SizedBox(height: AppSpacing.xxxl),

          // 6-digit code fields
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (i) {
              return SizedBox(
                width: 48,
                height: 56,
                child: TextField(
                  controller: _codeControllers[i],
                  focusNode: _codeFocusNodes[i],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: C.textPrimary(context),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: C.surfaceLight(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                      borderSide: BorderSide(color: C.divider(context)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                      borderSide: BorderSide(color: C.divider(context)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                  ),
                  onChanged: (value) {
                    if (value.isNotEmpty && i < 5) {
                      _codeFocusNodes[i + 1].requestFocus();
                    } else if (value.isEmpty && i > 0) {
                      _codeFocusNodes[i - 1].requestFocus();
                    }
                    setState(() {});
                  },
                ),
              );
            }),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Resend
          Center(
            child: GestureDetector(
              onTap: _resendCode,
              child: Text(
                _resendSeconds > 0
                    ? 'Resend code in ${_resendSeconds}s'
                    : 'Resend code',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _resendSeconds > 0
                      ? AppColors.grey500
                      : AppColors.primaryDark,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          SizedBox(
            width: double.infinity,
            height: AppSizing.buttonHeight(context),
            child: ElevatedButton(
              onPressed: _isVerifying ? null : _verifyCode,
              style: AppDecorations.primaryButtonStyle(context: context),
              child: _isVerifying
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.black,
                      ),
                    )
                  : const Text(
                      'Verify Code',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 3: New password ───────────────────────────────────────────

  Widget _buildNewPasswordStep() {
    final bottomPadding = MediaQuery.viewInsetsOf(context).bottom;

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lock_outline,
            size: 48,
            color: AppColors.primary,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Create new password',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: C.textPrimary(context),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Your new password must be at least 6 characters long.',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppColors.grey700,
            ),
          ),
          const SizedBox(height: AppSpacing.xxxl),

          // New password
          Text(
            'New password',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: C.textPrimary(context),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _newPasswordController,
            obscureText: _obscureNew,
            textInputAction: TextInputAction.next,
            decoration: AppDecorations.inputDecoration(
              hintText: 'Enter new password',
              context: context,
            ).copyWith(
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _obscureNew = !_obscureNew),
                icon: Icon(
                  _obscureNew
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.grey600,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),

          // Confirm password
          Text(
            'Confirm password',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: C.textPrimary(context),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirm,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _resetPassword(),
            decoration: AppDecorations.inputDecoration(
              hintText: 'Re-enter new password',
              context: context,
            ).copyWith(
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.grey600,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Password strength hint
          Row(
            children: [
              Icon(
                _newPasswordController.text.length >= 6
                    ? Icons.check_circle
                    : Icons.info_outline,
                size: 14,
                color: _newPasswordController.text.length >= 6
                    ? AppColors.success
                    : AppColors.grey500,
              ),
              const SizedBox(width: 6),
              Text(
                'At least 6 characters',
                style: TextStyle(
                  fontSize: 12,
                  color: _newPasswordController.text.length >= 6
                      ? AppColors.success
                      : AppColors.grey500,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxxl),
          SizedBox(
            width: double.infinity,
            height: AppSizing.buttonHeight(context),
            child: ElevatedButton(
              onPressed: _isResetting ? null : _resetPassword,
              style: AppDecorations.primaryButtonStyle(context: context),
              child: _isResetting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.black,
                      ),
                    )
                  : const Text(
                      'Reset Password',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
