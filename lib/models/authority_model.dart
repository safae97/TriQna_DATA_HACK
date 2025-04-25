// lib/models/authority_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_model.dart';

class Authority extends AppUser {
  final String jurisdiction; // e.g., "City", "County", "State"
  final String department;   // e.g., "Roads", "Transportation"
  final List<String> managedAreas; // List of location identifiers

  Authority({
    required String uid,
    required String email,
    int ecoPoints = 0,
    required this.jurisdiction,
    required this.department,
    this.managedAreas = const [],
  }) : super(uid: uid, email: email, ecoPoints: ecoPoints);

  factory Authority.fromMap(String uid, Map<String, dynamic> data) {
    return Authority(
      uid: uid,
      email: data['email'] ?? '',
      ecoPoints: data['ecoPoints'] ?? 0,
      jurisdiction: data['jurisdiction'] ?? '',
      department: data['department'] ?? '',
      managedAreas: List<String>.from(data['managedAreas'] ?? []),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    final baseMap = super.toMap();
    return {
      ...baseMap,
      'jurisdiction': jurisdiction,
      'department': department,
      'managedAreas': managedAreas,
      'isAuthority': true, // Flag to identify authority accounts
    };
  }
}