import 'package:flutter/material.dart';
import '../theme.dart';
import '../data/mock_data.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enter your new phone number.')));
      return;
    }
    if (newPhone.length < 7) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enter a valid phone number.')));
      return;
    }
    setState(() => isLoading = true);
    try {
      CustomerData.phone = newPhone;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Phone number updated successfully.')));
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
                    Text('Change phone number',
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
                      Text('Change your phone number',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: C.textPrimary(context))),
                      SizedBox(height: AppSpacing.sm + 2),
                      Text('Enter the phone number you want to use for your GROWBOX account.',
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
                          hintText: 'Enter new phone number'),
                    ),
                      SizedBox(height: AppSpacing.md),
                      Text('You will need to verify your new phone number.',
                      style: TextStyle(fontSize: 14, color: C.textMuted(context))),
                      Spacer(),
                    SizedBox(
                      width: double.infinity, height: AppSizing.buttonHeight(context),
                      child: ElevatedButton(
                        onPressed: isLoading ? null : updatePhoneNumber,
                        style: AppDecorations.primaryButtonStyle(),
                        child: isLoading
                            ?   SizedBox(width: 22, height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2, color: C.textPrimary(context)))
                            :   Text('Update phone number',
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
