import 'package:flutter/material.dart';

import '../services/voice_search_session.dart';
import '../theme.dart';

/// The mic inside a search field.
///
/// Drawn from the session's state, so the button always matches the microphone:
/// a pulsing mic while listening (tap stops), a plain mic when idle, and
/// nothing at all when the device has no speech recognition — the status line
/// next to the field says why, so there is no dead control to tap.
class VoiceSearchButton extends StatefulWidget {
  final VoiceSearchSession session;

  /// Icon size. The Search field uses 24, the catalog's compact field 20.
  final double iconSize;

  const VoiceSearchButton({
    super.key,
    required this.session,
    this.iconSize = 24,
  });

  @override
  State<VoiceSearchButton> createState() => _VoiceSearchButtonState();
}

class _VoiceSearchButtonState extends State<VoiceSearchButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_syncPulse);
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant VoiceSearchButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      oldWidget.session.removeListener(_syncPulse);
      widget.session.addListener(_syncPulse);
      _syncPulse();
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(_syncPulse);
    _pulse.dispose();
    super.dispose();
  }

  /// The pulse runs only while listening: a repeating animation left running
  /// would keep the whole screen rebuilding once a second.
  void _syncPulse() {
    if (widget.session.isListening) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else if (_pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // No engine or no permission: the status line explains it, and a button
    // that cannot do anything is not shown at all.
    if (widget.session.state == VoiceSearchState.unavailable) {
      return const SizedBox.shrink();
    }

    final listening = widget.session.isListening;

    return IconButton(
      key: const ValueKey('voiceSearchMic'),
      tooltip: listening ? 'Stop listening' : 'Search by voice',
      splashRadius: 22,
      onPressed: () {
        // A second tap stops the running session instead of opening another.
        widget.session.toggle();
      },
      icon: ScaleTransition(
        scale: Tween<double>(begin: 1, end: 1.18).animate(
          CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
        ),
        child: Icon(
          listening ? Icons.mic : Icons.mic_none,
          size: widget.iconSize,
          color: listening ? C.primary(context) : C.textMuted(context),
        ),
      ),
    );
  }
}

/// One line under the search field: "Listening…", a failure with a retry, or
/// the reason voice search is not available here.
///
/// Takes the whole width of the field below it, which is why it is not part of
/// the button: it must not be squeezed into the suffix icon.
class VoiceSearchStatus extends StatelessWidget {
  final VoiceSearchSession session;

  const VoiceSearchStatus({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: session,
      builder: (context, _) {
        final state = session.state;
        if (state == VoiceSearchState.idle) return const SizedBox.shrink();

        final failed = state == VoiceSearchState.failed;
        final text = state == VoiceSearchState.listening
            ? 'Listening…'
            : session.message ?? '';

        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Row(
            children: [
              if (state == VoiceSearchState.listening)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(C.primary(context)),
                  ),
                )
              else
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: failed ? C.warningText(context) : C.textMuted(context),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  key: const ValueKey('voiceSearchStatus'),
                  style: TextStyle(
                    fontSize: 13,
                    color: failed ? C.warningText(context) : C.textMuted(context),
                  ),
                ),
              ),
              if (failed)
                TextButton(
                  key: const ValueKey('voiceSearchRetry'),
                  onPressed: session.retry,
                  child: const Text('Try again'),
                ),
            ],
          ),
        );
      },
    );
  }
}
