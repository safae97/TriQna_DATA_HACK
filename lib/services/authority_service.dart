// lib/services/authority_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import '../models/road_issue.dart';

class AuthorityService {
  final FirebaseFirestore _firestore;
  final String authorityId;

  AuthorityService({required this.authorityId, FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Get all reported issues
  Stream<List<RoadIssue>> getAllIssues() {
    return _firestore
        .collection('roadIssues')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => RoadIssue.fromMap(doc.data(), doc.id))
        .toList());
  }

  // Filter issues by type
  Stream<List<RoadIssue>> getIssuesByType(String type) {
    return _firestore
        .collection('roadIssues')
        .where('type', isEqualTo: type)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => RoadIssue.fromMap(doc.data(), doc.id))
        .toList());
  }

  // Filter issues by verification count (issues with at least X verifications)
  Stream<List<RoadIssue>> getIssuesByMinVerification(int minVerification) {
    return _firestore
        .collection('roadIssues')
        .where('verificationCount', isGreaterThanOrEqualTo: minVerification)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => RoadIssue.fromMap(doc.data(), doc.id))
        .toList());
  }

  // Filter issues by transport mode
  Stream<List<RoadIssue>> getIssuesByTransportMode(String transportMode) {
    return _firestore
        .collection('roadIssues')
        .where('transportMode', isEqualTo: transportMode)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => RoadIssue.fromMap(doc.data(), doc.id))
        .toList());
  }

  // Get issues within a radius of a location
  Future<List<RoadIssue>> getIssuesNearLocation(
      double latitude, double longitude, double radiusInKm) async {
    // Since Firestore doesn't support geo queries directly,
    // we'll fetch all and filter manually
    final snapshot = await _firestore.collection('roadIssues').get();

    final issues = snapshot.docs.map((doc) => RoadIssue.fromMap(doc.data(), doc.id)).toList();

    // Calculate distance for each issue and filter
    const Distance distance = Distance();
    final center = LatLng(latitude, longitude);

    return issues.where((issue) {
      final issuePoint = LatLng(issue.latitude, issue.longitude);
      final distanceInKm = distance.as(LengthUnit.Kilometer, center, issuePoint);
      return distanceInKm <= radiusInKm;
    }).toList();
  }

  // Update issue status (e.g., pending, in progress, resolved)
  Future<void> updateIssueStatus(String issueId, String newStatus) async {
    await _firestore.collection('roadIssues').doc(issueId).update({
      'status': newStatus,
    });

    // If marking as resolved, reward the reporter with eco points
    if (newStatus == 'resolved') {
      final issueDoc = await _firestore.collection('roadIssues').doc(issueId).get();
      final userId = issueDoc.data()?['userId'];

      if (userId != null) {
        // Add 10 eco points for having your issue resolved
        await _firestore.collection('users').doc(userId).update({
          'ecoPoints': FieldValue.increment(10),
        });
      }
    }
  }

  // Get aggregated data for reports and analytics
  Future<Map<String, int>> getMostReportedTypes() async {
    final snapshot = await _firestore.collection('roadIssues').get();
    final issues = snapshot.docs.map((doc) => RoadIssue.fromMap(doc.data(), doc.id)).toList();

    // Count issues by type
    final Map<String, int> typeCounts = {};
    for (var issue in issues) {
      typeCounts[issue.type] = (typeCounts[issue.type] ?? 0) + 1;
    }

    return typeCounts;
  }

  // Get transport mode distribution
  Future<Map<String, int>> getTransportModeDistribution() async {
    final snapshot = await _firestore.collection('roadIssues').get();
    final issues = snapshot.docs.map((doc) => RoadIssue.fromMap(doc.data(), doc.id)).toList();

    // Count issues by transport mode
    final Map<String, int> modeCounts = {};
    for (var issue in issues) {
      modeCounts[issue.transportMode] = (modeCounts[issue.transportMode] ?? 0) + 1;
    }

    return modeCounts;
  }

  // Get hotspot areas (areas with highest concentration of issues)
  Future<List<Map<String, dynamic>>> getHotspotAreas(int gridSize) async {
    final snapshot = await _firestore.collection('roadIssues').get();
    final issues = snapshot.docs.map((doc) => RoadIssue.fromMap(doc.data(), doc.id)).toList();

    // Group issues by geographic grid cells
    final Map<String, List<RoadIssue>> gridCells = {};

    for (var issue in issues) {
      // Create grid cell key (simplified for example)
      final cellKey = '${(issue.latitude * gridSize).floor()}_${(issue.longitude * gridSize).floor()}';

      if (!gridCells.containsKey(cellKey)) {
        gridCells[cellKey] = [];
      }
      gridCells[cellKey]!.add(issue);
    }

    // Convert to list of areas with count
    final hotspots = gridCells.entries.map((entry) {
      // Calculate average position of all issues in this cell
      double avgLat = 0, avgLng = 0;
      for (var issue in entry.value) {
        avgLat += issue.latitude;
        avgLng += issue.longitude;
      }
      avgLat /= entry.value.length;
      avgLng /= entry.value.length;

      return {
        'latitude': avgLat,
        'longitude': avgLng,
        'count': entry.value.length,
      };
    }).toList();

    // Sort by count (highest first)
    hotspots.sort((a, b) => (b['count'] ?? 0).compareTo(a['count'] ?? 0));
    return hotspots;
  }

  // Get issue statistics by time period
  Future<Map<String, int>> getIssuesByTimePeriod() async {
    final snapshot = await _firestore.collection('roadIssues').get();
    final issues = snapshot.docs.map((doc) => RoadIssue.fromMap(doc.data(), doc.id)).toList();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final lastWeek = today.subtract(const Duration(days: 7));
    final lastMonth = today.subtract(const Duration(days: 30));

    // Count issues by time period
    int todayCount = 0;
    int yesterdayCount = 0;
    int lastWeekCount = 0;
    int lastMonthCount = 0;
    int olderCount = 0;

    for (var issue in issues) {
      final issueDate = DateTime(
        issue.timestamp.year,
        issue.timestamp.month,
        issue.timestamp.day,
      );

      if (issueDate.isAtSameMomentAs(today)) {
        todayCount++;
      } else if (issueDate.isAtSameMomentAs(yesterday)) {
        yesterdayCount++;
      } else if (issueDate.isAfter(lastWeek)) {
        lastWeekCount++;
      } else if (issueDate.isAfter(lastMonth)) {
        lastMonthCount++;
      } else {
        olderCount++;
      }
    }

    return {
      'today': todayCount,
      'yesterday': yesterdayCount,
      'lastWeek': lastWeekCount, // Not including today and yesterday
      'lastMonth': lastMonthCount, // Not including last week
      'older': olderCount,
    };
  }
}