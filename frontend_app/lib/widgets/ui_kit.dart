import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../state/models.dart';
import '../theme.dart';

// ─── HomiesCard ───────────────────────────────────────────────────────────────

class HomiesCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;
  const HomiesCard({super.key, required this.child, this.padding, this.color, this.borderColor, this.onTap});

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: color ?? HomiesColors.surface,
        border: Border.all(color: borderColor ?? HomiesColors.border),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 3)),
          BoxShadow(color: Color(0x06000000), blurRadius: 2,  offset: Offset(0, 1)),
        ],
      ),
      padding: padding ?? const EdgeInsets.all(16),
      child: child,
    );

    if (onTap == null) return card;

    return TapScale(onTap: onTap!, child: card);
  }
}

// ─── TapScale — subtle press-scale feedback ───────────────────────────────────

class TapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  const TapScale({super.key, required this.child, this.onTap, this.onLongPress});

  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 90));
    _scale = Tween<double>(begin: 1.0, end: 0.965)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) => _ctrl.forward(),
        onTapUp: (_) { _ctrl.reverse(); widget.onTap?.call(); },
        onTapCancel: () => _ctrl.reverse(),
        onLongPress: widget.onLongPress,
        child: ScaleTransition(scale: _scale, child: widget.child),
      );
}

// ─── FadeSlideIn — content entrance animation ─────────────────────────────────

class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset slideFrom;
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 340),
    this.slideFrom = const Offset(0, 0.06),
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: widget.slideFrom, end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(widget.delay, () { if (mounted) _ctrl.forward(); });
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _opacity,
        child: SlideTransition(position: _slide, child: widget.child),
      );
}

// ─── Stagger — animate list children in sequence ─────────────────────────────

class Stagger extends StatelessWidget {
  final List<Widget> children;
  final Duration itemDelay;
  final Duration itemDuration;
  const Stagger({
    super.key,
    required this.children,
    this.itemDelay = const Duration(milliseconds: 55),
    this.itemDuration = const Duration(milliseconds: 300),
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++)
            FadeSlideIn(
              delay: itemDelay * i,
              duration: itemDuration,
              slideFrom: const Offset(0, 0.04),
              child: children[i],
            ),
        ],
      );
}

// ─── HomiesChip ───────────────────────────────────────────────────────────────

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
        bg = const Color(0x154A7DB0);
        fg = const Color(0xFF356190);
        break;
      case ChipTone.neutral:
        bg = const Color(0xFFEAE6E0);
        fg = HomiesColors.textDim;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

// ─── Segment control ──────────────────────────────────────────────────────────

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
    this.optionPadding = const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: HomiesColors.border),
        borderRadius: BorderRadius.circular(12),
        color: HomiesColors.surface2,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < options.length; i++) ...[
            InkWell(
              onTap: () => onChanged(options[i]),
              borderRadius: BorderRadius.horizontal(
                left:  i == 0               ? const Radius.circular(11) : Radius.zero,
                right: i == options.length - 1 ? const Radius.circular(11) : Radius.zero,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOut,
                padding: optionPadding,
                decoration: BoxDecoration(
                  color: options[i] == value ? HomiesColors.surface : Colors.transparent,
                  borderRadius: BorderRadius.horizontal(
                    left:  i == 0               ? const Radius.circular(11) : Radius.zero,
                    right: i == options.length - 1 ? const Radius.circular(11) : Radius.zero,
                  ),
                  boxShadow: options[i] == value
                      ? const [BoxShadow(color: Color(0x0C000000), blurRadius: 6, offset: Offset(0, 1))]
                      : null,
                ),
                child: Text(
                  labelFor(options[i]),
                  style: TextStyle(
                    fontSize: 13,
                    color: options[i] == value ? HomiesColors.accentStrong : HomiesColors.textDim,
                    fontWeight: options[i] == value ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
            if (i < options.length - 1) Container(width: 1, height: 28, color: HomiesColors.border),
          ],
        ],
      ),
    );
  }
}

// ─── FieldLabel / Hint ────────────────────────────────────────────────────────

class FieldLabel extends StatelessWidget {
  final String text;
  const FieldLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Text(text, style: const TextStyle(color: HomiesColors.textDim, fontSize: 13, fontWeight: FontWeight.w500)),
      );
}

class Hint extends StatelessWidget {
  final String text;
  const Hint(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(text, style: const TextStyle(color: HomiesColors.textFaint, fontSize: 12, height: 1.45)),
      );
}

// ─── PageHead ─────────────────────────────────────────────────────────────────

class PageHead extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  const PageHead({super.key, required this.title, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20, top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                    color: HomiesColors.text,
                    letterSpacing: -0.5,
                    height: 1.2,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      subtitle!,
                      style: const TextStyle(color: HomiesColors.textDim, fontSize: 13, height: 1.45),
                    ),
                  ),
              ],
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: 12),
            action!,
          ],
        ],
      ),
    );
  }
}

// ─── StatTile ─────────────────────────────────────────────────────────────────

class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final double valueFontSize;
  const StatTile({super.key, required this.label, required this.value, this.sub, this.valueFontSize = 22});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HomiesColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x0C000000), blurRadius: 10, offset: Offset(0, 3)),
          BoxShadow(color: Color(0x06000000), blurRadius: 2,  offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              color: HomiesColors.textFaint,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 7),
          Text(value, style: TextStyle(fontSize: valueFontSize, fontWeight: FontWeight.w700, color: HomiesColors.text, letterSpacing: -0.4)),
          if (sub != null)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(sub!, style: const TextStyle(fontSize: 12, color: HomiesColors.textDim, height: 1.35)),
            ),
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

// ─── EmptyState ───────────────────────────────────────────────────────────────

class EmptyState extends StatelessWidget {
  final String title;
  final String? body;
  const EmptyState({super.key, required this.title, this.body});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        decoration: BoxDecoration(
          color: HomiesColors.surface2,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: HomiesColors.textDim)),
            if (body != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(body!, textAlign: TextAlign.center, style: const TextStyle(color: HomiesColors.textFaint, fontSize: 13, height: 1.45)),
              ),
          ],
        ),
      );
}

// ─── InfoBanner ───────────────────────────────────────────────────────────────

class InfoBanner extends StatelessWidget {
  final String text;
  final IconData? icon;
  const InfoBanner({super.key, required this.text, this.icon});

  @override
  Widget build(BuildContext context) => HomiesCard(
        color: HomiesColors.accentSoft,
        borderColor: HomiesColors.accentBorder,
        child: Row(children: [
          if (icon != null)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Icon(icon, color: HomiesColors.accent, size: 20),
            ),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, height: 1.45, color: HomiesColors.accentStrong))),
        ]),
      );
}

// ─── AttachmentTile ───────────────────────────────────────────────────────────

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
      padding: const EdgeInsets.only(top: 8),
      child: Row(children: [
        if (isImage)
          GestureDetector(
            onTap: () => showDialog(
              context: context,
              builder: (_) => Dialog(child: InteractiveViewer(child: Image.memory(bytes))),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(bytes, width: size, height: size, fit: BoxFit.cover),
            ),
          )
        else
          const HomiesChip('📎 attached', tone: ChipTone.ok),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value.fileName ?? 'file', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            if (sizeKb.isNotEmpty)
              Text(sizeKb, style: const TextStyle(fontSize: 11, color: HomiesColors.textFaint)),
          ]),
        ),
      ]),
    );
  }
}

// ─── Date/time utilities ─────────────────────────────────────────────────────

Future<DateTime?> pickDate(BuildContext context, {DateTime? initial}) {
  final now = DateTime.now();
  return showDatePicker(
    context: context,
    initialDate: initial ?? now,
    firstDate: DateTime(now.year - 2),
    lastDate: DateTime(now.year + 5),
  );
}

String? toIso(DateTime? d) => d?.toIso8601String().substring(0, 10);
