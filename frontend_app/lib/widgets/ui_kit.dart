import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../state/models.dart';
import '../theme.dart';

class HomiesCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Color? borderColor;
  const HomiesCard({super.key, required this.child, this.padding, this.color, this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: color ?? HomiesColors.surface,
        border: Border.all(color: borderColor ?? HomiesColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: padding ?? const EdgeInsets.all(16),
      child: child,
    );
  }
}

enum ChipTone { neutral, ok, warn, danger, accent, info }

class HomiesChip extends StatelessWidget {
  final String label;
  final ChipTone tone;
  const HomiesChip(this.label, {super.key, this.tone = ChipTone.neutral});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (tone) {
      case ChipTone.ok:
        bg = HomiesColors.okSoft;
        fg = HomiesColors.ok;
        break;
      case ChipTone.warn:
        bg = HomiesColors.warnSoft;
        fg = HomiesColors.warn;
        break;
      case ChipTone.danger:
        bg = HomiesColors.dangerSoft;
        fg = HomiesColors.danger;
        break;
      case ChipTone.accent:
        bg = HomiesColors.accentSoft;
        fg = HomiesColors.accentStrong;
        break;
      case ChipTone.info:
        bg = const Color(0x1A4A7DB0);
        fg = const Color(0xFF356190);
        break;
      case ChipTone.neutral:
      // ignore: unreachable_switch_default
      default:
        bg = HomiesColors.surface2;
        fg = HomiesColors.textDim;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w500)),
    );
  }
}

class Segment<T> extends StatelessWidget {
  final List<T> options;
  final T value;
  final String Function(T) labelFor;
  final ValueChanged<T> onChanged;
  final EdgeInsetsGeometry optionPadding;
  const Segment({
    super.key,
    required this.options,
    required this.value,
    required this.labelFor,
    required this.onChanged,
    this.optionPadding = const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: HomiesColors.borderStrong),
        borderRadius: BorderRadius.circular(8),
        color: HomiesColors.surface,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < options.length; i++) ...[
            InkWell(
              onTap: () => onChanged(options[i]),
              child: Container(
                padding: optionPadding,
                decoration: BoxDecoration(
                  color: options[i] == value ? HomiesColors.accentSoft : Colors.transparent,
                  borderRadius: BorderRadius.horizontal(
                    left: i == 0 ? const Radius.circular(7) : Radius.zero,
                    right: i == options.length - 1 ? const Radius.circular(7) : Radius.zero,
                  ),
                ),
                child: Text(
                  labelFor(options[i]),
                  style: TextStyle(
                    fontSize: 13,
                    color: options[i] == value ? HomiesColors.accentStrong : HomiesColors.textDim,
                    fontWeight: options[i] == value ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ),
            ),
            if (i < options.length - 1) Container(width: 1, height: 32, color: HomiesColors.border),
          ],
        ],
      ),
    );
  }
}

class FieldLabel extends StatelessWidget {
  final String text;
  const FieldLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: const TextStyle(color: HomiesColors.textDim, fontSize: 13, fontWeight: FontWeight.w500)),
      );
}

class Hint extends StatelessWidget {
  final String text;
  const Hint(this.text, {super.key});
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.only(top: 6), child: Text(text, style: const TextStyle(color: HomiesColors.textFaint, fontSize: 12)));
}

class PageHead extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  const PageHead({super.key, required this.title, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: HomiesColors.text)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(subtitle!, style: const TextStyle(color: HomiesColors.textDim, fontSize: 13)),
                  ),
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final double valueFontSize;
  const StatTile({super.key, required this.label, required this.value, this.sub, this.valueFontSize = 22});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: HomiesColors.surface2, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(fontSize: 11, color: HomiesColors.textDim, letterSpacing: 0.5, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: valueFontSize, fontWeight: FontWeight.w600, color: HomiesColors.text)),
          if (sub != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(sub!, style: const TextStyle(fontSize: 12, color: HomiesColors.textDim))),
        ],
      ),
    );
  }
}

class StatRow extends StatelessWidget {
  final List<Widget> tiles;
  const StatRow({super.key, required this.tiles});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth < 360 ? 1 : c.maxWidth < 540 ? 2 : tiles.length.clamp(2, 4);
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: tiles.map((t) => SizedBox(width: (c.maxWidth - (cols - 1) * 10) / cols, child: t)).toList(),
      );
    });
  }
}

class EmptyState extends StatelessWidget {
  final String title;
  final String? body;
  const EmptyState({super.key, required this.title, this.body});
  @override
  Widget build(BuildContext context) => HomiesCard(
        color: HomiesColors.surface2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: HomiesColors.textDim)),
            if (body != null)
              Padding(padding: const EdgeInsets.only(top: 4), child: Text(body!, style: const TextStyle(color: HomiesColors.textFaint, fontSize: 13))),
          ],
        ),
      );
}

class InfoBanner extends StatelessWidget {
  final String text;
  final IconData? icon;
  const InfoBanner({super.key, required this.text, this.icon});
  @override
  Widget build(BuildContext context) => HomiesCard(
        color: HomiesColors.surface2,
        borderColor: HomiesColors.accentSoft,
        child: Row(children: [
          if (icon != null) Padding(padding: const EdgeInsets.only(right: 10), child: Icon(icon, color: HomiesColors.accent)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ]),
      );
}

class AttachmentTile extends StatelessWidget {
  final Attachment value;
  final bool compact;
  const AttachmentTile({super.key, required this.value, this.compact = false});

  Uint8List? _decode() {
    final url = value.dataUrl;
    if (url == null || !url.startsWith('data:')) return null;
    final comma = url.indexOf(',');
    if (comma < 0) return null;
    try {
      return base64Decode(url.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _decode();
    final isImage = (value.type ?? '').startsWith('image/') && bytes != null;
    final sizeKb = value.size != null ? '${(value.size! / 1024).toStringAsFixed(0)} KB' : '';
    final size = compact ? 40.0 : 56.0;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(children: [
        if (isImage)
          GestureDetector(
            onTap: () => showDialog(
              context: context,
              builder: (_) => Dialog(child: InteractiveViewer(child: Image.memory(bytes))),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.memory(bytes, width: size, height: size, fit: BoxFit.cover),
            ),
          )
        else
          const HomiesChip('📎 attached', tone: ChipTone.ok),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value.fileName ?? 'file', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            if (sizeKb.isNotEmpty) Text(sizeKb, style: const TextStyle(fontSize: 11, color: HomiesColors.textFaint)),
          ]),
        ),
      ]),
    );
  }
}

Future<DateTime?> pickDate(BuildContext context, {DateTime? initial}) {
  final now = DateTime.now();
  return showDatePicker(
    context: context,
    initialDate: initial ?? now,
    firstDate: DateTime(now.year - 2),
    lastDate: DateTime(now.year + 5),
  );
}

String? toIso(DateTime? d) => d == null ? null : d.toIso8601String().substring(0, 10);
