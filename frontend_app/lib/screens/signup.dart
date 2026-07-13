import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/ui_kit.dart';
import 'browser_profile_prompt.dart';

class InviteHandoff {
  final String code;
  final String email;
  final String? phone;
  final String role;
  final String houseId;
  const InviteHandoff({required this.code, required this.email, this.phone, required this.role, required this.houseId});
}

class SignupScreen extends StatefulWidget {
  final InviteHandoff? invite;
  const SignupScreen({super.key, this.invite});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  late String _step;
  String? _role;
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _businessNameCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.invite != null) {
      _step = 'details';
      _role = widget.invite!.role;
      _emailCtrl.text = widget.invite!.email;
      _phoneCtrl.text = widget.invite!.phone ?? '';
    } else {
      _step = 'role';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _businessNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(HomiesState state) async {
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;
    final name = _nameCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError('Email and password are required.');
      return;
    }
    if (password.length < 6) {
      _showError('Password must be at least 6 characters.');
      return;
    }
    if (_role == 'business' && _businessNameCtrl.text.trim().isEmpty) {
      _showError('Business name is required.');
      return;
    }

    // A house member is a leaseholder (who sets up the property) or anyone who
    // signs up through a leaseholder's invite. A plain sign-up is a "browser"
    // who can only see the marketplace until they're invited in. Business
    // accounts are never members — they have no house features at all.
    final isMember = widget.invite != null || _role == 'leaseholder';

    setState(() => _submitting = true);
    final result = await state.signUpWithEmail(
      email: email,
      password: password,
      name: name,
      role: _role ?? 'tenant',
      phone: _phoneCtrl.text.trim(),
      member: isMember,
      businessName: _role == 'business' ? _businessNameCtrl.text.trim() : null,
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (!result.ok) {
      _showError(result.error ?? 'Sign-up failed.');
      return;
    }

    final invite = widget.invite;
    if (invite != null && state.currentUser != null) {
      try {
        await state.joinHouseByCode(invite.code);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Joined, but couldn't finish linking your account to the house — you may need to ask for a fresh invite. ($e)")),
          );
        }
      }
    }
    if (!mounted) return;
    if (_role == 'business') {
      // Business accounts skip the lifestyle/emergency prompt entirely — it's
      // irrelevant for a seller-only account with no house features.
      context.go('/app/essentials');
      return;
    }
    if (!isMember) {
      // Browsers skip house onboarding, but get a quick (skippable) prompt
      // to fill in their profile before landing in the marketplace — it's
      // what leaseholders see when this person later applies for a room.
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const BrowserProfilePromptScreen()));
      if (!mounted) return;
      context.go('/app/listings');
      return;
    }
    context.go(_role == 'leaseholder' ? '/onboarding/leaseholder' : '/onboarding/tenant');
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: HomiesCard(
                child: _step == 'role' ? _roleView() : _detailsView(state),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _roleView() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: const [
        Icon(Icons.circle, size: 12, color: HomiesColors.accent),
        SizedBox(width: 8),
        Text('Create account', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 6),
      const Text("First — what's your role in the property?", style: TextStyle(color: HomiesColors.textDim)),
      const SizedBox(height: 14),
      _RoleCard(
        icon: '🔑',
        title: 'Leaseholder',
        body: "I hold the lease (alone or with co-leaseholders). I'll set up the property, invite tenants, and manage bond, bills, and rules.",
        onTap: () => setState(() {
          _role = 'leaseholder';
          _step = 'details';
        }),
      ),
      const SizedBox(height: 10),
      _RoleCard(
        icon: '🛋️',
        title: 'Looking for a room',
        body: "Browse rooms and message leaseholders. You'll get full house access once a leaseholder invites you in.",
        onTap: () => setState(() {
          _role = 'tenant';
          _step = 'details';
        }),
      ),
      const SizedBox(height: 10),
      _RoleCard(
        icon: '🏪',
        title: 'Business',
        body: "I run a business and want to post services or items for sale. No house features here — just your listings and analytics.",
        onTap: () => setState(() {
          _role = 'business';
          _step = 'details';
        }),
      ),
      const SizedBox(height: 12),
      TextButton(onPressed: () => context.push('/login'), child: const Text('Already have an account? Sign in')),
      TextButton(onPressed: () => context.go('/'), child: const Text('Back')),
    ]);
  }

  Widget _detailsView(HomiesState state) {
    final invite = widget.invite;
    final isBusiness = _role == 'business';
    final isBrowser = invite == null && _role == 'tenant';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(
          isBusiness
              ? 'Business signup'
              : isBrowser
                  ? 'Create your account'
                  : '${_role == 'leaseholder' ? 'Leaseholder' : 'Tenant'} signup',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text(
          isBusiness
              ? "Set up your seller account to post services or items for sale — no house features here, just your listings and analytics."
              : isBrowser
                  ? 'Browse rooms and message leaseholders straight away. A leaseholder can invite you into their house anytime.'
                  : "Create your account. You'll add property and lease details next.",
          style: const TextStyle(color: HomiesColors.textDim)),
      if (invite != null) ...[
        const SizedBox(height: 10),
        HomiesCard(
          color: HomiesColors.surface2,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Joining by invite',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: HomiesColors.textDim)),
            Text('Code ${invite.code} · role locked to ${invite.role}',
                style: const TextStyle(fontSize: 12)),
          ]),
        ),
      ],
      const SizedBox(height: 14),
      if (isBusiness) ...[
        const FieldLabel('Business name'),
        TextField(
          controller: _businessNameCtrl,
          decoration: const InputDecoration(hintText: "e.g. Sam's Cleaning Co."),
        ),
        const SizedBox(height: 12),
      ],
      const FieldLabel('Full name'),
      TextField(controller: _nameCtrl),
      const SizedBox(height: 12),
      const FieldLabel('Email'),
      TextField(
        controller: _emailCtrl,
        keyboardType: TextInputType.emailAddress,
        readOnly: invite != null && invite.email.isNotEmpty,
        decoration: const InputDecoration(hintText: 'you@example.com'),
      ),
      if (invite != null && invite.email.isNotEmpty) const Hint('Use the email the invite was sent to.'),
      const SizedBox(height: 12),
      const FieldLabel('Mobile number (optional)'),
      TextField(
        controller: _phoneCtrl,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(hintText: '+61 4XX XXX XXX'),
      ),
      const SizedBox(height: 12),
      const FieldLabel('Password'),
      TextField(controller: _passCtrl, obscureText: true),
      const Hint('At least 6 characters.'),
      const SizedBox(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        invite != null
            ? TextButton(onPressed: () => context.go('/'), child: const Text('← Back'))
            : TextButton(
                onPressed: _submitting ? null : () => setState(() => _step = 'role'),
                child: const Text('← Change role'),
              ),
        ElevatedButton(
          onPressed: _submitting ? null : () => _submit(state),
          child: _submitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Create account →'),
        ),
      ]),
    ]);
  }
}

class _RoleCard extends StatelessWidget {
  final String icon;
  final String title;
  final String body;
  final VoidCallback? onTap;
  const _RoleCard({required this.icon, required this.title, required this.body, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Opacity(
      opacity: disabled ? 0.6 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(border: Border.all(color: HomiesColors.border), borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(icon, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 6),
            Row(children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              if (disabled) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: HomiesColors.surface2, borderRadius: BorderRadius.circular(10)),
                  child: const Text('invite only', style: TextStyle(fontSize: 10, color: HomiesColors.textDim)),
                ),
              ],
            ]),
            const SizedBox(height: 4),
            Text(body, style: const TextStyle(color: HomiesColors.textDim, fontSize: 12)),
          ]),
        ),
      ),
    );
  }
}
