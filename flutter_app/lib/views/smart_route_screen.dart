// VaxTrace AI — Smart Route Screen (shim → MapView)
// Delegates to MapView which now uses flutter_map + OpenStreetMap (free, no API key).

import 'package:flutter/material.dart';
import '../models/child.dart';
import 'map_view.dart';

/// SmartRouteScreen is kept for backward compatibility with existing navigation
/// calls (child_detail_screen.dart, dashboard_screen.dart).
/// It simply wraps the new MapView widget.
class SmartRouteScreen extends StatelessWidget {
  final List<Child> children;
  const SmartRouteScreen({super.key, required this.children});

  @override
  Widget build(BuildContext context) => MapView(children: children);
}
