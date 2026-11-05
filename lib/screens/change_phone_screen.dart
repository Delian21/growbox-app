import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_header.dart';
import '../data/mock_data.dart';
import '../widgets/app_snack_bar.dart';

class ChangePhoneNumberScreen extends StatefulWidget {
    const ChangePhoneNumberScreen({super.key});

  @override
  State<ChangePhoneNumberScreen> createState() => _ChangePhoneNumberScreenState();
}

class _ChangePhoneNumberScreenState extends State<ChangePhoneNumberScreen> {
  final TextEditingController phoneController = TextEditingController();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    phoneController.text = CustomerData.phone ?? '';
  }

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }

  Future<void> updatePhoneNumber() async {
    final newPhone = phoneController.text.trim();
    if (newPhone.isEmpty) {
      showAppSnackBar(context, 'Please enter your new phone number.',
          isError: true);
      return;
    }
    if (newPhone.length < 7) {
      showAppSnackBar(context, 'Please enter a valid phone number.',
          isError: true);
      return;
    }
    setState(() => isLoading = true);
    try {
      CustomerData.phone = newPhone;
      if (!mounted) return;
      showAppSnackBar(context, 'Phone number updated successfully.');
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
            const AppHeader(title: 'Change phone number'),
            Expanded(
              child: Padding(
                padding:   EdgeInsets.symmetric(horizontal: 21),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      // Header names the page; keep only the explanatory line.
                      const SizedBox(height: AppSpacing.lg),
                      Text('Enter the phone number you want to use for your Growbox account.',
                      style: TextStyle(fontSize: 16, height: 1.5, color: C.textPrimary(context))),
                      SizedBox(height: 35),
                      Text('New phone number',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: C.textPrimary(context))),
                      SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      enabled: !isLoading,
                      decoration: AppDecorations.inputDecoration(
                        hintText: 'Enter new phone number',
                        context: context,
                      ),
                    ),
                      SizedBox(height: AppSpacing.md),
                      Text('You will need to verify your new phone number.',
                      style: TextStyle(fontSize: 14, color: C.textMuted(context))),
                      Spacer(),
                    SizedBox(
                      width: double.infinity, height: AppSizing.buttonHeight(context),
                      child: AppButton(
                        label: 'Update phone number',
                        onPressed: isLoading ? null : updatePhoneNumber,
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
