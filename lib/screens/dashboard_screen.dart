// lib/screens/dashboard_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/road_issue.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'auth/login_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class DashboardScreen extends StatelessWidget {
  final AppUser user;

  const DashboardScreen({super.key, required this.user});

  Future<List<RoadIssue>> _loadUserReports() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('roadIssues')
        .where('userId', isEqualTo: user.uid)
        .get();

    return snapshot.docs.map((doc) => RoadIssue.fromMap(doc.data(), doc.id)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard - ${user.email}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              AuthService().signOut();
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
          )
        ],
      ),
      body: FutureBuilder<List<RoadIssue>>(
        future: _loadUserReports(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          return ListView(
            padding: const EdgeInsets.all(12),
            children: snapshot.data!.map((issue) {
              return ListTile(
                title: Text(issue.type),
                subtitle: Text('${issue.description}\nStatus: ${issue.status}'),
                isThreeLine: true,
              );
            }).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.map),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HomeScreen())),
      ),
    );
  }
}
