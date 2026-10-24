import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../theme.dart';

/// Edits the customer's display name and email address.
///
/// Both are written through [CustomerData], which persists each setter, so the
/// screen owns no storage logic of its own.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameController =
      TextEditingController(text: CustomerData.name ?? '');
  late final TextEditingController _emailController =
      TextEditingController(text: CustomerData.email ?? '');

  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();

    if (name.isEmpty) {
      setState(() => _error = 'Enter the name we should greet you by.');
      return;
    }
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }

    CustomerData.name = name;
    CustomerData.email = email;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final hp = AppSizing.horizontalPadding(context);

    return Scaffold(
      backgroundColor: C.background(context),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(hp, AppSpacing.lg, hp, 0),
              child: Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.pop(context),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(
                        child: Icon(
                          Icons.arrow_back,
                          size: 24,
                          color: C.textPrimary(context),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Edit profile',
                      textAlign: TextAlign.center,
                      style: AppTypography.title
                          .copyWith(color: C.textPrimary(context)),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            // ── Fields ──────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  hp,
                  AppSpacing.xxl,
                  hp,
                  AppSpacing.xxxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Name',
                      style: AppTypography.labelSmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: C.textSecondary(context),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      style: AppTypography.bodyMedium
                          .copyWith(color: C.textPrimary(context)),
                      decoration: AppDecorations.inputDecoration(
                        hintText: 'Your name',
                        context: context,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Email',
                      style: AppTypography.labelSmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: C.textSecondary(context),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _save(),
                      style: AppTypography.bodyMedium
                          .copyWith(color: C.textPrimary(context)),
                      decoration: AppDecorations.inputDecoration(
                        hintText: 'you@example.com',
                        context: context,
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        _error!,
                        style: AppTypography.bodySmall
                            .copyWith(color: C.errorBright(context)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // ── Save ────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(hp, 0, hp, AppSpacing.xxl),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _save,
                child: Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: C.primary(context),
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(
                    'Save changes',
                    style: AppTypography.labelLarge.copyWith(
                      color: C.onPrimary(context),
                      fontWeight: FontWeight.w700,
                    ),
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

