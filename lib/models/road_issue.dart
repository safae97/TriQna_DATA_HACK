// import 'package:cloud_firestore/cloud_firestore.dart';
//
// class RoadIssue {
//   final String id;
//   final String description;
//   final String type;
//   final double latitude;
//   final double longitude;
//   final String? imageUrl;
//   final DateTime timestamp;
//   final int verificationCount;
//   final String status;
//   final String transportMode;
//   final String userId; // Added userId field to track who created the report
//
//   RoadIssue({
//     required this.id,
//     required this.description,
//     required this.type,
//     required this.latitude,
//     required this.longitude,
//     this.imageUrl,
//     required this.timestamp,
//     required this.verificationCount,
//     required this.status,
//     required this.transportMode,
//     required this.userId, // Make userId required
//   });
//
//   factory RoadIssue.fromMap(Map<String, dynamic> map, String docId) {
//     try {
//       // Handle Timestamp conversion safely
//       DateTime timestamp;
//       if (map['timestamp'] is Timestamp) {
//         timestamp = (map['timestamp'] as Timestamp).toDate();
//       } else {
//         timestamp = DateTime.now(); // Default fallback
//         print('Warning: Invalid timestamp format in document $docId');
//       }
//
//       // Extract latitude/longitude values safely
//       double latitude = 0.0;
//       double longitude = 0.0;
//
//       if (map['latitude'] != null) {
//         latitude = (map['latitude'] is num)
//             ? (map['latitude'] as num).toDouble()
//             : 0.0;
//       }
//
//       if (map['longitude'] != null) {
//         longitude = (map['longitude'] is num)
//             ? (map['longitude'] as num).toDouble()
//             : 0.0;
//       }
//
//       return RoadIssue(
//         id: docId,
//         description: map['description'] ?? 'No description',
//         type: map['type'] ?? 'Unknown',
//         latitude: latitude,
//         longitude: longitude,
//         imageUrl: map['imageUrl'],
//         timestamp: timestamp,
//         verificationCount: map['verificationCount'] ?? 0,
//         status: map['status'] ?? 'pending',
//         transportMode: map['transportMode'] ?? 'Unknown',
//         userId: map['userId'] ?? '',
//       );
//     } catch (e) {
//       print('Error parsing RoadIssue from document $docId: $e');
//       // Return a placeholder object to avoid crashes
//       return RoadIssue(
//         id: docId,
//         description: 'Error loading report',
//         type: 'Unknown',
//         latitude: 0.0,
//         longitude: 0.0,
//         timestamp: DateTime.now(),
//         verificationCount: 0,
//         status: 'error',
//         transportMode: 'Unknown',
//         userId: '',
//       );
//     }
//   }
//   Map<String, dynamic> toMap() {
//     return {
//       'description': description,
//       'type': type,
//       'latitude': latitude,
//       'longitude': longitude,
//       'imageUrl': imageUrl,
//       'timestamp': Timestamp.fromDate(timestamp),
//       'verificationCount': verificationCount,
//       'status': status,
//       'transportMode': transportMode,
//       'userId': userId, // Include userId in the map
//     };
//   }
// }
// in road_issue.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

class RoadIssue {
  final String id;
  final String userId;
  final String type;
  final String description;
  final double latitude;
  final double longitude;
  final String transportMode;
  final int verificationCount;
  final DateTime timestamp;
  final String? imageUrl;

  RoadIssue({
    required this.id,
    required this.userId,
    required this.type,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.transportMode,
    required this.verificationCount,
    required this.timestamp,
    this.imageUrl,
  });

  LatLng get location => LatLng(latitude, longitude);

  factory RoadIssue.fromMap(Map<String, dynamic> map, String id) {
    return RoadIssue(
      id: id,
      userId: map['userId'] ?? '',
      type: map['type'] ?? '',
      description: map['description'] ?? '',
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      transportMode: map['transportMode'] ?? 'Unknown',
      verificationCount: map['verificationCount'] ?? 0,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      imageUrl: map['imageUrl'],
    );
  }
}