import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../state/models.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/lifestyle_fields.dart';
import '../widgets/ui_kit.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Lifestyle? _lifestyle;
  EmergencyContact? _emergency;
  bool _shareEmergency = false;
  bool _sharePhone = true;
  bool _shareEmail = true;
  bool _shareLifestyle = true;
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final cu = HomiesScope.of(context).currentUser;
    _lifestyle = cu?.lifestyle?.copy() ?? Lifestyle();
    _emergency = cu?.emergency?.copy() ?? EmergencyContact();
    _shareEmergency = cu?.shareEmergency ?? false;
    _sharePhone = cu?.sharePhone ?? true;
    _shareEmail = cu?.shareEmail ?? true;
    _shareLifestyle = cu?.shareLifestyle ?? true;
  }

  void _save(HomiesState state) {
    final cu = state.currentUser;
    if (cu == null) return;
    state.mutate(() {
      cu.lifestyle = _lifestyle;
      cu.emergency = _emergency;
      cu.shareEmergency = _shareEmergency;
      cu.sharePhone = _sharePhone;
      cu.shareEmail = _shareEmail;
      cu.shareLifestyle = _shareLifestyle;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved ✓')));
  }

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final cu = state.currentUser!;
    final complete = (_lifestyle?.isComplete ?? false) && (_emergency?.isComplete ?? false);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const PageHead(
            title: 'Your profile',
            subtitle: 'Lifestyle answers and an emergency contact — everyone fills these in.',
          ),
          HomiesCard(
            child: Row(children: [
              Avatar.lg(cu),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(cu.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  Text('${cu.email}${cu.phone.isNotEmpty ? ' · ${cu.phone}' : ''}',
                      style: const TextStyle(color: HomiesColors.textDim, fontSize: 12)),
                ]),
              ),
              HomiesChip(complete ? 'Complete' : 'Incomplete', tone: complete ? ChipTone.ok : ChipTone.warn),
            ]),
          ),
          if (!complete)
            const InfoBanner(
              icon: Icons.info_outline,
              text: 'Answer the required lifestyle questions and add an emergency contact to complete your profile.',
            ),
          HomiesCard(
            child: LifestyleEmergencyForm(
              lifestyle: _lifestyle,
              emergency: _emergency,
              onChanged: (l, e) {
                _lifestyle = l;
                _emergency = e;
                setState(() {});
              },
            ),
          ),
          HomiesCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Privacy', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const Padding(
                padding: EdgeInsets.only(top: 2, bottom: 6),
                child: Text('Leaseholder and admin always see everything.',
                    style: TextStyle(color: HomiesColors.textDim, fontSize: 12)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _sharePhone,
                onChanged: (v) => setState(() => _sharePhone = v),
                activeThumbColor: HomiesColors.accent,
                title: const Text('Share phone number', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(
                  _sharePhone ? 'Housemates can see your phone number.' : 'Phone hidden from housemates.',
                  style: const TextStyle(color: HomiesColors.textDim, fontSize: 12),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _shareEmail,
                onChanged: (v) => setState(() => _shareEmail = v),
                activeThumbColor: HomiesColors.accent,
                title: const Text('Share email address', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(
                  _shareEmail ? 'Housemates can see your email.' : 'Email hidden from housemates.',
                  style: const TextStyle(color: HomiesColors.textDim, fontSize: 12),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _shareLifestyle,
                onChanged: (v) => setState(() => _shareLifestyle = v),
                activeThumbColor: HomiesColors.accent,
                title: const Text('Share lifestyle profile', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(
                  _shareLifestyle ? 'Housemates can see your lifestyle answers.' : 'Lifestyle profile hidden from housemates.',
                  style: const TextStyle(color: HomiesColors.textDim, fontSize: 12),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _shareEmergency,
                onChanged: (v) => setState(() => _shareEmergency = v),
                activeThumbColor: HomiesColors.accent,
                title: const Text('Share emergency contact', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(
                  _shareEmergency ? 'Housemates can see your emergency contact.' : 'Hidden from housemates.',
                  style: const TextStyle(color: HomiesColors.textDim, fontSize: 12),
                ),
              ),
            ]),
          ),
          if (cu.role == 'tenant') _LeaseholderRefCard(),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: () => _save(state), child: const Text('Save profile')),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}

class _LeaseholderRefCard extends StatefulWidget {
  const _LeaseholderRefCard();
  @override
  State<_LeaseholderRefCard> createState() => _LeaseholderRefCardState();
}

class _LeaseholderRefCardState extends State<_LeaseholderRefCard> {
  bool _editing = false;
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final cu = state.currentUser!;
    final leaseholders = state.users.where((u) => u.role == 'leaseholder').toList();
    final current = cu.leaseholderUserId != null ? state.findUser(cu.leaseholderUserId!) : null;

    return HomiesCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.person_pin_outlined, size: 18, color: HomiesColors.accent),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Your leaseholder', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => setState(() {
              _editing = !_editing;
              _selectedId = cu.leaseholderUserId;
            }),
            child: Text(_editing ? 'Cancel' : 'Edit'),
          ),
        ]),
        const Text(
          'Other leaseholders can request your performance reference directly from your leaseholder.',
          style: TextStyle(color: HomiesColors.textDim, fontSize: 12),
        ),
        const SizedBox(height: 10),
        if (!_editing) ...[
          if (current != null)
            Row(children: [
              Avatar.sm(current),
              const SizedBox(width: 8),
              Expanded(child: Text(current.name, style: const TextStyle(fontWeight: FontWeight.w600))),
              const HomiesChip('Linked', tone: ChipTone.ok),
            ])
          else
            const Text('Not set — tap Edit to link your leaseholder.',
                style: TextStyle(color: HomiesColors.textFaint, fontSize: 13)),
        ] else ...[
          for (final l in leaseholders)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _selectedId = l.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  Icon(
                    _selectedId == l.id ? Icons.radio_button_checked : Icons.radio_button_off,
                    size: 20,
                    color: _selectedId == l.id ? HomiesColors.accent : HomiesColors.textFaint,
                  ),
                  const SizedBox(width: 10),
                  Avatar.sm(l),
                  const SizedBox(width: 8),
                  Expanded(child: Text(l.name, style: const TextStyle(fontSize: 14))),
                ]),
              ),
            ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              state.mutate(() {
                cu.leaseholderUserId = _selectedId;
                cu.leaseholderName = _selectedId != null ? state.findUser(_selectedId!)?.name : null;
              });
              setState(() => _editing = false);
            },
            child: const Text('Save'),
          ),
        ],
      ]),
    );
  }
}
