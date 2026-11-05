import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../widgets/app_snack_bar.dart';
import '../widgets/app_header.dart';
import '../widgets/app_button.dart';

class DeactivationScreen extends StatefulWidget {
  const DeactivationScreen({super.key});

  @override
  State<DeactivationScreen> createState() => _DeactivationScreenState();
}

class _DeactivationScreenState extends State<DeactivationScreen> {
  final TextEditingController _reasonController = TextEditingController();
  bool _hasReason = false;

  @override
  void initState() {
    super.initState();
    _reasonController.addListener(() {
      setState(() => _hasReason = _reasonController.text.trim().isNotEmpty);
    });
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _deleteAccount() {
    if (!_hasReason) return;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: C.surface(context),
          title: Text(
            'Delete account',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              color: C.textPrimary(context),
            ),
          ),
          content: Text(
            'Send a deletion request for this account?',
            style: GoogleFonts.inter(color: C.textSecondary(context)),
          ),
          actions: [
            AppButton(
              label: 'Cancel',
              variant: AppButtonVariant.text,
              onPressed: () => Navigator.pop(context),
            ),
            AppButton(
              label: 'Request deletion',
              variant: AppButtonVariant.destructive,
              onPressed: () {
                Navigator.pop(context);
                showAppSnackBar(context, 'Account deletion request submitted.');
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Pushed from Account: no bottom nav. The title names the action the
    // screen actually performs.
    return Scaffold(
      backgroundColor: C.background(context),
      body: SafeArea(
        child: Column(
          children: [
            const AppHeader(title: 'Delete account'),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    26,
                    24,
                    26,
                    AppSpacing.xxl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Why do you want to delete your account?',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: C.textPrimary(context),
                        ),
                      ),
                      SizedBox(height: 31),
                      TextField(
                        controller: _reasonController,
                        maxLines: 4,
                        textAlignVertical: TextAlignVertical.top,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: C.textPrimary(context),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Your reason',
                          hintStyle: GoogleFonts.inter(
                            fontSize: 11,
                            color: C.textMuted(context),
                          ),
                          contentPadding: EdgeInsets.fromLTRB(8, 10, 8, 10),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide(
                              color: C.textMuted(context),
                              width: 0.8,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide(
                              color: C.textMuted(context),
                              width: 0.9,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 29),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: AppButton(
                          label: 'Request deletion',
                          onPressed: _hasReason ? _deleteAccount : null,
                          variant: AppButtonVariant.destructive,
                          expand: true,
                          height: 44,
                          radius: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
