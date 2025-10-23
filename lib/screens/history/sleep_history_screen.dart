import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class SleepHistoryScreen extends StatefulWidget {
  const SleepHistoryScreen({super.key});

  @override
  State<SleepHistoryScreen> createState() => _SleepHistoryScreenState();
}

class _SleepHistoryScreenState extends State<SleepHistoryScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _user = FirebaseAuth.instance.currentUser;

  Future<void> _deleteSession(String id) async {
    await _firestore
        .collection('users')
        .doc(_user!.uid)
        .collection('sleep_sessions')
        .doc(id)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sleep History")),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('users')
            .doc(_user!.uid)
            .collection('sleep_sessions')
            .orderBy('start', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text("No sleep sessions yet."));
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i];
              final data = d.data()! as Map<String, dynamic>;
              final start = (data['start'] as Timestamp).toDate();
              final end = (data['end'] as Timestamp?)?.toDate();
              final duration = end == null ? 0 : end.difference(start).inMinutes / 60;
              return Dismissible(
                key: Key(d.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.redAccent,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) => _deleteSession(d.id),
                child: ListTile(
                  title: Text("${DateFormat('E, MMM d').format(start)} — ${duration.toStringAsFixed(1)}h"),
                  subtitle: Text("${DateFormat('h:mm a').format(start)} → ${end != null ? DateFormat('h:mm a').format(end) : 'ongoing'}"),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
