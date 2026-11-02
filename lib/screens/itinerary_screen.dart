import 'package:flutter/material.dart';
import 'planner_screen.dart';

class ItineraryScreen extends StatelessWidget {
  const ItineraryScreen({super.key, this.tripId});
  final int? tripId;
  @override
  Widget build(BuildContext context) =>
      PlannerScreen(section: PlannerSection.itinerary, tripId: tripId);
}

