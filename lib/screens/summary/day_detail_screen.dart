import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DayDetailScreen extends StatelessWidget {
  final DateTime day;
  final double hours;

  const DayDetailScreen({
    super.key,
    required this.day,
    required this.hours,
  });

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('EEEE, MMM d').format(day);

    return Scaffold(
      appBar: AppBar(
        title: Text(label),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "$hours h slept",
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Sleep sessions from this day will appear here.\n"
              "(You can later fetch from Firestore using the same date key.)",
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
