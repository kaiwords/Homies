import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../state/models.dart';
import '../theme.dart';
import '../widgets/lifestyle_fields.dart';

/// Shown once, right after a "browser" (non-invited, room-seeking) signup —
/// prompts them to fill in the same lifestyle/emergency-contact profile that
/// invited housemates complete during onboarding. Not blocking: skippable,
/// and always editable later from Settings → Your Profile.
class BrowserProfilePromptScreen extends StatefulWidget {
  const BrowserProfilePromptScreen({super.key});

  @override
  State<BrowserProfilePromptScreen> createState() => _BrowserProfilePromptScreenState();
}

class _BrowserProfilePromptScreenState extends State<BrowserProfilePromptScreen> {
  Lifestyle? _lifestyle;
  EmergencyContact? _emergency;

  void _save(HomiesState state) {
    final cu = state.currentUser;
    if (cu != null) {
      state.mutate(() {
        cu.lifestyle = _lifestyle;
        cu.emergency = _emergency;
      });
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Tell us about yourself')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text(
              'This helps leaseholders get to know you when you apply for a room — you can always finish this later in Settings.',
              style: TextStyle(color: HomiesColors.textDim, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            LifestyleEmergencyForm(
              lifestyle: _lifestyle,
              emergency: _emergency,
              onChanged: (l, e) {
                _lifestyle = l;
                _emergency = e;
              },
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => _save(state),
              style: FilledButton.styleFrom(
                backgroundColor: HomiesColors.accent,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text('Save & continue'),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Skip for now'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
