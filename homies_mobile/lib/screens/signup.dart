import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/ui_kit.dart';

class InviteHandoff {
  final String code;
  final String email;
  final String role;
  const InviteHandoff({required this.code, required this.email, required this.role});
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
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.invite != null) {
      _step = 'details';
      _role = widget.invite!.role;
      _emailCtrl.text = widget.invite!.email;
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

    setState(() => _submitting = true);
    final result = await state.signUpWithEmail(
      email: email,
      password: password,
      name: name,
      role: _role ?? 'tenant',
      phone: _phoneCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (!result.ok) {
      _showError(result.error ?? 'Sign-up failed.');
      return;
    }
    final inviteCode = widget.invite?.code;
    if (inviteCode != null) {
      state.mutate(() {
        for (final i in state.invites) {
          if (i.code == inviteCode) {
            i.status = 'accepted';
          }
        }
      });
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
        title: 'Tenant',
        body: "Tenants join by invite only — ask your leaseholder to send you an invite link, then open it to create your account.",
        onTap: null,
      ),
      const SizedBox(height: 12),
      TextButton(onPressed: () => context.push('/login'), child: const Text('Already have an account? Sign in')),
      TextButton(onPressed: () => context.go('/'), child: const Text('Back')),
    ]);
  }

  Widget _detailsView(HomiesState state) {
    final invite = widget.invite;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('${_role == 'leaseholder' ? 'Leaseholder' : 'Tenant'} signup',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      const Text("Create your account. You'll add property and lease details next.",
          style: TextStyle(color: HomiesColors.textDim)),
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
      const FieldLabel('Full name'),
      TextField(controller: _nameCtrl),
      const SizedBox(height: 12),
      const FieldLabel('Email'),
      TextField(
        controller: _emailCtrl,
        keyboardType: TextInputType.emailAddress,
        readOnly: invite != null,
        decoration: const InputDecoration(hintText: 'you@example.com'),
      ),
      if (invite != null) const Hint('Use the email the invite was sent to.'),
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
