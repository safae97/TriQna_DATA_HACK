// lib/services/gamification_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class GamificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Points for different transport modes
  final Map<String, int> _transportModePoints = {
    'Walking': 20,
    'Cycling': 15,
    'Public Transport': 10,
    'Electric Vehicle': 5,
    'Car': 2,
    'Other': 2,
  };

  // Points for different actions
  final Map<String, int> _actionPoints = {
    'report_issue': 10,
    'verify_issue': 5,
    'issue_resolved': 15,
    'daily_login': 2,
    'streak_week': 10,
  };

  // XP needed for each level
  final List<int> _levelThresholds = [
    0, 100, 250, 500, 1000, 2000, 3500, 5000, 7500, 10000, 15000, 20000, 30000, 50000, 75000, 100000
  ];

  // Badge criteria
  final Map<String, Map<String, dynamic>> _badgeCriteria = {
    'Newbie': {'description': 'Welcome to triQna!', 'automatic': true},
    'Scout': {'description': 'Report 5 issues', 'totalReports': 5},
    'Explorer': {'description': 'Report 20 issues', 'totalReports': 20},
    'Road Warrior': {'description': 'Report 50 issues', 'totalReports': 50},
    'Eco Hero': {'description': 'Earn 500 eco-points', 'ecoPoints': 500},
    'Green Champion': {'description': 'Earn 2000 eco-points', 'ecoPoints': 2000},
    'Verified Reporter': {'description': 'Get 10 reports verified', 'verifiedReports': 10},
    'Walking Pro': {'description': 'Report 10 issues while walking', 'transportMode': 'Walking', 'count': 10},
    'Cycling Enthusiast': {'description': 'Report 10 issues while cycling', 'transportMode': 'Cycling', 'count': 10},
    'Public Transport Supporter': {'description': 'Report 10 issues while using public transport', 'transportMode': 'Public Transport', 'count': 10},
  };

  // Award points for reporting an issue
  Future<void> awardPointsForReport(String userId, String transportMode) async {
    try {
      // Get basic report points
      int points = _actionPoints['report_issue']!;

      // Add transport mode points
      points += _transportModePoints[transportMode] ?? _transportModePoints['Other']!;

      // Update user document
      await _firestore.collection('users').doc(userId).update({
        'ecoPoints': FieldValue.increment(points),
        'totalReports': FieldValue.increment(1),
        'transportModeReports.${transportMode.toLowerCase().replaceAll(' ', '_')}': FieldValue.increment(1),
      });

      // Check for level up and badges
      await _checkLevelUpAndBadges(userId);

      // Add activity to user's activity feed
      await _addActivity(userId, 'Reported an issue while $transportMode', points);
    } catch (e) {
      print('Error awarding points: $e');
    }
  }

  // Award points for verifying an issue
  Future<void> awardPointsForVerification(String userId) async {
    try {
      int points = _actionPoints['verify_issue']!;

      await _firestore.collection('users').doc(userId).update({
        'ecoPoints': FieldValue.increment(points),
        'verifiedReports': FieldValue.increment(1),
      });

      await _checkLevelUpAndBadges(userId);
      await _addActivity(userId, 'Verified an issue', points);
    } catch (e) {
      print('Error awarding verification points: $e');
    }
  }

  // Check for level up and award badges
  Future<void> _checkLevelUpAndBadges(String userId) async {
    try {
      // Get current user data
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return;

      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      int currentEcoPoints = userData['ecoPoints'] ?? 0;
      int currentLevel = userData['level'] ?? 1;
      List<String> currentBadges = List<String>.from(userData['badges'] ?? []);

      // Check for level up
      int newLevel = _calculateLevel(currentEcoPoints);
      if (newLevel > currentLevel) {
        await _firestore.collection('users').doc(userId).update({
          'level': newLevel,
        });

        await _addActivity(userId, 'Leveled up to level $newLevel!', 0);
      }

      // Check for new badges
      List<String> newBadges = await _checkForNewBadges(userId, userData, currentBadges);
      if (newBadges.isNotEmpty) {
        await _firestore.collection('users').doc(userId).update({
          'badges': FieldValue.arrayUnion(newBadges),
        });

        for (String badge in newBadges) {
          await _addActivity(userId, 'Earned the "$badge" badge!', 0);
        }
      }
    } catch (e) {
      print('Error checking level and badges: $e');
    }
  }

  // Calculate level based on eco-points
  int _calculateLevel(int ecoPoints) {
    for (int i = _levelThresholds.length - 1; i >= 0; i--) {
      if (ecoPoints >= _levelThresholds[i]) {
        return i + 1;
      }
    }
    return 1;
  }

  // Check for new badges
  Future<List<String>> _checkForNewBadges(
      String userId,
      Map<String, dynamic> userData,
      List<String> currentBadges
      ) async {
    List<String> newBadges = [];

    // Get transport mode reports
    Map<String, dynamic> transportModeReports = userData['transportModeReports'] ?? {};

    for (String badge in _badgeCriteria.keys) {
      if (!currentBadges.contains(badge)) {
        Map<String, dynamic> criteria = _badgeCriteria[badge]!;

        bool awarded = false;

        // Check for total reports
        if (criteria.containsKey('totalReports')) {
          int totalReports = userData['totalReports'] ?? 0;
          if (totalReports >= criteria['totalReports']) {
            awarded = true;
          }
        }

        // Check for eco points
        if (criteria.containsKey('ecoPoints')) {
          int ecoPoints = userData['ecoPoints'] ?? 0;
          if (ecoPoints >= criteria['ecoPoints']) {
            awarded = true;
          }
        }

        // Check for verified reports
        if (criteria.containsKey('verifiedReports')) {
          int verifiedReports = userData['verifiedReports'] ?? 0;
          if (verifiedReports >= criteria['verifiedReports']) {
            awarded = true;
          }
        }

        // Check for transport mode count
        if (criteria.containsKey('transportMode')) {
          String transportMode = criteria['transportMode'];
          String transportModeKey = transportMode.toLowerCase().replaceAll(' ', '_');
          int count = transportModeReports[transportModeKey] ?? 0;

          if (count >= criteria['count']) {
            awarded = true;
          }
        }

        if (awarded) {
          newBadges.add(badge);
        }
      }
    }

    return newBadges;
  }

  // Add activity to user's activity feed
  Future<void> _addActivity(String userId, String description, int points) async {
    await _firestore.collection('users').doc(userId).collection('activities').add({
      'description': description,
      'points': points,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Get user's activities
  Future<List<Map<String, dynamic>>> getUserActivities(String userId, {int limit = 20}) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('activities')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'description': data['description'],
          'points': data['points'],
          'timestamp': (data['timestamp'] as Timestamp).toDate(),
        };
      }).toList();
    } catch (e) {
      print('Error getting user activities: $e');
      return [];
    }
  }

  // Get all badge criteria
  Map<String, Map<String, dynamic>> getAllBadgeCriteria() {
    return _badgeCriteria;
  }

  // Get points for each level
  List<int> getLevelThresholds() {
    return _levelThresholds;
  }
}