import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../state/app_state.dart';
import '../theme.dart';

// ─── Local neutral palette (welcome screen only) ──────────────────────────────
// The rest of the app uses HomiesColors.accent (sage-forest green). This landing
// screen is deliberately monochrome-warm: warm near-black, warm stone/greys and
// warm off-white surfaces. No green accent is referenced anywhere below.
const _ink = HomiesColors.text; // warm near-black 0xFF1C1A16
const _inkGrad = Color(0xFF2C2823); // warm charcoal (dark card gradient end)
const _stone = HomiesColors.textDim; // warm stone 0xFF6B6258
const _faint = HomiesColors.textFaint; // warm muted 0xFFACA49A
const _surface = HomiesColors.surface; // warm white 0xFFFEFDF9
const _surface2 = HomiesColors.surface2; // recessed warm surface
const _border = HomiesColors.border;
const _borderStrong = HomiesColors.borderStrong;

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  // A single controller drives every entrance animation; each block reads a
  // different slice of it (see _FadeSlideIn intervals) to stagger. Runs once.
  late final AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    )..forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final signedIn = state.currentUser != null;

    return Scaffold(
      backgroundColor: HomiesColors.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _FadeSlideIn(
                    parent: _entrance,
                    start: 0.00,
                    end: 0.45,
                    child: _BrandBar(
                      signedIn: signedIn,
                      onSignIn: () => context.push('/login'),
                    ),
                  ),
                  const SizedBox(height: 36),
                  _FadeSlideIn(
                    parent: _entrance,
                    start: 0.08,
                    end: 0.60,
                    child: _Hero(signedIn: signedIn, state: state),
                  ),
                  if (!signedIn && kDebugMode) ...[
                    const SizedBox(height: 14),
                    _FadeSlideIn(
                      parent: _entrance,
                      start: 0.16,
                      end: 0.66,
                      child: _DemoBanner(onTap: () => context.push('/demo')),
                    ),
                  ],
                  const SizedBox(height: 40),
                  _FadeSlideIn(
                    parent: _entrance,
                    start: 0.22,
                    end: 0.70,
                    child: const _SectionLabel('EVERYTHING IN ONE PLACE'),
                  ),
                  const SizedBox(height: 16),
                  _FadeSlideIn(
                    parent: _entrance,
                    start: 0.28,
                    end: 0.78,
                    child: const _FeatureGrid(),
                  ),
                  const SizedBox(height: 28),
                  _FadeSlideIn(
                    parent: _entrance,
                    start: 0.36,
                    end: 0.86,
                    child: const _MarketplaceSection(),
                  ),
                  const SizedBox(height: 28),
                  _FadeSlideIn(
                    parent: _entrance,
                    start: 0.44,
                    end: 0.94,
                    child: const _Reassurance(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Entrance animation helper ────────────────────────────────────────────────
// Fades + slides its child up as [parent] sweeps through [start]..[end]. Owns its
// CurvedAnimation so it can dispose it (avoids leaking listeners on the parent).
class _FadeSlideIn extends StatefulWidget {
  final Animation<double> parent;
  final double start;
  final double end;
  final Widget child;
  const _FadeSlideIn({
    required this.parent,
    required this.start,
    required this.end,
    required this.child,
  });

  @override
  State<_FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<_FadeSlideIn> {
  late final CurvedAnimation _curved;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _curved = CurvedAnimation(
      parent: widget.parent,
      curve: Interval(widget.start, widget.end, curve: Curves.easeOutCubic),
    );
    _offset = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(_curved);
  }

  @override
  void dispose() {
    _curved.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curved,
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}

// ─── Press-scale wrapper ──────────────────────────────────────────────────────
// A light tap-to-shrink feedback around any tappable child. Uses a passive
// Listener (it observes pointer events without consuming them, so the button
// inside still receives the tap) plus an implicit AnimatedScale — no controller
// to dispose.
class _PressableScale extends StatefulWidget {
  final Widget child;
  const _PressableScale({required this.child});

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  double _scale = 1.0;

  void _set(bool down) {
    if (mounted) setState(() => _scale = down ? 0.97 : 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// ─── Brand bar ────────────────────────────────────────────────────────────────

class _BrandBar extends StatelessWidget {
  final bool signedIn;
  final VoidCallback onSignIn;
  const _BrandBar({required this.signedIn, required this.onSignIn});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _ink,
            borderRadius: BorderRadius.circular(11),
            boxShadow: [
              BoxShadow(
                color: _ink.withValues(alpha: 0.22),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Text('🏡', style: TextStyle(fontSize: 18)),
        ),
        const SizedBox(width: 11),
        const Text(
          'homies',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _ink, letterSpacing: -0.3),
        ),
        const Spacer(),
        // Signed-out users get a visible top-right "Sign in" entry point (in
        // addition to the hero button); signed-in users see the tagline pill.
        if (!signedIn)
          TextButton(
            onPressed: onSignIn,
            style: TextButton.styleFrom(
              foregroundColor: _ink,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('Sign in'),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _border),
            ),
            child: const Text('Sharehouse, sorted',
                style: TextStyle(fontSize: 11.5, color: _stone, fontWeight: FontWeight.w500)),
          ),
      ],
    );
  }
}

// ─── Hero ─────────────────────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  final bool signedIn;
  final HomiesState state;
  const _Hero({required this.signedIn, required this.state});

  @override
  Widget build(BuildContext context) {
    final eyebrow = signedIn ? 'Welcome back' : 'No more spreadsheets';
    final headline = signedIn
        ? 'Good to see you\nagain, ${state.currentUser!.name}.'
        : 'Run a sharehouse\nwithout the drama.';
    final subtitle = signedIn
        ? 'Pick up where you left off — bills, chores, and everything your house is keeping track of.'
        : 'Bills, bond, chores, parties and complaints — all in one place, with fair splits and a shared record everyone can trust.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Eyebrow badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border),
          ),
          child: Text(eyebrow,
              style: const TextStyle(color: _stone, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 18),
        Text(
          headline,
          style: const TextStyle(
            color: _ink,
            fontSize: 36,
            height: 1.08,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.0,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          subtitle,
          style: const TextStyle(color: _stone, fontSize: 15.5, height: 1.5),
        ),
        const SizedBox(height: 26),
        if (signedIn) ...[
          _PressableScale(
            child: _PrimaryButton(
              label: 'Continue as ${state.currentUser!.name}',
              onPressed: () => context.go('/app'),
            ),
          ),
          const SizedBox(height: 12),
          _PressableScale(
            child: _SecondaryButton(
              label: 'Sign out',
              onPressed: () => state.signOut(),
            ),
          ),
        ] else ...[
          _PressableScale(
            child: _PrimaryButton(
              label: 'Create account',
              onPressed: () => context.push('/signup'),
            ),
          ),
          const SizedBox(height: 12),
          // Prominent, above-the-fold sign-in — the primary/secondary pair sits
          // together so returning users never hunt for how to log in.
          _PressableScale(
            child: _SecondaryButton(
              label: 'Sign in',
              onPressed: () => context.push('/login'),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              'Free to set up · takes about a minute',
              style: const TextStyle(color: _faint, fontSize: 12.5, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ],
    );
  }
}

// Solid warm-black CTA with white text.
class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _PrimaryButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _ink,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, letterSpacing: 0.1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded, size: 19),
          ],
        ),
      ),
    );
  }
}

// Outlined warm-neutral secondary action.
class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _SecondaryButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: _ink,
          backgroundColor: _surface,
          side: const BorderSide(color: _borderStrong),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        child: Text(label),
      ),
    );
  }
}

// ─── Demo banner (debug only) ─────────────────────────────────────────────────

class _DemoBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _DemoBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _borderStrong),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _surface2,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _border),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.bolt_rounded, color: _ink, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Just looking?',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _ink)),
                    SizedBox(height: 2),
                    Text('Explore with a demo account — no signup needed.',
                        style: TextStyle(fontSize: 12.5, color: _stone)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: _faint),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Marketplace ──────────────────────────────────────────────────────────────

class _MarketplaceSection extends StatelessWidget {
  const _MarketplaceSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_ink, _inkGrad],
        ),
        boxShadow: [
          BoxShadow(
            color: _ink.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('MARKETPLACE',
                    style: TextStyle(
                        color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
              ),
              const Spacer(),
              const Text('🛏️', style: TextStyle(fontSize: 20)),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Got a free room? Find a housemate.',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: -0.3),
          ),
          const SizedBox(height: 8),
          Text(
            'List an empty room or post what you’re after, message housemates directly, and ask prospective tenants for their track record before they move in.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.82), fontSize: 13.5, height: 1.5),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _MarketTag('🏠  Rooms available'),
              _MarketTag('🔎  People looking'),
              _MarketTag('💬  Message in the post'),
              _MarketTag('📋  Performance references'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MarketTag extends StatelessWidget {
  final String label;
  const _MarketTag(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11.5,
        color: _faint,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}

// ─── Feature grid ─────────────────────────────────────────────────────────────

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid();

  static const _features = [
    _FeatureData('💡', 'Bills & bond', 'Split utilities, track who paid, prorate by move-in date.'),
    _FeatureData('🧹', 'Chores', 'A fair roster with photo proof and a paper trail.'),
    _FeatureData('🎉', 'Parties & rules', 'Plan events, RSVP, and keep house rules clear.'),
    _FeatureData('🚪', 'Move out clean', '2-week notice, bond release, deductions explained.'),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const gap = 12.0;
      final cols = c.maxWidth < 380 ? 1 : 2;
      final tileW = (c.maxWidth - (cols - 1) * gap) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final f in _features) SizedBox(width: tileW, child: _FeatureCard(f)),
        ],
      );
    });
  }
}

class _FeatureData {
  final String icon;
  final String title;
  final String body;
  const _FeatureData(this.icon, this.title, this.body);
}

class _FeatureCard extends StatelessWidget {
  final _FeatureData data;
  const _FeatureCard(this.data);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _surface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            alignment: Alignment.center,
            child: Text(data.icon, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(height: 12),
          Text(data.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: _ink)),
          const SizedBox(height: 5),
          Text(data.body, style: const TextStyle(color: _stone, fontSize: 12.5, height: 1.4)),
        ],
      ),
    );
  }
}

// ─── Reassurance ──────────────────────────────────────────────────────────────

class _Reassurance extends StatelessWidget {
  const _Reassurance();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _border),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.verified_user_rounded, color: _ink, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Transparent splits and a shared record everyone can trust — so the house stays drama-free.',
              style: TextStyle(fontSize: 12.5, color: _stone, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
