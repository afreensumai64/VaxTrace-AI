// VaxTrace AI — Child Detail Screen
// Full profile with vaccination history, risk score, and AI explanation card

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/child.dart';
import '../providers/providers.dart';
import '../theme.dart';
import 'smart_route_screen.dart';

class ChildDetailScreen extends ConsumerWidget {
  final Child child;
  const ChildDetailScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch for live updates (explanation cached after prediction)
    final childAsync = ref.watch(childByIdProvider(child.id));
    final liveChild = childAsync.asData?.value ?? child;

    final recordsAsync = ref.watch(vaccinationRecordsProvider(child.id));
    final riskColor = VaxColors.riskColor(liveChild.riskLevel.name);

    return Scaffold(
      backgroundColor: VaxColors.deepNavy,
      body: CustomScrollView(
        slivers: [
          // Hero header
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: VaxColors.navyDark,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [riskColor.withOpacity(0.3), VaxColors.navyDark],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 48),
                      Container(
                        width: 72, height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: riskColor.withOpacity(0.15),
                          border: Border.all(color: riskColor, width: 3),
                        ),
                        child: Center(
                          child: Text(liveChild.name[0].toUpperCase(),
                              style: TextStyle(color: riskColor,
                                  fontWeight: FontWeight.w900, fontSize: 30)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(liveChild.name,
                          style: const TextStyle(color: VaxColors.white,
                              fontSize: 22, fontWeight: FontWeight.w800)),
                      Text('Guardian: ${liveChild.guardianName}',
                          style: const TextStyle(
                              color: VaxColors.textSecondary, fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              // GuardianVoice button
              IconButton(
                icon: const Icon(Icons.record_voice_over,
                    color: VaxColors.electricCyan),
                tooltip: 'Speak Reminder',
                onPressed: () async {
                  final lang = ref.read(languageProvider);
                  final tts = ref.read(ttsServiceProvider);
                  await tts.setLanguage(lang);
                  await tts.speakVaccineReminder(liveChild);
                },
              ),
              // Smart Route
              IconButton(
                icon: const Icon(Icons.route, color: VaxColors.electricCyan),
                tooltip: 'Smart Route',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => SmartRouteScreen(children: [liveChild])),
                ),
              ),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Risk score card
                _RiskCard(child: liveChild, riskColor: riskColor),
                const SizedBox(height: 16),

                // AI Explanation card (only for high-risk)
                if (liveChild.isHighRisk)
                  _AiExplanationCard(child: liveChild),
                if (liveChild.isHighRisk)
                  const SizedBox(height: 16),

                // Info grid
                _InfoGrid(child: liveChild),
                const SizedBox(height: 20),

                const Text('Vaccination History',
                    style: TextStyle(color: VaxColors.electricCyan,
                        fontWeight: FontWeight.w700, fontSize: 14,
                        letterSpacing: 1)),
                const SizedBox(height: 12),

                recordsAsync.when(
                  loading: () => const Center(
                      child: CircularProgressIndicator(
                          color: VaxColors.electricCyan)),
                  error: (e, _) => Text('Error: $e',
                      style: const TextStyle(color: VaxColors.riskCritical)),
                  data: (records) => records.isEmpty
                      ? const _NoRecords()
                      : Column(
                          children: records
                              .map((r) => _VaccineRecordTile(record: r))
                              .toList()),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// AI Explanation Card (Hero Feature)
// ─────────────────────────────────────────────

class _AiExplanationCard extends ConsumerWidget {
  final Child child;
  const _AiExplanationCard({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final predState = ref.watch(riskPredictionProvider(child.id));
    final tts = ref.read(ttsServiceProvider);
    final riskColor = VaxColors.riskColor(child.riskLevel.name);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VaxColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VaxColors.electricCyan.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: VaxColors.electricCyan.withOpacity(0.06),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.auto_awesome,
                color: VaxColors.electricCyan, size: 16),
            const SizedBox(width: 6),
            const Text('AI Analysis',
                style: TextStyle(
                    color: VaxColors.electricCyan,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 0.5)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: riskColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: riskColor.withOpacity(0.4)),
              ),
              child: Text(child.riskLevel.label.toUpperCase(),
                  style: TextStyle(
                      color: riskColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 10)),
            ),
          ]),
          const SizedBox(height: 12),

          if (predState.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Row(children: [
                SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                      color: VaxColors.electricCyan, strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Analyzing with AI...',
                    style: TextStyle(
                        color: VaxColors.textSecondary, fontSize: 13)),
              ]),
            )
          else if (predState.error != null)
            _ErrorRow(error: predState.error!, onRetry: () => _runPrediction(ref))
          else if (child.explanation != null && child.explanation!.isNotEmpty) ...[
            Text(child.explanation!,
                style: const TextStyle(
                    color: VaxColors.white,
                    fontSize: 14,
                    height: 1.5)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => tts.speak(child.explanation!),
                  icon: const Icon(Icons.volume_up, size: 18),
                  label: const Text('Listen'),
                  style: FilledButton.styleFrom(
                    backgroundColor: VaxColors.electricCyan,
                    foregroundColor: VaxColors.deepNavy,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    textStyle: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () => _runPrediction(ref),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: VaxColors.electricCyan,
                  side: BorderSide(
                      color: VaxColors.electricCyan.withOpacity(0.4)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
            ]),
          ] else ...[
            Text(
              'Get an AI-generated explanation of why this child is at risk '
              'and what action to take.',
              style: const TextStyle(
                  color: VaxColors.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _runPrediction(ref),
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('Analyze Risk'),
                style: FilledButton.styleFrom(
                  backgroundColor: VaxColors.electricCyan,
                  foregroundColor: VaxColors.deepNavy,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _runPrediction(WidgetRef ref) {
    ref.read(riskPredictionProvider(child.id).notifier).predict(
          childId: child.id,
          distanceKm: child.distanceFromClinicKm,
          daysSinceLastDose: child.daysSinceLastDose == 9999
              ? 0
              : child.daysSinceLastDose,
        );
  }
}

class _ErrorRow extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorRow({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      const Icon(Icons.error_outline,
          color: VaxColors.riskCritical, size: 16),
      const SizedBox(width: 8),
      Expanded(
        child: Text('Could not reach AI service. Check connection.',
            style: const TextStyle(
                color: VaxColors.textSecondary, fontSize: 12)),
      ),
      TextButton(
        onPressed: onRetry,
        child: const Text('Retry',
            style: TextStyle(color: VaxColors.electricCyan, fontSize: 12)),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────
// Existing widgets (unchanged)
// ─────────────────────────────────────────────

class _RiskCard extends StatelessWidget {
  final Child child;
  final Color riskColor;
  const _RiskCard({required this.child, required this.riskColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: VaxColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: riskColor.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Risk Score',
                  style: TextStyle(color: VaxColors.textSecondary, fontSize: 13)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: riskColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: riskColor.withOpacity(0.5)),
                ),
                child: Text(child.riskLevel.label.toUpperCase(),
                    style: TextStyle(color: riskColor,
                        fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (child.riskScore / 100).clamp(0.0, 1.0),
              backgroundColor: VaxColors.navyLight,
              valueColor: AlwaysStoppedAnimation(riskColor),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${child.riskScore.toStringAsFixed(1)} / 100',
                  style: TextStyle(
                      color: riskColor,
                      fontWeight: FontWeight.w800, fontSize: 22)),
              if (child.isOverdue)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: VaxColors.riskCritical.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('⚠ OVERDUE',
                      style: TextStyle(color: VaxColors.riskCritical,
                          fontWeight: FontWeight.w800, fontSize: 12)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  final Child child;
  const _InfoGrid({required this.child});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Village', child.villageName, Icons.location_on),
      ('Phone', child.guardianPhone, Icons.phone),
      ('Distance', '${child.distanceFromClinicKm.toStringAsFixed(1)} km',
          Icons.directions_walk),
      ('Last Dose', child.lastDoseDate != null
          ? '${child.lastDoseDate!.day}/${child.lastDoseDate!.month}/${child.lastDoseDate!.year}'
          : 'Unknown', Icons.vaccines),
      ('Next Due', child.nextDueDate != null
          ? '${child.nextDueDate!.day}/${child.nextDueDate!.month}/${child.nextDueDate!.year}'
          : 'Not set', Icons.schedule),
      ('Days Overdue', child.isOverdue
          ? '${-child.daysUntilNextDose}d'
          : 'On track', Icons.timelapse),
    ];

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.5,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final (label, value, icon) = items[i];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: VaxColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: VaxColors.navyLight),
          ),
          child: Row(children: [
            Icon(icon, color: VaxColors.electricCyan, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: VaxColors.textSecondary, fontSize: 10)),
                  Text(value,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: VaxColors.white, fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ],
              ),
            ),
          ]),
        );
      },
    );
  }
}

class _VaccineRecordTile extends StatelessWidget {
  final dynamic record;
  const _VaccineRecordTile({required this.record});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VaxColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VaxColors.navyLight),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: VaxColors.electricCyan.withOpacity(0.1),
          ),
          child: const Icon(Icons.vaccines,
              color: VaxColors.electricCyan, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(record.vaccineName,
                  style: const TextStyle(color: VaxColors.white,
                      fontWeight: FontWeight.w600)),
              Text('Dose ${record.doseNumber} · ${record.administeredBy}',
                  style: const TextStyle(
                      color: VaxColors.textSecondary, fontSize: 12)),
            ],
          ),
        ),
        Text(
          '${record.dateAdministered.day}/${record.dateAdministered.month}/${record.dateAdministered.year}',
          style: const TextStyle(color: VaxColors.textSecondary, fontSize: 12),
        ),
      ]),
    );
  }
}

class _NoRecords extends StatelessWidget {
  const _NoRecords();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: VaxColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Text('No vaccination records yet',
            style: TextStyle(color: VaxColors.textSecondary)),
      ),
    );
  }
}
