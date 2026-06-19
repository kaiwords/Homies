import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/ui_kit.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(HomiesState state) async {
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      _showError('Email and password are required.');
      return;
    }
    setState(() => _submitting = true);
    final result = await state.signInWithEmail(email: email, password: password);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!result.ok) {
      _showError(result.error ?? 'Sign-in failed.');
      return;
    }
    context.go('/app');
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
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: HomiesCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: const [
                    Icon(Icons.circle, size: 12, color: HomiesColors.accent),
                    SizedBox(width: 8),
                    Text('Sign in', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 6),
                  const Text('Welcome back.', style: TextStyle(color: HomiesColors.textDim)),
                  const SizedBox(height: 14),
                  const FieldLabel('Email'),
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(hintText: 'you@example.com'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  const FieldLabel('Password'),
                  TextField(
                    controller: _passCtrl,
                    obscureText: true,
                    onSubmitted: (_) => _submit(state),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _submitting ? null : () => _submit(state),
                    child: _submitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Sign in'),
                  ),
                  const SizedBox(height: 10),
                  TextButton(onPressed: () => context.push('/signup'), child: const Text('New here? Create an account')),
                  TextButton(onPressed: () => context.go('/'), child: const Text('Back')),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
