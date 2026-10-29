import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../widgets/app_snack_bar.dart';
import '../widgets/scaffold_with_nav.dart';
import '../widgets/app_button.dart';
import '../widgets/bottom_nav.dart';

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
            'Delete Account',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              color: C.textPrimary(context),
            ),
          ),
          content: Text(
            'Are you sure you want to delete your account?',
            style: GoogleFonts.inter(color: C.textSecondary(context)),
          ),
          actions: [
            AppButton(
              label: 'Cancel',
              variant: AppButtonVariant.text,
              onPressed: () => Navigator.pop(context),
            ),
            AppButton(
              label: 'Delete',
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
    return ScaffoldWithNav(
      activeIndex: 3,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(24, 22, 24, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.arrow_back,
                      size: 22,
                      color: C.textPrimary(context),
                    ),
                  ),
                  SizedBox(width: AppSpacing.md + 2),
                  Text(
                    'Right of Cancellation',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: C.textPrimary(context),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    26,
                    40,
                    26,
                    // Clears the floating nav bar.
                    BottomNavMetrics.contentInset(context),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Why do you want to delete?',
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
                          label: 'Delete',
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
