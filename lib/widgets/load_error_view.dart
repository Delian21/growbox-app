import 'package:flutter/material.dart';

import 'status_view.dart';

/// The one failed-load state, so every list fails the same way.
///
/// [title] names what could not load ("Couldn't load vendors"); the body and
/// the retry label are fixed, because the remedy is the same everywhere: check
/// the connection and run the call again.
class LoadErrorView extends StatelessWidget {
  const LoadErrorView({
    super.key,
    required this.title,
    required this.onRetry,
  });

  final String title;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return StatusView(
      icon: Icons.cloud_off_outlined,
      title: title,
      message: 'Check your connection and try again.',
      primaryLabel: 'Try again',
      onPrimary: onRetry,
    );
  }
}
