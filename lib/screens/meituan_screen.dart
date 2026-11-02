import 'package:flutter/material.dart';
import 'planner_screen.dart';

class MeituanScreen extends StatelessWidget {
  const MeituanScreen({super.key, this.tripId});
  final int? tripId;
  @override
  Widget build(BuildContext context) =>
      PlannerScreen(section: PlannerSection.meituan, tripId: tripId);
}

