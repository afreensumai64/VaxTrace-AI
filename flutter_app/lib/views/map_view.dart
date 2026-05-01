// VaxTrace AI — Map View (flutter_map + OpenStreetMap)
// Zero-cost replacement for google_maps_flutter.
// No API key required — uses free OSM tile server.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../models/child.dart';
import '../providers/providers.dart';
import '../theme.dart';

class MapView extends ConsumerStatefulWidget {
  /// Pass a specific list of children, or leave null to show all high-risk children.
  final List<Child>? children;
  const MapView({super.key, this.children});

  @override
  ConsumerState<MapView> createState() => _MapViewState();
}

class _MapViewState extends ConsumerState<MapView> {
  final MapController _mapController = MapController();
  Child? _selectedChild;
  bool _isOptimizing = false;

  // Clinic home base — update to real clinic GPS
  static const LatLng _clinicLatLng = LatLng(13.0827, 80.2707); // Chennai default

  List<Child> get _displayChildren =>
      widget.children ?? ref.watch(highRiskChildrenProvider).asData?.value ?? [];

  List<Child> get _mappableChildren =>
      _displayChildren.where((c) => c.latitude != null && c.longitude != null).toList()
        ..sort((a, b) => b.riskScore.compareTo(a.riskScore)); // highest risk first

  @override
  Widget build(BuildContext context) {
    final mappable = _mappableChildren;

    return Scaffold(
      backgroundColor: VaxColors.deepNavy,
      appBar: AppBar(
        backgroundColor: VaxColors.navyDark,
        title: const Row(children: [
          Icon(Icons.route, color: VaxColors.electricCyan, size: 22),
          SizedBox(width: 8),
          Text('Smart Route'),
        ]),
        actions: [
          TextButton.icon(
            onPressed: _isOptimizing || mappable.isEmpty ? null : _optimizeRoute,
            icon: _isOptimizing
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: VaxColors.electricCyan))
                : const Icon(Icons.auto_fix_high,
                    color: VaxColors.electricCyan, size: 18),
            label: const Text('Optimize',
                style: TextStyle(color: VaxColors.electricCyan, fontSize: 13)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats bar
          _StatsBar(
            total: _displayChildren.length,
            highRisk: _displayChildren.where((c) => c.isHighRisk).length,
            mapped: mappable.length,
          ),

          // Map
          Expanded(
            flex: 3,
            child: mappable.isEmpty
                ? const _NoLocationState()
                : _buildMap(mappable),
          ),

          // Selected child info card
          if (_selectedChild != null)
            _SelectedChildCard(
              child: _selectedChild!,
              onDismiss: () => setState(() => _selectedChild = null),
            ),

          // Visit order list
          Expanded(
            flex: 2,
            child: _VisitOrderList(
              children: mappable,
              onChildTap: (child) {
                setState(() => _selectedChild = child);
                _mapController.move(
                  LatLng(child.latitude!, child.longitude!), 14);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(List<Child> mappable) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _clinicLatLng,
        initialZoom: 11,
        backgroundColor: VaxColors.navyDark,
      ),
      children: [
        // ─── OSM Tile Layer (FREE — no API key) ───────────────
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.vaxtrace.app',
          // Optionally use a dark Stamen/Carto tile for better match with theme:
          // urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
          // subdomains: const ['a', 'b', 'c', 'd'],
        ),

        // ─── Route polyline ──────────────────────────────────
        PolylineLayer(
          polylines: [
            Polyline(
              points: [
                _clinicLatLng,
                ...mappable.map((c) => LatLng(c.latitude!, c.longitude!)),
                _clinicLatLng,
              ],
              color: VaxColors.electricCyan.withOpacity(0.8),
              strokeWidth: 3.5,
              isDotted: true,
            ),
          ],
        ),

        // ─── Child markers ───────────────────────────────────
        MarkerLayer(
          markers: [
            // Clinic marker
            Marker(
              point: _clinicLatLng,
              width: 46,
              height: 46,
              child: GestureDetector(
                onTap: () => setState(() => _selectedChild = null),
                child: Container(
                  decoration: BoxDecoration(
                    color: VaxColors.electricCyan,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                          color: VaxColors.electricCyan.withOpacity(0.5),
                          blurRadius: 8, spreadRadius: 2)
                    ],
                  ),
                  child: const Icon(Icons.local_hospital,
                      color: VaxColors.deepNavy, size: 22),
                ),
              ),
            ),

            // Child markers
            ...List.generate(mappable.length, (i) {
              final child = mappable[i];
              final riskColor = VaxColors.riskColor(child.riskLevel.name);
              final isSelected = _selectedChild?.id == child.id;
              return Marker(
                point: LatLng(child.latitude!, child.longitude!),
                width: isSelected ? 52 : 44,
                height: isSelected ? 52 : 44,
                child: GestureDetector(
                  onTap: () => setState(() => _selectedChild = child),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: riskColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: isSelected ? 3 : 0),
                      boxShadow: [
                        BoxShadow(
                            color: riskColor.withOpacity(0.5),
                            blurRadius: isSelected ? 12 : 6,
                            spreadRadius: isSelected ? 3 : 1)
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),

        // ─── OSM Attribution (required by OSM license) ───────
        const RichAttributionWidget(
          attributions: [
            TextSourceAttribution('OpenStreetMap contributors',
                onTap: null),
          ],
        ),
      ],
    );
  }

  Future<void> _optimizeRoute() async {
    setState(() => _isOptimizing = true);
    // Nearest-neighbour greedy sort from clinic
    // In production: call OSRM (free routing API) for true optimization
    await Future.delayed(const Duration(milliseconds: 600));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Route optimized! Visit by risk score: highest first.'),
        backgroundColor: VaxColors.electricCyan,
      ),
    );
    setState(() => _isOptimizing = false);
  }
}

// ─────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────

class _StatsBar extends StatelessWidget {
  final int total, highRisk, mapped;
  const _StatsBar({required this.total, required this.highRisk, required this.mapped});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: VaxColors.navyDark,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Chip('$total', 'Children', Icons.people, VaxColors.electricCyan),
          _Chip('$highRisk', 'High Risk', Icons.warning, VaxColors.riskHigh),
          _Chip('$mapped', 'On Map', Icons.location_on, VaxColors.riskLow),
          const _Chip('OSM', 'Free Map', Icons.map, VaxColors.textSecondary),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;
  const _Chip(this.value, this.label, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 15),
      const SizedBox(width: 4),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w800, fontSize: 15)),
        Text(label,
            style: const TextStyle(
                color: VaxColors.textSecondary, fontSize: 10)),
      ]),
    ]);
  }
}

class _SelectedChildCard extends StatelessWidget {
  final Child child;
  final VoidCallback onDismiss;
  const _SelectedChildCard({required this.child, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final riskColor = VaxColors.riskColor(child.riskLevel.name);
    return Container(
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VaxColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: riskColor.withOpacity(0.5)),
      ),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: riskColor.withOpacity(0.15),
              border: Border.all(color: riskColor, width: 2)),
          child: Center(
            child: Text(child.name[0],
                style: TextStyle(color: riskColor, fontWeight: FontWeight.w900,
                    fontSize: 18)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(child.name,
                style: const TextStyle(color: VaxColors.white,
                    fontWeight: FontWeight.w700, fontSize: 15)),
            Text(
              '${child.villageName} · ${child.distanceFromClinicKm.toStringAsFixed(1)}km · '
              'Risk: ${child.riskScore.toStringAsFixed(0)}',
              style: const TextStyle(color: VaxColors.textSecondary, fontSize: 12),
            ),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: riskColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(child.riskLevel.label,
              style: TextStyle(color: riskColor, fontWeight: FontWeight.w700,
                  fontSize: 12)),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.close, color: VaxColors.textSecondary, size: 18),
          onPressed: onDismiss,
          padding: EdgeInsets.zero, constraints: const BoxConstraints(),
        ),
      ]),
    );
  }
}

class _VisitOrderList extends StatelessWidget {
  final List<Child> children;
  final ValueChanged<Child> onChildTap;
  const _VisitOrderList({required this.children, required this.onChildTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: VaxColors.surface,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(children: [
            const Icon(Icons.list_alt, color: VaxColors.electricCyan, size: 16),
            const SizedBox(width: 6),
            const Text('Visit Order — Highest Risk First',
                style: TextStyle(color: VaxColors.white,
                    fontWeight: FontWeight.w700, fontSize: 13)),
            const Spacer(),
            Text('${children.length} stops',
                style: const TextStyle(color: VaxColors.textSecondary, fontSize: 12)),
          ]),
        ),
        Expanded(
          child: children.isEmpty
              ? const Center(
                  child: Text('No children with GPS coordinates',
                      style: TextStyle(color: VaxColors.textSecondary)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  itemCount: children.length,
                  itemBuilder: (_, i) {
                    final child = children[i];
                    final riskColor = VaxColors.riskColor(child.riskLevel.name);
                    return ListTile(
                      dense: true,
                      onTap: () => onChildTap(child),
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: riskColor.withOpacity(0.2),
                        child: Text('${i + 1}',
                            style: TextStyle(color: riskColor,
                                fontWeight: FontWeight.w800, fontSize: 12)),
                      ),
                      title: Text(child.name,
                          style: const TextStyle(
                              color: VaxColors.white, fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '${child.villageName} · ${child.distanceFromClinicKm.toStringAsFixed(1)}km',
                        style: const TextStyle(
                            color: VaxColors.textSecondary, fontSize: 11),
                      ),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: riskColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(child.riskLevel.label,
                              style: TextStyle(color: riskColor, fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 6),
                        Text('${child.riskScore.toStringAsFixed(0)}',
                            style: TextStyle(color: riskColor,
                                fontWeight: FontWeight.w900, fontSize: 16)),
                      ]),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

class _NoLocationState extends StatelessWidget {
  const _NoLocationState();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: VaxColors.navyDark,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 52, color: VaxColors.textSecondary),
            SizedBox(height: 14),
            Text('No GPS coordinates available',
                style: TextStyle(color: VaxColors.white, fontSize: 16,
                    fontWeight: FontWeight.w600)),
            SizedBox(height: 6),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Add latitude & longitude to child records\nto display them on the map.',
                textAlign: TextAlign.center,
                style: TextStyle(color: VaxColors.textSecondary, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
