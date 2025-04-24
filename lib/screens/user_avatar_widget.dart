import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class UserAvatarWidget extends StatelessWidget {
  final AppUser user;

  const UserAvatarWidget({Key? key, required this.user}) : super(key: key);

  // Determine user level based on eco points
  int _calculateUserLevel(int ecoPoints) {
    if (ecoPoints < 100) return 1;
    if (ecoPoints < 250) return 2;
    if (ecoPoints < 500) return 3;
    if (ecoPoints < 1000) return 4;
    return 5;
  }

  // Get avatar image based on level
  String _getAvatarImage(int level) {
    switch (level) {
      case 1:
        return 'assets/avatars/eco_level1.png';
      case 2:
        return 'assets/avatars/eco_level2.png';
      case 3:
        return 'assets/avatars/eco_level3.png';
      case 4:
        return 'assets/avatars/eco_level4.png';
      case 5:
        return 'assets/avatars/eco_level5.png';
      default:
        return 'assets/avatars/eco_level1.png';
    }
  }

  // Get progress to next level
  double _getLevelProgress(int ecoPoints) {
    if (ecoPoints < 100) return ecoPoints / 100;
    if (ecoPoints < 250) return (ecoPoints - 100) / 150;
    if (ecoPoints < 500) return (ecoPoints - 250) / 250;
    if (ecoPoints < 1000) return (ecoPoints - 500) / 500;
    return 1.0;
  }

  // Get points needed for next level
  int _getPointsToNextLevel(int ecoPoints) {
    if (ecoPoints < 100) return 100 - ecoPoints;
    if (ecoPoints < 250) return 250 - ecoPoints;
    if (ecoPoints < 500) return 500 - ecoPoints;
    if (ecoPoints < 1000) return 1000 - ecoPoints;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final int userLevel = _calculateUserLevel(user.ecoPoints);
    final double levelProgress = _getLevelProgress(user.ecoPoints);
    final int pointsToNextLevel = _getPointsToNextLevel(user.ecoPoints);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                // Avatar Image
                Image.asset(
                  _getAvatarImage(userLevel),
                  width: 120,
                  height: 120,
                  fit: BoxFit.contain,
                ),
                // Level Badge
                Positioned(
                  top: 0,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Level $userLevel',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Eco Points Progress
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Eco Points: ${user.ecoPoints}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: levelProgress,
                  backgroundColor: Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                  minHeight: 10,
                ),
                const SizedBox(height: 8),
                Text(
                  '$pointsToNextLevel points to next level',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Reward system for different actions
class EcoPointsRewards {
  static const int reportIssuePoints = 20;
  static const int verifyIssuePoints = 5;
  static const int resolvedIssuePoints = 50;

  // Method to calculate eco points for reporting an issue
  static int calculateReportPoints(String issueType) {
    switch (issueType.toLowerCase()) {
      case 'pothole':
        return reportIssuePoints + 10;
      case 'damaged road':
        return reportIssuePoints + 5;
      case 'missing sign':
        return reportIssuePoints;
      default:
        return reportIssuePoints;
    }
  }
}