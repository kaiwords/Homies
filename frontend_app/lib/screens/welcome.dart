import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../state/app_state.dart';
import '../theme.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final signedIn = state.currentUser != null;

    return Scaffold(
      backgroundColor: HomiesColors.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _BrandBar(),
                  const SizedBox(height: 20),
                  _Hero(signedIn: signedIn, state: state),
                  if (!signedIn) ...[
                    const SizedBox(height: 12),
                    _DemoBanner(onTap: () => context.push('/demo')),
                  ],
                  const SizedBox(height: 26),
                  const _SectionLabel('EVERYTHING IN ONE PLACE'),
                  const SizedBox(height: 12),
                  const _FeatureGrid(),
                  const SizedBox(height: 22),
                  const _MarketplaceSection(),
                  const SizedBox(height: 22),
                  const _Reassurance(),
                  const SizedBox(height: 18),
                  if (!signedIn)
                    Center(
                      child: TextButton(
                        onPressed: () => context.push('/login'),
                        child: const Text.rich(
                          TextSpan(
                            text: 'Already have an account?  ',
                            style: TextStyle(color: HomiesColors.textDim, fontSize: 13),
                            children: [
                              TextSpan(
                                text: 'Sign in',
                                style: TextStyle(
                                  color: HomiesColors.accentStrong,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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

class _BrandBar extends StatelessWidget {
  const _BrandBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: HomiesColors.accent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: HomiesColors.accent.withValues(alpha: 0.30),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Text('🏡', style: TextStyle(fontSize: 17)),
        ),
        const SizedBox(width: 10),
        const Text(
          'homies',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: HomiesColors.text, letterSpacing: -0.3),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: HomiesColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: HomiesColors.border),
          ),
          child: const Text('Sharehouse, sorted',
              style: TextStyle(fontSize: 11, color: HomiesColors.textDim, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  final bool signedIn;
  final HomiesState state;
  const _Hero({required this.signedIn, required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [HomiesColors.accent, HomiesColors.accentStrong],
        ),
        boxShadow: [
          BoxShadow(
            color: HomiesColors.accent.withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('No more spreadsheets',
                style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 16),
          const Text(
            'Run a sharehouse\nwithout the drama.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              height: 1.12,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Bills, bond, chores, parties and complaints — one place, fair splits, less friction with your housemates.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 14.5, height: 1.4),
          ),
          const SizedBox(height: 22),
          if (signedIn) ...[
            _HeroPrimaryButton(
              label: 'Continue as ${state.currentUser!.name}',
              onPressed: () => context.go('/app'),
            ),
            const SizedBox(height: 10),
            _HeroGhostButton(
              label: 'Sign out',
              onPressed: () => state.signOut(),
            ),
          ] else ...[
            _HeroPrimaryButton(
              label: 'Create account',
              onPressed: () => context.push('/signup'),
            ),
            const SizedBox(height: 10),
            _HeroGhostButton(
              label: 'Sign in',
              onPressed: () => context.push('/login'),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _HeroPrimaryButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: HomiesColors.accentStrong,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}

class _HeroGhostButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _HeroGhostButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.55)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
        ),
        child: Text(label),
      ),
    );
  }
}

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
            color: HomiesColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: HomiesColors.borderStrong),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: HomiesColors.accentSoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.bolt_rounded, color: HomiesColors.accent, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Just looking?',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: HomiesColors.text)),
                    SizedBox(height: 2),
                    Text('Explore with a demo account — no signup needed.',
                        style: TextStyle(fontSize: 12.5, color: HomiesColors.textDim)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: HomiesColors.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarketplaceSection extends StatelessWidget {
  const _MarketplaceSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A2730), Color(0xFF3C3744)],
        ),
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
          const SizedBox(height: 14),
          const Text(
            'Got a free room? Find a housemate.',
            style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: -0.3),
          ),
          const SizedBox(height: 8),
          Text(
            'List an empty room or post what you’re after, message housemates directly, and ask prospective tenants for their track record before they move in.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.82), fontSize: 13.5, height: 1.45),
          ),
          const SizedBox(height: 14),
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

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11.5,
        color: HomiesColors.textFaint,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
      ),
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid();

  static const _features = [
    _FeatureData('💡', 'Bills & bond', 'Split utilities, track who paid, prorate by move-in date.', HomiesColors.warn),
    _FeatureData('🧹', 'Chores', 'A fair roster with photo proof and a paper trail.', HomiesColors.ok),
    _FeatureData('🎉', 'Parties & rules', 'Plan events, RSVP, and keep house rules clear.', HomiesColors.accent),
    _FeatureData('🚪', 'Move out clean', '2-week notice, bond release, deductions explained.', Color(0xFF356190)),
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
  final Color tint;
  const _FeatureData(this.icon, this.title, this.body, this.tint);
}

class _FeatureCard extends StatelessWidget {
  final _FeatureData data;
  const _FeatureCard(this.data);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HomiesColors.surface,
        border: Border.all(color: HomiesColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: data.tint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child: Text(data.icon, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(height: 10),
          Text(data.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: HomiesColors.text)),
          const SizedBox(height: 4),
          Text(data.body, style: const TextStyle(color: HomiesColors.textDim, fontSize: 12.5, height: 1.35)),
        ],
      ),
    );
  }
}

class _Reassurance extends StatelessWidget {
  const _Reassurance();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HomiesColors.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HomiesColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: HomiesColors.okSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.verified_user_rounded, color: HomiesColors.ok, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Transparent splits and a shared record everyone can trust — so the house stays drama-free.',
              style: TextStyle(fontSize: 12.5, color: HomiesColors.textDim, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
