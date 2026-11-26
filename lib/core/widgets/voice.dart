import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';

/// Mic button for search bars: speak in English or Urdu and the text is filled in.
class VoiceSearchButton extends StatefulWidget {
  final ValueChanged<String> onResult;
  const VoiceSearchButton({super.key, required this.onResult});
  @override
  State<VoiceSearchButton> createState() => _VoiceSearchButtonState();
}

class _VoiceSearchButtonState extends State<VoiceSearchButton> with SingleTickerProviderStateMixin {
  static final SpeechToText _stt = SpeechToText();
  static bool _ready = false;
  bool _listening = false;
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  @override
  void dispose() {
    if (_listening) _stt.stop();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_listening) {
      await _stt.stop();
      _stopped();
      return;
    }
    try {
      _ready = _ready || await _stt.initialize(onStatus: (s) {
        if (s == 'done' || s == 'notListening') _stopped();
      }, onError: (_) => _stopped());
    } catch (_) {
      _ready = false;
    }
    if (!mounted) return;
    if (!_ready) {
      snack(context, 'Voice search is not available on this device', error: true);
      return;
    }
    setState(() => _listening = true);
    _pulse.repeat(reverse: true);
    snack(context, AppLang.isUrdu ? 'بولیں...' : 'Listening... speak now');
    await _stt.listen(
      localeId: AppLang.isUrdu ? 'ur_PK' : 'en_US',
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
      onResult: (r) {
        if (r.recognizedWords.isNotEmpty) widget.onResult(r.recognizedWords);
        if (r.finalResult) _stopped();
      },
    );
  }

  void _stopped() {
    if (!mounted || !_listening) return;
    _pulse.stop();
    setState(() => _listening = false);
  }

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tr('Search by voice'),
        onPressed: _toggle,
        icon: AnimatedBuilder(
          animation: _pulse,
          builder: (_, _) => Transform.scale(
            scale: _listening ? 1 + _pulse.value * 0.25 : 1,
            child: Icon(_listening ? Icons.mic : Icons.mic_none, color: _listening ? Colors.red : C.green),
          ),
        ),
      );
}
