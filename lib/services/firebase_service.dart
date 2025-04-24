import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/road_issue.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<List<RoadIssue>> getAllRoadIssues() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('roadIssues').get();
      return snapshot.docs.map((doc) {
        return RoadIssue.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      print('Error getting road issues: $e');
      return [];
    }
  }

  Future<List<RoadIssue>> getNearbyRoadIssues(double lat, double lng, double radiusKm) async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('roadIssues').get();
      List<RoadIssue> issues = snapshot.docs.map((doc) {
        return RoadIssue.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
      return issues.where((issue) {
        double latDiff = (issue.latitude - lat).abs();
        double lngDiff = (issue.longitude - lng).abs();
        double approxDistance = (latDiff + lngDiff) * 111;
        return approxDistance <= radiusKm;
      }).toList();
    } catch (e) {
      print('Error getting nearby road issues: $e');
      return [];
    }
  }

  Future<String?> addRoadIssue({
    required String description,
    required String type,
    required String transportMode,
    required double latitude,
    required double longitude,
    File? imageFile,
  }) async {
    try {
      String? imageUrl;
      if (imageFile != null) {
        imageUrl = await uploadImage(imageFile);
      }
      DocumentReference docRef = await _firestore.collection('roadIssues').add({
        'description': description,
        'type': type,
        'transportMode': transportMode,
        'latitude': latitude,
        'longitude': longitude,
        'imageUrl': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'verificationCount': 0,
        'status': 'pending',
      });
      return docRef.id;
    } catch (e) {
      print('Error adding road issue: $e');
      return null;
    }
  }

  Future<String?> uploadImage(File imageFile) async {
    try {
      String fileName = 'issue_${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference storageRef = _storage.ref().child('issue_images').child(fileName);
      UploadTask uploadTask = storageRef.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  Future<bool> verifyRoadIssue(String issueId) async {
    try {
      await _firestore.collection('roadIssues').doc(issueId).update({
        'verificationCount': FieldValue.increment(1),
      });
      return true;
    } catch (e) {
      print('Error verifying road issue: $e');
      return false;
    }
  }

  Future<bool> addEcoPoints(String userId, int points) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'ecoPoints': FieldValue.increment(points),
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      print('Error adding eco-points: $e');
      return false;
    }
  }
}