// import 'package:flutter/material.dart';
// import 'package:your_app/services/auth_service.dart';
// import '../screens/home_screen.dart';
// import 'auth_service.dart';
//
// class AuthScreen extends StatefulWidget {
//   @override
//   _AuthScreenState createState() => _AuthScreenState();
// }
//
// class _AuthScreenState extends State<AuthScreen> {
//   final AuthService _authService = AuthService();
//   final _formKey = GlobalKey<FormState>();
//   String _email = '';
//   String _password = '';
//   bool _isLogin = true;
//
//   void _toggleForm() {
//     setState(() {
//       _isLogin = !_isLogin;
//     });
//   }
//
//   Future<void> _submit() async {
//     if (_formKey.currentState!.validate()) {
//       _formKey.currentState!.save();
//       if (_isLogin) {
//         await _authService.signIn(_email, _password);
//       } else {
//         await _authService.register(_email, _password);
//       }
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(builder: (context) => HomeScreen()),
//       );
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(_isLogin ? 'Login' : 'Register'),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             children: [
//               TextFormField(
//                 decoration: InputDecoration(labelText: 'Email'),
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return 'Please enter your email';
//                   }
//                   return null;
//                 },
//                 onSaved: (value) {
//                   _email = value!;
//                 },
//               ),
//               TextFormField(
//                 decoration: InputDecoration(labelText: 'Password'),
//                 obscureText: true,
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return 'Please enter your password';
//                   }
//                   return null;
//                 },
//                 onSaved: (value) {
//                   _password = value!;
//                 },
//               ),
//               SizedBox(height: 20),
//               ElevatedButton(
//                 onPressed: _submit,
//                 child: Text(_isLogin ? 'Login' : 'Register'),
//               ),
//               TextButton(
//                 onPressed: _toggleForm,
//                 child: Text(_isLogin
//                     ? 'Don\'t have an account? Register'
//                     : 'Already have an account? Login'),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }