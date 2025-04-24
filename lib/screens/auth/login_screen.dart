// // lib/screens/auth/login_screen.dart
// import 'package:flutter/material.dart';
// import '../../services/auth_service.dart';
//
// class LoginScreen extends StatefulWidget {
//   const LoginScreen({Key? key}) : super(key: key);
//
//   @override
//   State<LoginScreen> createState() => _LoginScreenState();
// }
//
// class _LoginScreenState extends State<LoginScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final AuthService _authService = AuthService();
//
//   String _email = '';
//   String _password = '';
//   bool _isLoading = false;
//   String _errorMessage = '';
//   bool _obscurePassword = true;
//
//   Future<void> _signInWithEmail() async {
//     if (_formKey.currentState!.validate()) {
//       _formKey.currentState!.save();
//
//       setState(() {
//         _isLoading = true;
//         _errorMessage = '';
//       });
//
//       try {
//         await _authService.signInWithEmail(_email, _password);
//
//         // Login successful, navigation is handled by the wrapper
//       } catch (e) {
//         setState(() {
//           _errorMessage = _getFirebaseAuthErrorMessage(e.toString());
//         });
//       } finally {
//         setState(() {
//           _isLoading = false;
//         });
//       }
//     }
//   }
//
//   Future<void> _signInWithGoogle() async {
//     setState(() {
//       _isLoading = true;
//       _errorMessage = '';
//     });
//
//     try {
//       await _authService.signInWithGoogle();
//
//       // Login successful, navigation is handled by the wrapper
//     } catch (e) {
//       setState(() {
//         _errorMessage = _getFirebaseAuthErrorMessage(e.toString());
//       });
//     } finally {
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }
//
//   String _getFirebaseAuthErrorMessage(String errorString) {
//     if (errorString.contains('user-not-found')) {
//       return 'No user found with this email. Please register first.';
//     } else if (errorString.contains('wrong-password')) {
//       return 'Incorrect password. Please try again.';
//     } else if (errorString.contains('invalid-email')) {
//       return 'Invalid email address.';
//     } else if (errorString.contains('user-disabled')) {
//       return 'This account has been disabled.';
//     } else if (errorString.contains('too-many-requests')) {
//       return 'Too many login attempts. Please try again later.';
//     } else if (errorString.contains('network-request-failed')) {
//       return 'Network error. Please check your connection.';
//     }
//     return 'An error occurred. Please try again.';
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: SafeArea(
//         child: Center(
//           child: SingleChildScrollView(
//             padding: const EdgeInsets.all(24.0),
//             child: Form(
//               key: _formKey,
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 crossAxisAlignment: CrossAxisAlignment.stretch,
//                 children: [
//                   // App logo
//                   Container(
//                     width: 100,
//                     height: 100,
//                     decoration: BoxDecoration(
//                       color: const Color(0xFF3498DB),
//                       borderRadius: BorderRadius.circular(20),
//                     ),
//                     child: const Center(
//                       child: Text(
//                         'triQna',
//                         style: TextStyle(
//                           color: Colors.white,
//                           fontSize: 24,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 32),
//
//                   const Text(
//                     'Welcome Back',
//                     style: TextStyle(
//                       fontSize: 24,
//                       fontWeight: FontWeight.bold,
//                     ),
//                     textAlign: TextAlign.center,
//                   ),
//                   const SizedBox(height: 8),
//
//                   const Text(
//                     'Sign in to continue reporting road issues',
//                     style: TextStyle(
//                       color: Colors.grey,
//                     ),
//                     textAlign: TextAlign.center,
//                   ),
//                   const SizedBox(height: 32),
//
//                   // Email field
//                   TextFormField(
//                     decoration: InputDecoration(
//                       labelText: 'Email',
//                       prefixIcon: const Icon(Icons.email),
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       filled: true,
//                       fillColor: Colors.grey[100],
//                     ),
//                     keyboardType: TextInputType.emailAddress,
//                     validator: (value) {
//                       if (value == null || value.isEmpty) {
//                         return 'Please enter your email';
//                       }
//                       if (!value.contains('@') || !value.contains('.')) {
//                         return 'Please enter a valid email';
//                       }
//                       return null;
//                     },
//                     onSaved: (value) {
//                       _email = value!.trim();
//                     },
//                   ),
//                   const SizedBox(height: 16),
//
//                   // Password field
//                   TextFormField(
//                     decoration: InputDecoration(
//                       labelText: 'Password',
//                       prefixIcon: const Icon(Icons.lock),
//                       suffixIcon: IconButton(
//                         icon: Icon(
//                           _obscurePassword ? Icons.visibility : Icons.visibility_off,
//                         ),
//                         onPressed: () {
//                           setState(() {
//                             _obscurePassword = !_obscurePassword;
//                           });
//                         },
//                       ),
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       filled: true,
//                       fillColor: Colors.grey[100],
//                     ),
//                     obscureText: _obscurePassword,
//                     validator: (value) {
//                       if (value == null || value.isEmpty) {
//                         return 'Please enter your password';
//                       }
//                       return null;
//                     },
//                     onSaved: (value) {
//                       _password = value!;
//                     },
//                   ),
//                   const SizedBox(height: 8),
//
//                   // Forgot password
//                   Align(
//                     alignment: Alignment.centerRight,
//                     child: TextButton(
//                       onPressed: () {
//                         Navigator.pushNamed(context, '/forgot-password');
//                       },
//                       child: const Text('Forgot Password?'),
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//
//                   // Error message
//                   if (_errorMessage.isNotEmpty)
//                     Container(
//                       padding: const EdgeInsets.all(12),
//                       decoration: BoxDecoration(
//                         color: Colors.red[100],
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                       child: Text(
//                         _errorMessage,
//                         style: TextStyle(color: Colors.red[800]),
//                       ),
//                     ),
//                   if (_errorMessage.isNotEmpty) const SizedBox(height: 16),
//
//                   // Login button
//                   SizedBox(
//                     height: 50,
//                     child: ElevatedButton(
//                       onPressed: _isLoading ? null : _signInWithEmail,
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: const Color(0xFF3498DB),
//                         foregroundColor: Colors.white,
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                       ),
//                       child: _isLoading
//                           ? const CircularProgressIndicator(color: Colors.white)
//                           : const Text(
//                         'LOG IN',
//                         style: TextStyle(
//                           fontWeight: FontWeight.bold,
//                           fontSize: 16,
//                         ),
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//
//                   // Or divider
//                   Row(
//                     children: [
//                       const Expanded(child: Divider()),
//                       const Padding(
//                         padding: EdgeInsets.symmetric(horizontal: 16),
//                         child: Text('OR'),
//                       ),
//                       const Expanded(child: Divider()),
//                     ],
//                   ),
//                   const SizedBox(height: 16),
//
//                   // Google sign in button
//                   SizedBox(
//                     height: 50,
//                     child: OutlinedButton.icon(
//                       onPressed: _isLoading ? null : _signInWithGoogle,
//                       icon: Image.asset(
//                         'assets/images/google_logo.png',
//                         height: 24,
//                       ),
//                       label: const Text('Sign in with Google'),
//                       style: OutlinedButton.styleFrom(
//                         side: BorderSide(color: Colors.grey[300]!),
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 24),
//
//                   // Register link
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       const Text("Don't have an account?"),
//                       TextButton(
//                         onPressed: () {
//                           Navigator.pushNamed(context, '/register');
//                         },
//                         child: const Text('Register'),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }