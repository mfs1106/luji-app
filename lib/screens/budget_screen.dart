import 'package:flutter/material.dart';
import 'planner_screen.dart';

class BudgetScreen extends StatelessWidget {
  const BudgetScreen({super.key, this.tripId});
  final int? tripId;
  @override
  Widget build(BuildContext context) =>
      PlannerScreen(section: PlannerSection.budget, tripId: tripId);
}

