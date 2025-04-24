import 'package:cloud_firestore/cloud_firestore.dart';

class RoadIssue {
  final String id;
  final String description;
  final String type;
  final double latitude;
  final double longitude;
  final String? imageUrl;
  final DateTime timestamp;
  final int verificationCount;
  final String status;
  final String transportMode;

  RoadIssue({
    required this.id,
    required this.description,
    required this.type,
    required this.latitude,
    required this.longitude,
    this.imageUrl,
    required this.timestamp,
    required this.verificationCount,
    required this.status,
    required this.transportMode,
  });

  factory RoadIssue.fromMap(Map<String, dynamic> map, String docId) {
    return RoadIssue(
      id: docId,
      description: map['description'] ?? '',
      type: map['type'] ?? 'Unknown',
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      imageUrl: map['imageUrl'],
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      verificationCount: map['verificationCount'] ?? 0,
      status: map['status'] ?? 'pending',
      transportMode: map['transportMode'] ?? 'Unknown',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'description': description,
      'type': type,
      'latitude': latitude,
      'longitude': longitude,
      'imageUrl': imageUrl,
      'timestamp': Timestamp.fromDate(timestamp),
      'verificationCount': verificationCount,
      'status': status,
      'transportMode': transportMode,
    };
  }
}