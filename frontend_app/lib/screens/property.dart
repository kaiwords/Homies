import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/ui_kit.dart';

const _featureLabels = {
  'balcony': 'Balcony',
  'garage': 'Garage / parking',
  'furnished': 'Furnished',
  'swimmingPool': 'Swimming pool',
  'gym': 'Gym',
  'airCon': 'Air conditioning',
  'dishwasher': 'Dishwasher',
  'laundry': 'In-unit laundry',
  'petsAllowed': 'Pets allowed',
  'nbn': 'NBN included',
};

class PropertyScreen extends StatelessWidget {
  const PropertyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final p = state.property;
    final isLeaseholder = state.currentUser?.role == 'leaseholder';
    final features = p.features.entries.where((e) => e.value).map((e) => _featureLabels[e.key] ?? e.key).toList();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PageHead(
            title: 'Property & lease',
            subtitle: 'The details every housemate should know.',
            action: isLeaseholder ? OutlinedButton(onPressed: () {}, child: const Text('Edit')) : null,
          ),
          HomiesCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.address, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              Text('${p.type} · ${p.bedrooms} bed · ${p.bathrooms} bath · sleeps ${p.maxOccupants}',
                  style: const TextStyle(color: HomiesColors.textDim)),
              if (features.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 6, children: [for (final f in features) HomiesChip(f)]),
              ],
            ]),
          ),
          HomiesCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Lease', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              StatRow(tiles: [
                StatTile(label: 'Start', value: fmtDate(p.leaseStart), valueFontSize: 16),
                StatTile(label: 'End', value: fmtDate(p.leaseEnd), valueFontSize: 16),
                StatTile(label: 'Agent', value: p.agent.isEmpty ? '—' : p.agent, valueFontSize: 14, sub: p.agentContact),
              ]),
            ]),
          ),
          HomiesCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Rent & bond', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              StatRow(tiles: [
                StatTile(label: 'Rent', value: fmtAUD(p.rentAmount), sub: '${cadenceLabel(p.rentCadence)} · starts ${fmtDate(p.rentStartDate)}'),
                StatTile(label: 'Bond required', value: '${p.bondWeeks} weeks', sub: '≈ ${fmtAUD(p.rentAmount * p.bondWeeks)} for the property'),
                StatTile(label: 'Advance rent', value: '${p.advanceWeeks} weeks', sub: 'collected before move-in'),
              ]),
            ]),
          ),
          if (!isLeaseholder)
            const InfoBanner(
              icon: Icons.info_outline,
              text: 'Only the leaseholder can edit property & lease details. Speak to them if anything looks off.',
            ),
        ]),
      ),
    );
  }
}
