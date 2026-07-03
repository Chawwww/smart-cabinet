import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

// ════════════════════════════════════════════════════════
// VoiceInputWidget — reusable voice button
// Drop this anywhere in the app to add voice input.
//
// Usage example:
//   VoiceInputWidget(
//     onResult: (text) => myController.text = text,
//     hintText: 'Speak item name…',
//   )
// ════════════════════════════════════════════════════════

class VoiceInputWidget extends StatefulWidget {
  final void Function(String text) onResult;
  final String? hintText;
  final Color? color;
  final double iconSize;
  final bool showLabel;

  const VoiceInputWidget({
    super.key,
    required this.onResult,
    this.hintText,
    this.color,
    this.iconSize = 24,
    this.showLabel = false,
  });

  @override
  State<VoiceInputWidget> createState() => _VoiceInputWidgetState();
}

class _VoiceInputWidgetState extends State<VoiceInputWidget>
    with SingleTickerProviderStateMixin {
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;
  bool _speechReady = false;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _initSpeech();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    if (kIsWeb) return;
    try {
      final ok = await _speech.initialize(
        onError: (_) => setState(() => _isListening = false),
        onStatus: (s) {
          if (s == SpeechToText.doneStatus ||
              s == SpeechToText.notListeningStatus) {
            setState(() => _isListening = false);
          }
        },
      );
      if (mounted) setState(() => _speechReady = ok);
    } catch (_) {}
  }

  Future<void> _toggle() async {
    if (!_speechReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '麦克风不可用 / Microphone not available.\n'
            'Check app permissions in Settings.',
          ),
        ),
      );
      return;
    }

    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    // Pick best locale
    String locale = 'en_US';
    try {
      final locales = await _speech.locales();
      for (final pref in ['zh_CN', 'ms_MY', 'en_US']) {
        if (locales.any((l) =>
            l.localeId.startsWith(pref.split('_')[0]))) {
          locale = pref;
          break;
        }
      }
    } catch (_) {}

    setState(() => _isListening = true);

    await _speech.listen(
      localeId: locale,
      listenFor: const Duration(seconds: 15),
      pauseFor:  const Duration(seconds: 2),
      partialResults: true,
      onResult: (result) {
        if (result.finalResult) {
          setState(() => _isListening = false);
          if (result.recognizedWords.isNotEmpty) {
            widget.onResult(result.recognizedWords.trim());
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return const SizedBox.shrink();

    final color = widget.color ?? const Color(0xFF4ECDC4);

    if (widget.showLabel) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildButton(color),
          const SizedBox(height: 4),
          Text(
            _isListening
                ? '正在听… / Listening…'
                : '语音 / Voice',
            style: TextStyle(
                fontSize: 10,
                color: _isListening ? Colors.red : color),
          ),
        ],
      );
    }

    return _buildButton(color);
  }

  Widget _buildButton(Color color) {
    if (_isListening) {
      return ScaleTransition(
        scale: _pulseAnim,
        child: GestureDetector(
          onTap: _toggle,
          child: Container(
            width: widget.iconSize + 20,
            height: widget.iconSize + 20,
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.4),
                  blurRadius: 12,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: Icon(Icons.stop,
                color: Colors.white, size: widget.iconSize - 4),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _toggle,
      child: Container(
        width: widget.iconSize + 20,
        height: widget.iconSize + 20,
        decoration: BoxDecoration(
          color: _speechReady
              ? color.withValues(alpha: 0.12)
              : Colors.grey.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(
            color: _speechReady
                ? color.withValues(alpha: 0.4)
                : Colors.grey.shade400,
          ),
        ),
        child: Icon(Icons.mic,
            color: _speechReady ? color : Colors.grey.shade400,
            size: widget.iconSize),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
// VoiceTextField — TextField with built-in voice button
//
// Usage:
//   VoiceTextField(
//     controller: _myController,
//     label: 'Item Name',
//     onVoiceResult: (text) => setState(() {}),
//   )
// ════════════════════════════════════════════════════════

class VoiceTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final void Function(String)? onVoiceResult;
  final void Function(String)? onChanged;
  final String? Function(String?)? validator;
  final int maxLines;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;

  const VoiceTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.onVoiceResult,
    this.onChanged,
    this.validator,
    this.maxLines = 1,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: isDark ? const Color(0xFF2D2D2D) : Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: isDark
                    ? Colors.grey.shade700
                    : Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: isDark
                    ? Colors.grey.shade700
                    : Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
                color: Color(0xFF4ECDC4), width: 1.5)),
        // Voice button as suffix
        suffixIcon: onVoiceResult != null
            ? Padding(
                padding: const EdgeInsets.only(right: 8),
                child: VoiceInputWidget(
                  iconSize: 20,
                  onResult: (text) {
                    controller.text = text;
                    onVoiceResult!(text);
                  },
                ),
              )
            : null,
      ),
    );
  }
}