import 'package:flutter/material.dart';
import 'planner_screen.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key, this.tripId});
  final int? tripId;
  @override
  Widget build(BuildContext context) =>
      PlannerScreen(section: PlannerSection.map, tripId: tripId);
}

