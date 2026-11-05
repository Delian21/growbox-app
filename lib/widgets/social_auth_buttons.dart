import 'package:flutter/material.dart';

import '../data/placeholder_images.dart';
import '../theme.dart';

/// Google and Apple sign-in, identical on login and sign-up.
///
/// One stacked, full-width pair: Google is a white button with the official
/// multicolour "G", Apple is black with the Apple mark, and both carry the
/// "Continue with …" wording the sign-up screen used. Brand colours are fixed
/// on purpose — these buttons are recognisable because they are white and
/// black, not because they follow the app's green.
class SocialAuthButtons extends StatelessWidget {
  final VoidCallback? onGoogle;
  final VoidCallback? onApple;

  /// Short-screen variant: 48px tall instead of the standard 52px.
  final bool compact;

  const SocialAuthButtons({
    super.key,
    this.onGoogle,
    this.onApple,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final height = compact ? 48.0 : AppSizing.buttonHeight(context);

    return Column(
      children: [
        _SocialButton(
          height: height,
          background: AppColors.white,
          foreground: AppColors.black,
          // A white button needs an edge on a white page.
          border: C.divider(context),
          label: 'Continue with Google',
          onTap: onGoogle,
          leading: Image.asset(
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
        ),
        const SizedBox(height: AppSpacing.sm + 2),
        _SocialButton(
          height: height,
          background: AppColors.black,
          foreground: AppColors.white,
          border: AppColors.black,
          label: 'Continue with Apple',
          onTap: onApple,
          leading: const Icon(Icons.apple, size: 24, color: AppColors.white),
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  final double height;
  final Color background;
  final Color foreground;
  final Color border;
  final String label;
  final Widget leading;
  final VoidCallback? onTap;

  const _SocialButton({
    required this.height,
    required this.background,
    required this.foreground,
    required this.border,
    required this.label,
    required this.leading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          elevation: 0,
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            leading,
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: foreground,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
