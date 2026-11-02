import 'package:flutter/material.dart';
import 'planner_screen.dart';

class ReminderScreen extends StatelessWidget {
  const ReminderScreen({super.key, this.tripId});
  final int? tripId;
  @override
  Widget build(BuildContext context) =>
      PlannerScreen(section: PlannerSection.reminder, tripId: tripId);
}

