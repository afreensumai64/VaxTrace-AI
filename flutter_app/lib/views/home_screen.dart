// VaxTrace AI — Home Screen
// Auth: JWT (no Firebase)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../models/child.dart';
import '../theme.dart';
import 'child_detail_screen.dart';
import 'snap_card_screen.dart';
import 'smart_route_screen.dart';
import 'dashboard_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _currentTab = 0;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.8, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectivity = ref.watch(connectivityProvider);
    final syncState = ref.watch(syncNotifierProvider);

    return Scaffold(
      backgroundColor: VaxColors.deepNavy,
      appBar: _buildAppBar(context, connectivity),
      body: IndexedStack(
        index: _currentTab,
        children: const [
          _ChildrenTab(),
          DashboardScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: _buildFab(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  AppBar _buildAppBar(BuildContext context, AsyncValue<bool> connectivity) {
    final isOnline = connectivity.asData?.value ?? false;
    return AppBar(
      backgroundColor: VaxColors.navyDark,
      title: Row(children: [
        const Icon(Icons.vaccines, color: VaxColors.electricCyan, size: 24),
        const SizedBox(width: 8),
        const Text('VaxTrace AI',
            style: TextStyle(
                color: VaxColors.white,
                fontWeight: FontWeight.w800,
                fontSize: 20)),
        const Spacer(),
        // Connectivity indicator
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isOnline
                ? VaxColors.riskLow.withOpacity(0.2)
                : VaxColors.riskHigh.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isOnline ? VaxColors.riskLow : VaxColors.riskHigh,
                width: 1),
          ),
          child: Row(children: [
            Icon(isOnline ? Icons.wifi : Icons.wifi_off,
                color: isOnline ? VaxColors.riskLow : VaxColors.riskHigh,
                size: 14),
            const SizedBox(width: 4),
            Text(isOnline ? 'Online' : 'Offline',
                style: TextStyle(
                    fontSize: 12,
                    color: isOnline ? VaxColors.riskLow : VaxColors.riskHigh,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.sync, color: VaxColors.electricCyan),
          onPressed: () => ref.read(syncNotifierProvider.notifier).sync(),
          tooltip: 'Sync',
        ),
        PopupMenuButton(
          icon: const Icon(Icons.more_vert, color: VaxColors.white),
          color: VaxColors.surface,
          itemBuilder: (_) => [
            PopupMenuItem(
              child: const Row(children: [
                Icon(Icons.language, color: VaxColors.electricCyan, size: 18),
                SizedBox(width: 8),
                Text('Language', style: TextStyle(color: VaxColors.white)),
              ]),
              onTap: () => _showLanguageDialog(context),
            ),
            PopupMenuItem(
              child: const Row(children: [
                Icon(Icons.logout, color: VaxColors.riskHigh, size: 18),
                SizedBox(width: 8),
                Text('Sign Out', style: TextStyle(color: VaxColors.riskHigh)),
              ]),
              onTap: () => ref.read(jwtAuthServiceProvider).signOut(),
            ),
          ],
        ),
      ]),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: VaxColors.surface,
        title: const Text('Select Language',
            style: TextStyle(color: VaxColors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: AppLanguage.values.map((lang) {
            final labels = {
              AppLanguage.english: '🇬🇧 English',
              AppLanguage.hindi: '🇮🇳 हिंदी',
              AppLanguage.tamil: '🇮🇳 தமிழ்',
            };
            return ListTile(
              title: Text(labels[lang]!,
                  style: const TextStyle(color: VaxColors.white)),
              onTap: () {
                ref.read(languageProvider.notifier).state = lang;
                ref.read(ttsServiceProvider).setLanguage(lang);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  BottomAppBar _buildBottomNav() {
    return BottomAppBar(
      color: VaxColors.navyDark,
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: Row(children: [
        Expanded(
          child: _NavItem(
            icon: Icons.people_outline,
            activeIcon: Icons.people,
            label: 'Children',
            isActive: _currentTab == 0,
            onTap: () => setState(() => _currentTab = 0),
          ),
        ),
        const SizedBox(width: 60), // FAB space
        Expanded(
          child: _NavItem(
            icon: Icons.bar_chart_outlined,
            activeIcon: Icons.bar_chart,
            label: 'Dashboard',
            isActive: _currentTab == 1,
            onTap: () => setState(() => _currentTab = 1),
          ),
        ),
      ]),
    );
  }

  FloatingActionButton _buildFab(BuildContext context) {
    return FloatingActionButton(
      backgroundColor: VaxColors.electricCyan,
      foregroundColor: VaxColors.deepNavy,
      onPressed: () => _showAddChildMenu(context),
      child: const Icon(Icons.add, size: 28),
    );
  }

  void _showAddChildMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: VaxColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: VaxColors.textSecondary,
                borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            const Text('Add Child Record',
                style: TextStyle(
                    color: VaxColors.white,
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            _ActionTile(
              icon: Icons.camera_alt,
              label: 'SnapCard OCR',
              subtitle: 'Scan vaccination card',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SnapCardScreen()));
              },
            ),
            const SizedBox(height: 12),
            _ActionTile(
              icon: Icons.edit_note,
              label: 'Manual Entry',
              subtitle: 'Type child details',
              onTap: () {
                Navigator.pop(context);
                // Navigate to manual entry form
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Children Tab
// ─────────────────────────────────────────────

class _ChildrenTab extends ConsumerWidget {
  const _ChildrenTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childrenAsync = ref.watch(childrenProvider);

    return childrenAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: VaxColors.electricCyan)),
      error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: VaxColors.riskCritical))),
      data: (children) => children.isEmpty
          ? const _EmptyState()
          : RefreshIndicator(
              color: VaxColors.electricCyan,
              backgroundColor: VaxColors.surface,
              onRefresh: () => ref.refresh(childrenProvider.future),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: children.length,
                itemBuilder: (ctx, i) => _ChildCard(child: children[i]),
              ),
            ),
    );
  }
}

class _ChildCard extends StatelessWidget {
  final Child child;
  const _ChildCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final riskColor = VaxColors.riskColor(child.riskLevel.name);
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ChildDetailScreen(child: child)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: VaxColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: child.isHighRisk
                ? riskColor.withOpacity(0.6)
                : VaxColors.navyLight,
            width: child.isHighRisk ? 1.5 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            // Avatar
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: riskColor.withOpacity(0.15),
                border: Border.all(color: riskColor, width: 2),
              ),
              child: Center(
                child: Text(
                  child.name[0].toUpperCase(),
                  style: TextStyle(
                      color: riskColor,
                      fontWeight: FontWeight.w800, fontSize: 20),
                ),
              ),
            ),
            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(child.name,
                      style: const TextStyle(
                          color: VaxColors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(child.villageName,
                      style: const TextStyle(
                          color: VaxColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.schedule, size: 13,
                        color: child.isOverdue
                            ? VaxColors.riskHigh : VaxColors.textSecondary),
                    const SizedBox(width: 3),
                    Text(
                      child.isOverdue
                          ? 'OVERDUE'
                          : child.nextDueDate != null
                              ? 'Due in ${child.daysUntilNextDose}d'
                              : 'No due date',
                      style: TextStyle(
                        fontSize: 12,
                        color: child.isOverdue
                            ? VaxColors.riskHigh : VaxColors.textSecondary,
                        fontWeight: child.isOverdue
                            ? FontWeight.w700 : FontWeight.normal,
                      ),
                    ),
                  ]),
                ],
              ),
            ),

            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: riskColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: riskColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    child.riskLevel.label.toUpperCase(),
                    style: TextStyle(
                        color: riskColor, fontSize: 10,
                        fontWeight: FontWeight.w800, letterSpacing: 0.5),
                  ),
                ),
                const SizedBox(height: 6),
                Text('${child.riskScore.toStringAsFixed(0)}pts',
                    style: const TextStyle(
                        color: VaxColors.electricCyan,
                        fontWeight: FontWeight.w700, fontSize: 16)),
                if (!child.isSynced)
                  const Icon(Icons.cloud_off, size: 14,
                      color: VaxColors.textSecondary),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.child_care, size: 72, color: VaxColors.textSecondary),
          const SizedBox(height: 16),
          const Text('No children registered',
              style: TextStyle(color: VaxColors.white, fontSize: 18,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Tap + to scan a vaccination card or add manually',
              textAlign: TextAlign.center,
              style: TextStyle(color: VaxColors.textSecondary)),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon, required this.activeIcon,
    required this.label, required this.isActive, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isActive ? activeIcon : icon,
              color: isActive ? VaxColors.electricCyan : VaxColors.textSecondary),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: isActive ? VaxColors.electricCyan : VaxColors.textSecondary,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.normal)),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label, subtitle;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.label,
      required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      tileColor: VaxColors.surfaceLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: VaxColors.electricCyan.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: VaxColors.electricCyan, size: 22),
      ),
      title: Text(label, style: const TextStyle(
          color: VaxColors.white, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(
          color: VaxColors.textSecondary, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: VaxColors.textSecondary),
    );
  }
}
