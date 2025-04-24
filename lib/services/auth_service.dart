import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Public getter for Firestore
  FirebaseFirestore get firestore => _firestore;

  // Access methods remain the same...
  Future<AppUser?> signInWithEmail(String email, String password) async {
    try {
      final userCred = await _auth.signInWithEmailAndPassword(email: email, password: password);
      final userDoc = await _firestore.collection('users').doc(userCred.user!.uid).get();
      return AppUser.fromMap(userCred.user!.uid, userDoc.data() ?? {});
    } catch (e) {
      print('Sign-in error: $e');
      return null;
    }
  }

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

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Stream<User?> get userChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;
}