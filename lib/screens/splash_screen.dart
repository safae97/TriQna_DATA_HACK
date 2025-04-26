// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/signup_screen.dart';
import '../models/authority_model.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'welcome_screen.dart';
import 'authority_dashboard.dart';

// Define the color palette to match the authority dashboard
class AppColors {
  static const primaryColor = Color(0xFF20522F); // Dark green
  static const secondaryColor = Color(0xFF4D9C2D); // Light green
  static const white = Colors.white;
  static const lightGreen = Color(0xFFE8F5E9); // Light background
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    // Set up animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    // Start animation
    _animationController.forward();

    // Wait for animation to complete before checking auth status
    Timer(const Duration(seconds: 3), () {
      _checkAuthStatus();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // A method that waits for Firebase auth state and checks Firestore
  Future<void> _checkAuthStatus() async {
    // Wait until Firebase is initialized
    await Firebase.initializeApp();

    final authService = Provider.of<AuthService>(context, listen: false);

    // Now we can safely check the auth status after Firebase is initialized
    final user = authService.currentUser;

    if (user != null) {
      // Check if the user exists in Firestore
      final userDoc = await authService.firestore.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        // Check if the user is an authority
        final isAuthority = userDoc.data()?['isAuthority'] == true;

        if (isAuthority) {
          // Create an Authority object from the document data
          final authority = Authority.fromMap(user.uid, userDoc.data() ?? {});

          // Navigate to authority dashboard
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => AuthorityDashboard(authority: authority)),
          );
        } else {
          // User is a regular user, navigate to the home screen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      } else {
        // User doesn't exist in Firestore, navigate to registration screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const RegistrationScreen()),
        );
      }
    } else {
      // No user is authenticated, navigate to welcome/landing screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // White background instead of dark green
      backgroundColor: AppColors.white,
      body: Center(
        child: FadeTransition(
          opacity: _animation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Logo with enhanced design
              Container(

                padding: const EdgeInsets.all(20),
                child: Image.asset(
                  'assets/avatars/logo.png',
                  width: 400,
                  height: 400,
                ),
              ),
              const SizedBox(height: 30),
              // App Name with scale animation and branded color
              ScaleTransition(
                scale: _animation,
                child: const Text(
                  'triQna',
                  style: TextStyle(
                    color: AppColors.primaryColor, // Dark green text to match logo
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // App tagline
              Text(
                'Road Issue Reporter',
                style: TextStyle(
                  color: AppColors.primaryColor.withOpacity(0.8), // Slightly transparent dark green
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 50),
              // Loading indicator with branded color
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondaryColor), // green progress
                strokeWidth: 3.0,
              ),
            ],
          ),
        ),
      ),
    );
  }
}