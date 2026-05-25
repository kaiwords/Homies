import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OtpInput extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final int length;
  final bool autoFocus;
  const OtpInput({super.key, required this.value, required this.onChanged, this.length = 6, this.autoFocus = true});

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focuses;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (i) => TextEditingController(text: i < widget.value.length ? widget.value[i] : ''));
    _focuses = List.generate(widget.length, (_) => FocusNode());
    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focuses[0].requestFocus());
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focuses) {
      f.dispose();
    }
    super.dispose();
  }

  void _setDigit(int i, String char) {
    final clean = char.replaceAll(RegExp(r'\D'), '');
    if (clean.length > 1) {
      // pasted
      final padded = clean.substring(0, clean.length.clamp(0, widget.length));
      for (var k = 0; k < widget.length; k++) {
        _controllers[k].text = k < padded.length ? padded[k] : '';
      }
      widget.onChanged(padded.padRight(widget.length).substring(0, widget.length).replaceAll(' ', ''));
      final lastIdx = (padded.length - 1).clamp(0, widget.length - 1);
      _focuses[lastIdx].requestFocus();
      return;
    }
    _controllers[i].text = clean;
    final buf = _controllers.map((c) => c.text).join();
    widget.onChanged(buf);
    if (clean.isNotEmpty && i < widget.length - 1) _focuses[i + 1].requestFocus();
  }

  void _handleBackspace(int i) {
    if (_controllers[i].text.isEmpty && i > 0) {
      _controllers[i - 1].text = '';
      widget.onChanged(_controllers.map((c) => c.text).join());
      _focuses[i - 1].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        for (var i = 0; i < widget.length; i++) ...[
          SizedBox(
            width: 44,
            height: 52,
            child: KeyboardListener(
              focusNode: FocusNode(),
              onKeyEvent: (e) {
                if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.backspace) {
                  _handleBackspace(i);
                }
              },
              child: TextField(
                controller: _controllers[i],
                focusNode: _focuses[i],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                style: const TextStyle(fontSize: 22, fontFamily: 'monospace'),
                decoration: const InputDecoration(counterText: '', contentPadding: EdgeInsets.zero),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) => _setDigit(i, v),
              ),
            ),
          ),
          if (i < widget.length - 1) const SizedBox(width: 6),
        ],
      ],
    );
  }
}
