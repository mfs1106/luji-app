import 'package:flutter/material.dart';
import 'planner_screen.dart';

class NotebookScreen extends StatelessWidget {
  const NotebookScreen({super.key, this.tripId});
  final int? tripId;
  @override
  Widget build(BuildContext context) =>
      PlannerScreen(section: PlannerSection.notes, tripId: tripId);
}

