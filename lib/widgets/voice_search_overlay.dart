import 'dart:async';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/voice_search_service.dart';

/// Shows the voice search overlay as a full-screen modal.
///
/// Returns the parsed [VoiceIntent] if the user confirms, or null if cancelled.
Future<VoiceIntent?> showVoiceSearch(BuildContext context) async {
  return showModalBottomSheet<VoiceIntent>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const VoiceSearchOverlay(),
  );
}

class VoiceSearchOverlay extends StatefulWidget {
  const VoiceSearchOverlay({super.key});

  @override
  State<VoiceSearchOverlay> createState() => _VoiceSearchOverlayState();
}

class _VoiceSearchOverlayState extends State<VoiceSearchOverlay>
    with TickerProviderStateMixin {
  final VoiceSearchService _service = VoiceSearchService.instance;

  late AnimationController _pulseController;
  late AnimationController _waveController;

  String _transcript = '';
  String _partialTranscript = '';
  bool _isListening = false;
  bool _hasResult = false;
  bool _isProcessing = false;
  VoiceIntent? _intent;
  StreamSubscription<String>? _subscription;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _startListening();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    _subscription?.cancel();
    _service.stopListening();
    super.dispose();
  }

  Future<void> _startListening() async {
    final available = await _service.init();
    if (!available) {
      if (mounted) {
        setState(() => _transcript = 'Speech recognition not available');
      }
      return;
    }

    setState(() {
      _isListening = true;
      _isProcessing = false;
    });

    _pulseController.repeat(reverse: true);

    _subscription = _service.startListening().listen(
      (text) {
        if (mounted) {
          setState(() => _partialTranscript = text);
        }
      },
      onDone: () {
        if (mounted) {
          setState(() {
            _isListening = false;
            _transcript = _partialTranscript.isNotEmpty
                ? _partialTranscript
                : _transcript;
          });
          _pulseController.stop();
          _parseAndShow();
        }
      },
    );
  }

  void _parseAndShow() {
    if (_transcript.isEmpty) return;

    setState(() {
      _isProcessing = true;
    });

    // Small delay to show the processing state
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      final intent = _service.parseIntent(_transcript);

      // Auto-detect navigation commands — pop immediately.
      if (intent.action == VoiceAction.navigate) {
        final target = _service.parseNavigationTarget(_transcript);
        if (target != null) {
          Navigator.pop(context, intent);
          return;
        }
      }

      // If there's a clear product match, auto-confirm after a brief pause
      // so the user can see what was recognized (no need to tap Confirm).
      if (intent.hasMatch) {
        setState(() {
          _intent = intent;
          _hasResult = true;
          _isProcessing = false;
        });
        // Show the result for 1.5s, then auto-confirm.
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted && _hasResult && _intent != null) {
            _confirm();
          }
        });
        return;
      }

      // No match — show result and let the user decide (Try Again / Search).
      setState(() {
        _intent = intent;
        _hasResult = true;
        _isProcessing = false;
      });
    });
  }

  void _confirm() {
    Navigator.pop(context, _intent);
  }

  void _retry() {
    setState(() {
      _transcript = '';
      _partialTranscript = '';
      _hasResult = false;
      _isProcessing = false;
      _intent = null;
    });
    _startListening();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      height: screenHeight * 0.75,
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadii.lg),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: AppColors.grey300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomPadding),
              child: Column(
                children: [
                  // Title
                  const Text(
                    'Voice Search',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isListening
                        ? 'Listening... speak now'
                        : _hasResult
                            ? (_intent?.hasMatch == true
                                ? 'Found it! Confirming...'
                                : 'Did I get that right?')
                            : 'Tap the mic to start',
                    style: TextStyle(
                      fontSize: 14,
                      color: _isListening || (_hasResult && _intent?.hasMatch == true)
                          ? AppColors.primaryDark
                          : AppColors.grey700,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Mic / Wave animation area — hide while processing
                  if (!_hasResult && !_isProcessing) ...[
                    _buildListeningArea(),
                    const SizedBox(height: 32),
                  ],

                  // Transcript display (hide once we have a final result)
                  if (_transcript.isNotEmpty && !_hasResult)
                    _buildTranscriptCard(),

                  if (_isProcessing) ...[
                    const SizedBox(height: 24),
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(AppColors.primaryDark),
                    ),
                  ],

                  // Intent result
                  if (_hasResult && _intent != null) ...[
                    const SizedBox(height: 20),
                    _buildIntentCard(),
                  ],

                  const Spacer(),

                  // Action buttons
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // LISTENING AREA — animated mic with pulsing waves
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildListeningArea() {
    return GestureDetector(
      onTap: () {
        if (_isListening) {
          _service.stopListening();
          setState(() {
            _isListening = false;
            _transcript = _partialTranscript;
          });
          _pulseController.stop();
          _parseAndShow();
        } else {
          _startListening();
        }
      },
      child: SizedBox(
        width: 160,
        height: 160,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Animated wave rings
            if (_isListening)
              AnimatedBuilder(
                animation: _waveController,
                builder: (context, _) {
                  return CustomPaint(
                    size: const Size(160, 160),
                    painter: _WavePainter(
                      progress: _waveController.value,
                      color: AppColors.primaryLight,
                    ),
                  );
                },
              ),
            // Pulse ring
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final scale = 1.0 + (_pulseController.value * 0.15);
                return Transform.scale(
                  scale: _isListening ? scale : 1.0,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isListening
                          ? AppColors.primaryDark
                          : AppColors.grey200,
                    ),
                  ),
                );
              },
            ),
            // Mic icon
            Icon(
              _isListening ? Icons.mic : Icons.mic_none,
              size: 40,
              color: _isListening ? AppColors.white : AppColors.grey600,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // TRANSCRIPT CARD
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildTranscriptCard() {
    final displayText = _isListening && _partialTranscript.isNotEmpty
        ? _partialTranscript
        : _transcript;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.grey100,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Icon(
            Icons.format_quote,
            size: 20,
            color: AppColors.grey600,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              displayText.isNotEmpty ? displayText : '...',
              style: TextStyle(
                fontSize: 16,
                color: displayText.isNotEmpty
                    ? AppColors.black
                    : AppColors.grey500,
                fontStyle: displayText.isEmpty ? FontStyle.italic : null,
              ),
            ),
          ),
          if (_isListening)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(AppColors.primaryDark),
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // INTENT CARD — shows what was parsed
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildIntentCard() {
    final intent = _intent!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: intent.hasMatch ? const Color(0xFFF0FDF4) : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: intent.hasMatch ? AppColors.success : AppColors.warning,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                intent.hasMatch ? Icons.check_circle : Icons.help_outline,
                size: 20,
                color: intent.hasMatch ? AppColors.success : AppColors.warning,
              ),
              const SizedBox(width: 8),
              Text(
                intent.hasMatch ? 'Product found' : 'Did you mean?',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: intent.hasMatch ? AppColors.success : AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Action badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Text(
              intent.displayAction,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Product info
          Text(
            intent.hasMatch ? intent.matchedProductName! : '"${intent.productQuery}"',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.black,
            ),
          ),
          if (intent.hasQuantity) ...[
            const SizedBox(height: 4),
            Text(
              'Quantity: ${intent.quantity}',
              style: const TextStyle(fontSize: 14, color: AppColors.grey700),
            ),
          ],
          if (intent.matchedVendorName != null) ...[
            const SizedBox(height: 4),
            Text(
              'Vendor: ${intent.matchedVendorName}',
              style: const TextStyle(fontSize: 14, color: AppColors.grey700),
            ),
          ],
          if (!intent.hasMatch && intent.productQuery.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'No matching product found. Try a different search.',
              style: TextStyle(fontSize: 13, color: AppColors.grey600),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ACTION BUTTONS
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildActionButtons() {
    if (_hasResult && _intent != null) {
      return Row(
        children: [
          // Retry button
          Expanded(
            child: GestureDetector(
              onTap: _retry,
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.grey100,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  border: Border.all(color: AppColors.divider),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.refresh, size: 20, color: AppColors.grey700),
                    SizedBox(width: 8),
                    Text(
                      'Try Again',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.grey700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Confirm button
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: _confirm,
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: _intent!.hasMatch
                      ? AppColors.primaryDark
                      : AppColors.grey300,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _intent!.hasMatch ? Icons.check : Icons.search,
                      size: 20,
                      color: _intent!.hasMatch
                          ? AppColors.white
                          : AppColors.grey700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _intent!.hasMatch ? 'Confirm' : 'Search',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _intent!.hasMatch
                            ? AppColors.white
                            : AppColors.grey700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Initial state — just a cancel button
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        height: 50,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.grey100,
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: const Center(
          child: Text(
            'Cancel',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.grey700,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Wave painter — animated concentric rings
// ---------------------------------------------------------------------------

class _WavePainter extends CustomPainter {
  final double progress;
  final Color color;

  _WavePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (int i = 0; i < 3; i++) {
      final t = (progress + i * 0.33) % 1.0;
      final radius = 30.0 + t * 50.0;
      final opacity = (1.0 - t).clamp(0.0, 1.0);
      paint.color = color.withValues(alpha: opacity * 0.6);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
