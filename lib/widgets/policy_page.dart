import 'package:flutter/material.dart';

import '../theme.dart';

/// One titled block of a policy document.
class PolicySection {
  final String heading;
  final List<String> paragraphs;

  const PolicySection(this.heading, this.paragraphs);
}

/// Shared shell for the legal pages (Terms & Conditions, Privacy Policy).
///
/// Both pages are long, scrollable documents reached from checkout, so they get
/// the app's standard header (48×48 back target, 21px semibold title, hairline
/// divider) and a readable measure rather than a bespoke layout each.
class PolicyPage extends StatelessWidget {
  final String title;
  final String lastUpdated;
  final String intro;
  final List<PolicySection> sections;

  const PolicyPage({
    super.key,
    required this.title,
    required this.lastUpdated,
    required this.intro,
    required this.sections,
  });

  @override
  Widget build(BuildContext context) {
    final hp = AppSizing.horizontalPadding(context);

    return Scaffold(
      backgroundColor: C.background(context),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(hp, AppSpacing.md, hp, 0),
              child: Row(
                children: [
                  Semantics(
                    button: true,
                    label: 'Back',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.pop(context),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(Icons.arrow_back,
                            size: 24, color: C.textPrimary(context)),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTypography.title.copyWith(
                        fontSize: 21,
                        fontWeight: FontWeight.w600,
                        color: C.textPrimary(context),
                      ),
                    ),
                  ),
                  // Balances the back button so the title is centred.
                  const SizedBox(width: 48),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(height: 1, color: C.divider(context)),

            // ── Document ──────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                    hp, AppSpacing.xl, hp, AppSpacing.huge),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lastUpdated,
                      style: AppTypography.caption
                          .copyWith(color: C.textMuted(context)),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      intro,
                      style: AppTypography.bodyLarge.copyWith(
                        fontSize: 15,
                        height: 1.6,
                        color: C.textSecondary(context),
                      ),
                    ),
                    for (final section in sections) ...[
                      const SizedBox(height: AppSpacing.xxl),
                      Text(
                        section.heading,
                        style: AppTypography.title.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: C.textPrimary(context),
                        ),
                      ),
                      for (final paragraph in section.paragraphs) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          paragraph,
                          style: AppTypography.bodyMedium.copyWith(
                            fontSize: 15,
                            height: 1.6,
                            color: C.textSecondary(context),
                          ),
                        ),
                      ],
                    ],
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
