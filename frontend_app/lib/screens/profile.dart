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
  }

  void _save(HomiesState state) {
    final cu = state.currentUser;
    if (cu == null) return;
    state.mutate(() {
      cu.lifestyle = _lifestyle;
      cu.emergency = _emergency;
      cu.shareEmergency = _shareEmergency;
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
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _shareEmergency,
                onChanged: (v) => setState(() => _shareEmergency = v),
                activeThumbColor: HomiesColors.accent,
                title: const Text('Share emergency contact with housemates',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(
                  _shareEmergency
                      ? 'Housemates can see your emergency contact.'
                      : 'Hidden from housemates. The leaseholder can always see it.',
                  style: const TextStyle(color: HomiesColors.textDim, fontSize: 12),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: () => _save(state), child: const Text('Save profile')),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}
