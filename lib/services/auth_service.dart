// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
//
// import '../models/user_model.dart';
//
// class AuthService {
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//
//   // Public getter for Firestore
//   FirebaseFirestore get firestore => _firestore;
//
//   // Access methods remain the same...
//   Future<AppUser?> signInWithEmail(String email, String password) async {
//     try {
//       final userCred = await _auth.signInWithEmailAndPassword(email: email, password: password);
//       final userDoc = await _firestore.collection('users').doc(userCred.user!.uid).get();
//       return AppUser.fromMap(userCred.user!.uid, userDoc.data() ?? {});
//     } catch (e) {
//       print('Sign-in error: $e');
//       return null;
//     }
//   }
//
//   Future<AppUser?> register(String email, String password) async {
//     try {
//       final userCred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
//       final newUser = AppUser(uid: userCred.user!.uid, email: email);
//       await _firestore.collection('users').doc(userCred.user!.uid).set(newUser.toMap());
//       return newUser;
//     } catch (e) {
//       print('Registration error: $e');
//       return null;
//     }
//   }
//
//   Future<void> signOut() async {
//     await _auth.signOut();
//   }
//
//   Stream<User?> get userChanges => _auth.authStateChanges();
//
//   User? get currentUser => _auth.currentUser;
// }
// lib/services/auth_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_model.dart';
import '../models/authority_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Public getter for Firestore
  FirebaseFirestore get firestore => _firestore;

  // Sign in method (supports both regular users and authorities)
  Future<dynamic> signInWithEmail(String email, String password) async {
    try {
      final userCred = await _auth.signInWithEmailAndPassword(email: email, password: password);
      final userDoc = await _firestore.collection('users').doc(userCred.user!.uid).get();

      // Check if the user is an authority
      if (userDoc.data()?['isAuthority'] == true) {
        return Authority.fromMap(userCred.user!.uid, userDoc.data() ?? {});
      } else {
        return AppUser.fromMap(userCred.user!.uid, userDoc.data() ?? {});
      }
    } catch (e) {
      print('Sign-in error: $e');
      return null;
    }
  }

  // Register as regular user (unchanged)
  Future<AppUser?> register(String email, String password) async {
    try {
      final userCred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      final newUser = AppUser(uid: userCred.user!.uid, email: email);
      await _firestore.collection('users').doc(userCred.user!.uid).set(newUser.toMap());
      return newUser;
    } catch (e) {
      print('Registration error: $e');
      return null;
    }
  }

  // Register as authority (new method)
  Future<Authority?> registerAuthority(
      String email, String password, String jurisdiction, String department) async {
    try {
      final userCred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      final newAuthority = Authority(
        uid: userCred.user!.uid,
        email: email,
        jurisdiction: jurisdiction,
        department: department,
      );
      await _firestore.collection('users').doc(userCred.user!.uid).set(newAuthority.toMap());
      return newAuthority;
    } catch (e) {
      print('Authority registration error: $e');
      return null;
    }
  }

  // Check if current user is an authority
  Future<bool> isCurrentUserAuthority() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    return userDoc.data()?['isAuthority'] == true;
  }

  // Update user eco points
  Future<void> updateEcoPoints(String uid, int points) async {
    await _firestore.collection('users').doc(uid).update({
      'ecoPoints': FieldValue.increment(points),
    });
  }

  // Get user by ID
  Future<dynamic> getUserById(String uid) async {
    final docSnap = await _firestore.collection('users').doc(uid).get();

    if (!docSnap.exists) {
      return null;
    }

    final data = docSnap.data()!;

    if (data['isAuthority'] == true) {
      return Authority.fromMap(uid, data);
    } else {
      return AppUser.fromMap(uid, data);
    }
  }

  // The rest remains unchanged
  Future<void> signOut() async {
    await _auth.signOut();
  }

  Stream<User?> get userChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;
}