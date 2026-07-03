import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme.dart';
import '../widgets/ui_kit.dart';
import 'signup.dart' show InviteHandoff;

class AcceptInviteScreen extends StatefulWidget {
  final String code;
  const AcceptInviteScreen({super.key, required this.code});

  @override
  State<AcceptInviteScreen> createState() => _AcceptInviteScreenState();
}

class _AcceptInviteScreenState extends State<AcceptInviteScreen> {
  late final Future<DocumentSnapshot<Map<String, dynamic>>> _future =
      FirebaseFirestore.instance.collection('invites').doc(widget.code).get();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: HomiesCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text("You've been invited 🎉", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    future: _future,
                    builder: (context, snap) {
                      if (snap.connectionState != ConnectionState.done) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final data = snap.data?.data();
                      final status = data?['status'] as String?;
                      if (snap.hasError || data == null || status != 'sent') {
                        return const Text(
                          "That invite code isn't recognised, or it's already been used. Ask the leaseholder for a fresh link.",
                          style: TextStyle(color: HomiesColors.textDim),
                        );
                      }
                      final email = (data['email'] as String?) ?? '';
                      final phone = (data['phone'] as String?) ?? '';
                      final role = (data['role'] as String?) ?? 'tenant';
                      final houseId = data['houseId'] as String?;
                      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Text('You were invited to join as a $role.',
                            style: const TextStyle(color: HomiesColors.textDim)),
                        const SizedBox(height: 12),
                        HomiesCard(
                          color: HomiesColors.surface2,
                          child: Column(children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              const Text('Invite code', style: TextStyle(color: HomiesColors.textDim, fontSize: 12)),
                              Text(widget.code, style: const TextStyle(fontFamily: 'monospace')),
                            ]),
                            if (email.isNotEmpty || phone.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                const Text('Sent to', style: TextStyle(color: HomiesColors.textDim, fontSize: 12)),
                                Text(email.isNotEmpty ? email : phone),
                              ]),
                            ],
                          ]),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: houseId == null
                              ? null
                              : () => context.push(
                                    '/signup',
                                    extra: InviteHandoff(
                                      code: widget.code,
                                      email: email,
                                      phone: phone.isEmpty ? null : phone,
                                      role: role,
                                      houseId: houseId,
                                    ),
                                  ),
                          child: const Text('Accept & create account'),
                        ),
                      ]);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextButton(onPressed: () => context.go('/'), child: const Text('Back to home')),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
