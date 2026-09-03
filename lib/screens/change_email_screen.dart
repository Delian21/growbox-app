import 'package:flutter/material.dart';
import '../theme.dart';
import '../data/mock_data.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enter your new email address.')));
      return;
    }
    if (!newEmail.contains('@') || !newEmail.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enter a valid email address.')));
      return;
    }
    if (newEmail == CustomerData.email) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enter a different email address.')));
      return;
    }
    setState(() => isLoading = true);
    try {
      CustomerData.email = newEmail;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Email address updated successfully.')));
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Something went wrong. Please try again.')));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding:   EdgeInsets.fromLTRB(21, 50, 21, 25),
              child: Row(
                children: [
                  GestureDetector(onTap: () => Navigator.of(context).pop(),
                    child:   Icon(Icons.arrow_back, size: 24, color: AppColors.info)),
                    SizedBox(width: AppSpacing.sm + 2),
                    Text('Change email',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: C.textPrimary(context))),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding:   EdgeInsets.symmetric(horizontal: 21),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      SizedBox(height: AppSpacing.xxl),
                      Text('Change your email address',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: C.textPrimary(context))),
                      SizedBox(height: AppSpacing.sm + 2),
                      Text('Enter the email address you want to use for your GROWBOX account.',
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
                          hintText: 'Enter new email address'),
                    ),
                      SizedBox(height: AppSpacing.md),
                      Text('You will need to verify your new email address.',
                      style: TextStyle(fontSize: 14, color: C.textMuted(context))),
                      Spacer(),
                    SizedBox(
                      width: double.infinity, height: AppSizing.buttonHeight(context),
                      child: ElevatedButton(
                        onPressed: isLoading ? null : updateEmail,
                        style: AppDecorations.primaryButtonStyle(),
                        child: isLoading
                            ?   SizedBox(width: 22, height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2, color: C.textPrimary(context)))
                            :   Text('Update email',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
