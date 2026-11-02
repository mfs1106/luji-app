import 'package:flutter/material.dart';
import 'planner_screen.dart';

class RouteScreen extends StatelessWidget {
  const RouteScreen({super.key, this.tripId});
  final int? tripId;
  @override
  Widget build(BuildContext context) =>
      PlannerScreen(section: PlannerSection.route, tripId: tripId);
}

