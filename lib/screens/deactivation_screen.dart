import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../widgets/scaffold_with_nav.dart';

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
          title: Text('Delete Account', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: C.textPrimary(context))),
          content: Text('Are you sure you want to delete your account?', style: GoogleFonts.inter(color: C.textSecondary(context))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.inter(color: C.textMuted(context)))),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Account deletion request submitted.')),
                );
              },
              child: Text('Delete', style: GoogleFonts.poppins(color: AppColors.error, fontWeight: FontWeight.w600)),
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
                    child: Icon(Icons.arrow_back, size: 22, color: C.textPrimary(context)),
                  ),
                  SizedBox(width: AppSpacing.md + 2),
                  Text('Right of Cancellation',
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: C.textPrimary(context))),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(26, 40, 26, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Why do you want to delete?',
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: C.textPrimary(context))),
                      SizedBox(height: 31),
                      TextField(
                        controller: _reasonController,
                        maxLines: 4,
                        textAlignVertical: TextAlignVertical.top,
                        style: GoogleFonts.inter(fontSize: 12, color: C.textPrimary(context)),
                        decoration: InputDecoration(
                          hintText: 'Your reason',
                          hintStyle: GoogleFonts.inter(fontSize: 11, color: C.textMuted(context)),
                          contentPadding: EdgeInsets.fromLTRB(8, 10, 8, 10),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide(color: C.textMuted(context), width: 0.8)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide(color: C.textMuted(context), width: 0.9)),
                        ),
                      ),
                      SizedBox(height: 29),
                      SizedBox(
                        width: double.infinity, height: 44,
                        child: ElevatedButton(
                          onPressed: _hasReason ? _deleteAccount : null,
                          style: ElevatedButton.styleFrom(
                            elevation: 0, padding: EdgeInsets.zero,
                            backgroundColor: _hasReason ? C.textPrimary(context) : Color(0xFFE2E2E2),
                            disabledBackgroundColor: Color(0xFFE2E2E2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                          child: Text('Delete',
                            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600,
                              color: _hasReason ? AppColors.white : Color(0xFF777777))),
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
