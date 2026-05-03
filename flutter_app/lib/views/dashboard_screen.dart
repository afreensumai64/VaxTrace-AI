// VaxTrace AI — Dashboard Screen
// Analytics: coverage rate, high-risk count, sync status, overdue chart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../models/child.dart';
import '../theme.dart';
import 'smart_route_screen.dart';
import 'child_detail_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final highRiskAsync = ref.watch(highRiskChildrenProvider);
    final syncState = ref.watch(syncNotifierProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            const Icon(Icons.analytics, color: VaxColors.electricCyan, size: 20),
            const SizedBox(width: 8),
            const Text('Analytics Dashboard',
                style: TextStyle(color: VaxColors.electricCyan,
                    fontWeight: FontWeight.w700, fontSize: 16,
                    letterSpacing: 0.5)),
            const Spacer(),
            TextButton.icon(
              onPressed: () {
                ref.invalidate(dashboardStatsProvider);
                ref.invalidate(highRiskChildrenProvider);
              },
              icon: const Icon(Icons.refresh,
                  color: VaxColors.electricCyan, size: 16),
              label: const Text('Refresh',
                  style: TextStyle(color: VaxColors.electricCyan, fontSize: 12)),
            ),
          ]),
          const SizedBox(height: 16),

          // Stats grid
          statsAsync.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: VaxColors.electricCyan)),
            error: (e, _) => Text('Stats error: $e',
                style: const TextStyle(color: VaxColors.riskCritical)),
            data: (stats) => _StatsGrid(stats: stats),
          ),
          const SizedBox(height: 20),

          // Today's Route CTA
          highRiskAsync.when(
            data: (children) => _TodayRouteCard(children: children),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),

          // Sync status
          _SyncCard(syncState: syncState, onSync: () =>
              ref.read(syncNotifierProvider.notifier).sync()),
          const SizedBox(height: 20);

          // High-risk children
          Row(children: [
            const Icon(Icons.warning_amber,
                color: VaxColors.riskHigh, size: 18),
            const SizedBox(width: 6),
            const Text('High-Risk Children',
                style: TextStyle(color: VaxColors.white,
                    fontWeight: FontWeight.w700, fontSize: 15)),
            const Spacer(),
            highRiskAsync.when(
              data: (children) => TextButton(
                onPressed: children.isNotEmpty
                    ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => SmartRouteScreen(
                                children: children)))
                    : null,
                child: const Text('Route All →',
                    style: TextStyle(color: VaxColors.electricCyan,
                        fontSize: 13)),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ]),
          const SizedBox(height: 10),
          highRiskAsync.when(
            loading: () => const Center(
                child: CircularProgressIndicator(
                    color: VaxColors.electricCyan)),
            error: (e, _) => Text('Error: $e',
                style: const TextStyle(color: VaxColors.riskCritical)),
            data: (children) => children.isEmpty
                ? _NoHighRisk()
                : Column(
                    children: children.take(5)
                        .map((c) => _HighRiskTile(child: c))
                        .toList(),
                  ),
          ),
          const SizedBox(height: 20),

          // Risk distribution
          highRiskAsync.when(
            data: (children) => _RiskDistribution(
                allChildren: ref
                    .watch(childrenProvider)
                    .asData?.value ?? []),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 20),

          // Village zones (NGO view — online only)
          _VillageZonesSection(),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final Map<String, int> stats;
  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final total = stats['total'] ?? 0;
    final highRisk = stats['highRisk'] ?? 0;
    final unsynced = stats['unsynced'] ?? 0;
    final overdue = stats['overdue'] ?? 0;
    final coverage = total > 0
        ? ((total - overdue) / total * 100).toStringAsFixed(0)
        : '0';

    final tiles = [
      _StatTile('$total', 'Total Children',
          Icons.child_care, VaxColors.electricCyan),
      _StatTile('$coverage%', 'Coverage Rate',
          Icons.verified_user, VaxColors.riskLow),
      _StatTile('$highRisk', 'High Risk',
          Icons.warning, VaxColors.riskHigh),
      _StatTile('$overdue', 'Overdue',
          Icons.schedule, VaxColors.riskMedium),
      _StatTile('$unsynced', 'Unsynced',
          Icons.cloud_off, VaxColors.textSecondary),
    ];

    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.6,
      children: tiles,
    );
  }
}

class _StatTile extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;
  const _StatTile(this.value, this.label, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VaxColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(color: color,
                  fontWeight: FontWeight.w900, fontSize: 24)),
          Text(label,
              style: const TextStyle(
                  color: VaxColors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}

class _SyncCard extends StatelessWidget {
  final AsyncValue<String> syncState;
  final VoidCallback onSync;
  const _SyncCard({required this.syncState, required this.onSync});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VaxColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VaxColors.navyLight),
      ),
      child: Row(children: [
        const Icon(Icons.sync, color: VaxColors.electricCyan, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Backend Sync',
                  style: TextStyle(color: VaxColors.white,
                      fontWeight: FontWeight.w600)),
              syncState.when(
                loading: () => const Text('Syncing...',
                    style: TextStyle(
                        color: VaxColors.electricCyan, fontSize: 12)),
                data: (msg) => Text(msg,
                    style: const TextStyle(
                        color: VaxColors.textSecondary, fontSize: 12)),
                error: (e, _) => Text('Error: $e',
                    style: const TextStyle(
                        color: VaxColors.riskCritical, fontSize: 12)),
              ),
            ],
          ),
        ),
        ElevatedButton(
          onPressed: syncState.isLoading ? null : onSync,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
          child: const Text('Sync Now', style: TextStyle(fontSize: 13)),
        ),
      ]),
    );
  }
}

class _HighRiskTile extends ConsumerWidget {
  final Child child;
  const _HighRiskTile({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final riskColor = VaxColors.riskColor(child.riskLevel.name);
    final tts = ref.read(ttsServiceProvider);
    final hasExplanation =
        child.explanation != null && child.explanation!.isNotEmpty;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ChildDetailScreen(child: child)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: VaxColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: riskColor.withOpacity(0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: riskColor.withOpacity(0.15),
                ),
                child: Center(
                  child: Text(child.name[0],
                      style: TextStyle(color: riskColor,
                          fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(child.name,
                        style: const TextStyle(color: VaxColors.white,
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    Text(
                        '${child.villageName} · ${child.distanceFromClinicKm.toStringAsFixed(1)}km',
                        style: const TextStyle(
                            color: VaxColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Text('${child.riskScore.toStringAsFixed(0)}',
                  style: TextStyle(
                      color: riskColor,
                      fontWeight: FontWeight.w900, fontSize: 18)),
              if (hasExplanation) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => tts.speak(child.explanation!),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: VaxColors.electricCyan.withOpacity(0.12),
                    ),
                    child: const Icon(Icons.volume_up,
                        color: VaxColors.electricCyan, size: 16),
                  ),
                ),
              ],
            ]),
            if (hasExplanation) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 46),
                child: Text(
                  child.explanation!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: VaxColors.textSecondary,
                      fontSize: 12,
                      height: 1.4),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TodayRouteCard extends StatelessWidget {
  final List<Child> children;
  const _TodayRouteCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final criticalCount = children.where((c) => c.riskLevel == RiskLevel.critical).length;
    final highCount = children.where((c) => c.riskLevel == RiskLevel.high).length;

    return GestureDetector(
      onTap: children.isNotEmpty
          ? () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => SmartRouteScreen(children: children)))
          : null,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [VaxColors.electricCyan.withOpacity(0.18), VaxColors.riskHigh.withOpacity(0.12)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: VaxColors.electricCyan.withOpacity(0.5), width: 1.5),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: VaxColors.electricCyan.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.route, color: VaxColors.electricCyan, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("Today's Route",
                  style: TextStyle(color: VaxColors.white,
                      fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 3),
              Text(
                children.isEmpty
                    ? 'No high-risk children today'
                    : '${children.length} visits · $criticalCount critical · $highCount high',
                style: const TextStyle(color: VaxColors.textSecondary, fontSize: 12),
              ),
            ]),
          ),
          if (children.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: VaxColors.electricCyan,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('Open Map',
                  style: TextStyle(color: VaxColors.deepNavy,
                      fontWeight: FontWeight.w800, fontSize: 13)),
            ),
          ],
        ]),
      ),
    );
  }
}

class _NoHighRisk extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: VaxColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VaxColors.navyLight),
      ),
      child: const Center(
        child: Column(children: [
          Icon(Icons.check_circle, color: VaxColors.riskLow, size: 36),
          SizedBox(height: 8),
          Text('No high-risk children today',
              style: TextStyle(color: VaxColors.textSecondary)),
        ]),
      ),
    );
  }
}

class _VillageZonesSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(villageStatsProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VaxColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VaxColors.navyLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.map, color: VaxColors.electricCyan, size: 16),
            const SizedBox(width: 6),
            const Text('Village Zones',
                style: TextStyle(color: VaxColors.white,
                    fontWeight: FontWeight.w700, fontSize: 14)),
            const Spacer(),
            TextButton(
              onPressed: () => ref.invalidate(villageStatsProvider),
              style: TextButton.styleFrom(
                  minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
              child: const Text('Refresh', style: TextStyle(
                  color: VaxColors.electricCyan, fontSize: 11)),
            ),
          ]),
          const SizedBox(height: 4),
          const Text('Requires online connection',
              style: TextStyle(color: VaxColors.textSecondary, fontSize: 11)),
          const SizedBox(height: 12),
          statsAsync.when(
            loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(color: VaxColors.electricCyan, strokeWidth: 2),
                )),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(8),
              child: Row(children: [
                const Icon(Icons.wifi_off, color: VaxColors.textSecondary, size: 16),
                const SizedBox(width: 8),
                const Text('Offline — village data unavailable',
                    style: TextStyle(color: VaxColors.textSecondary, fontSize: 12)),
              ]),
            ),
            data: (villages) => Column(
              children: villages.map((v) => _VillageZoneTile(village: v)).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _VillageZoneTile extends StatelessWidget {
  final Map<String, dynamic> village;
  const _VillageZoneTile({required this.village});

  @override
  Widget build(BuildContext context) {
    final zone = village['zone'] as String;
    final color = VaxColors.riskColor(zone);
    final total = village['total_children'] as int;
    final highRisk = village['high_risk_count'] as int;
    final coverage = village['coverage_pct'] as double;
    final avgScore = village['avg_risk_score'] as double;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: VaxColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(village['village_name'] as String,
                style: const TextStyle(color: VaxColors.white,
                    fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 2),
            Text('$total children · $highRisk high-risk · ${coverage.toStringAsFixed(0)}% covered',
                style: const TextStyle(color: VaxColors.textSecondary, fontSize: 11)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(zone.toUpperCase(),
                style: TextStyle(color: color, fontSize: 10,
                    fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          ),
          const SizedBox(height: 3),
          Text('${avgScore.toStringAsFixed(0)} avg',
              style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
        ]),
      ]),
    );
  }
}

class _RiskDistribution extends StatelessWidget {
  final List<Child> allChildren;
  const _RiskDistribution({required this.allChildren});

  @override
  Widget build(BuildContext context) {
    if (allChildren.isEmpty) return const SizedBox.shrink();

    final counts = {
      'low': allChildren.where((c) => c.riskLevel == RiskLevel.low).length,
      'medium': allChildren.where((c) => c.riskLevel == RiskLevel.medium).length,
      'high': allChildren.where((c) => c.riskLevel == RiskLevel.high).length,
      'critical': allChildren.where((c) => c.riskLevel == RiskLevel.critical).length,
    };
    final total = allChildren.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VaxColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VaxColors.navyLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Risk Distribution',
              style: TextStyle(color: VaxColors.white,
                  fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 16),
          ...counts.entries.map((e) {
            final pct = total > 0 ? e.value / total : 0.0;
            final color = VaxColors.riskColor(e.key);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                SizedBox(
                  width: 60,
                  child: Text(e.key[0].toUpperCase() + e.key.substring(1),
                      style: TextStyle(color: color, fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: VaxColors.navyLight,
                      valueColor: AlwaysStoppedAnimation(color),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${e.value}',
                    style: const TextStyle(
                        color: VaxColors.white, fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ]),
            );
          }),
        ],
      ),
    );
  }
}
