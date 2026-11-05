import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_header.dart';
import '../data/mock_data.dart';
import '../widgets/app_snack_bar.dart';

class ChangeEmailScreen extends StatefulWidget {
    const ChangeEmailScreen({super.key});

  @override
  State<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends State<ChangeEmailScreen> {
  final TextEditingController emailController = TextEditingController();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    emailController.text = CustomerData.email ?? '';
  }

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  Future<void> updateEmail() async {
    final newEmail = emailController.text.trim();
    if (newEmail.isEmpty) {
      showAppSnackBar(context, 'Please enter your new email address.',
          isError: true);
      return;
    }
    if (!newEmail.contains('@') || !newEmail.contains('.')) {
      showAppSnackBar(context, 'Please enter a valid email address.',
          isError: true);
      return;
    }
    if (newEmail == CustomerData.email) {
      showAppSnackBar(context, 'Please enter a different email address.',
          isError: true);
      return;
    }
    setState(() => isLoading = true);
    try {
      CustomerData.email = newEmail;
      if (!mounted) return;
      showAppSnackBar(context, 'Email address updated successfully.');
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, 'Something went wrong. Please try again.',
          isError: true);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.background(context),
      body: SafeArea(
        child: Column(
          children: [
            const AppHeader(title: 'Change email'),
            Expanded(
              child: Padding(
                padding:   EdgeInsets.symmetric(horizontal: 21),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      // The header already names the page; the body opens with
                      // the one sentence that explains what to do.
                      const SizedBox(height: AppSpacing.lg),
                      Text('Enter the email address you want to use for your Growbox account.',
                      style: TextStyle(fontSize: 16, height: 1.5, color: C.textPrimary(context))),
                      SizedBox(height: 35),
                      Text('New email address',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: C.textPrimary(context))),
                      SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      enabled: !isLoading,
                      decoration: AppDecorations.inputDecoration(
                        hintText: 'Enter new email address',
                        context: context,
                      ),
                    ),
                      SizedBox(height: AppSpacing.md),
                      Text('You will need to verify your new email address.',
                      style: TextStyle(fontSize: 14, color: C.textMuted(context))),
                      Spacer(),
                    SizedBox(
                      width: double.infinity, height: AppSizing.buttonHeight(context),
                      child: AppButton(
                        label: 'Update email',
                        onPressed: isLoading ? null : updateEmail,
                        expand: true,
                        height: AppSizing.buttonHeight(context),
                        radius: AppRadii.pill,
                        child: isLoading
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: C.textMuted(context),
                                ),
                              )
                            : null,
                      ),
                    ),
                      SizedBox(height: AppSpacing.xxl),
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
