import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import '../services/auth_service.dart';
import '../services/signup_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';



class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late AuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _checkAuthStatus();
  }

  // A method that waits for Firebase auth state and checks Firestore
  Future<void> _checkAuthStatus() async {
    // Wait until Firebase is initialized
    await Firebase.initializeApp();

    // Now we can safely check the auth status after Firebase is initialized
    final user = _authService.currentUser;

    if (user != null) {
      // Check if the user exists in Firestore
      final userDoc = await _authService.firestore.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        // User exists in Firestore, navigate to the home screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        // User doesn't exist in Firestore, navigate to registration screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const RegistrationScreen()),
        );
      }
    } else {
      // No user is authenticated, navigate to login screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(), // Show loading indicator while checking auth state
      ),
    );
  }
}
