import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'authority_dashboard.dart';

class RegisterAuthorityScreen extends StatefulWidget {
  const RegisterAuthorityScreen({Key? key}) : super(key: key);

  @override
  _RegisterAuthorityScreenState createState() => _RegisterAuthorityScreenState();
}

class _RegisterAuthorityScreenState extends State<RegisterAuthorityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _jurisdictionController = TextEditingController();
  final _departmentController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _jurisdictionController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final authority = await authService.registerAuthority(
        _emailController.text.trim(),
        _passwordController.text,
        _jurisdictionController.text.trim(),
        _departmentController.text.trim(),
      );

      if (authority == null) {
        setState(() {
          _errorMessage = 'Registration failed. Please try again.';
          _isLoading = false;
        });
        return;
      }

      // Navigate to Authority Dashboard
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => AuthorityDashboard(authority: authority),
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register as Authority'),
        backgroundColor: Color(0xFF20522F), // Dark green color
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Authority Icon
                Icon(
                  Icons.admin_panel_settings,
                  size: 80,
                  color: Color(0xFF4D9C2D), // Light green color
                ),
                const SizedBox(height: 32),

                // Email Field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Official Email',
                    labelStyle: TextStyle(color: Color(0xFF20522F)), // Dark green label color
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email, color: Color(0xFF4D9C2D)), // Light green icon
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password Field
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: TextStyle(color: Color(0xFF20522F)), // Dark green label color
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock, color: Color(0xFF4D9C2D)), // Light green icon
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Confirm Password Field
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    labelStyle: TextStyle(color: Color(0xFF20522F)), // Dark green label color
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline, color: Color(0xFF4D9C2D)), // Light green icon
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Jurisdiction Field
                TextFormField(
                  controller: _jurisdictionController,
                  decoration: InputDecoration(
                    labelText: 'Jurisdiction (e.g., City, County)',
                    labelStyle: TextStyle(color: Color(0xFF20522F)), // Dark green label color
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_city, color: Color(0xFF4D9C2D)), // Light green icon
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your jurisdiction';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Department Field
                TextFormField(
                  controller: _departmentController,
                  decoration: InputDecoration(
                    labelText: 'Department (e.g., Roads, Transportation)',
                    labelStyle: TextStyle(color: Color(0xFF20522F)), // Dark green label color
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.business, color: Color(0xFF4D9C2D)), // Light green icon
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your department';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Error Message
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Register Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF20522F), // Dark green button color
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Register Authority Account', style: TextStyle(color: Colors.white)), // White text color
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
      backgroundColor: Colors.white, // White background color
    );
  }
}
