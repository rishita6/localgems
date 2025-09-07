import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class login_page extends StatefulWidget {
  const login_page({super.key});

  @override
  State<login_page> createState() => _login_pageState();
}

class _login_pageState extends State<login_page> {
  final _formKey = GlobalKey<FormState>();
  String email = '';
  String password = '';
  bool isLoading = false;
  String? errorMessage;

  Future<void> login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final userCred = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email.trim(), password: password);

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCred.user!.uid)
          .get();

      String role = userDoc['role'];

      if (role == 'Customer') {
        Navigator.pushReplacementNamed(context, '/customer_home');
      } else {
        Navigator.pushReplacementNamed(context, '/seller_home');
      }
    } on FirebaseAuthException catch (_) {
      setState(() {
        errorMessage = "Invalid email or password";
      });
    } catch (e) {
      setState(() {
        errorMessage = "Something went wrong. Try again.";
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 🌸 Background
          Positioned.fill(
            child: Image.asset(
              './lib/assets/bg.png',
              fit: BoxFit.cover,
            ),
          ),
          Container(
              color:
                  const Color.fromARGB(255, 120, 159, 220).withOpacity(0.4)),

          // 🌸 Login Card
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.black, // 🔥 Black box
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(4, 6),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Welcome Back!',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Colors.white, // white text
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Email
                      TextFormField(
                        decoration: _inputDecoration('Email'),
                        style: const TextStyle(color: Colors.black87),
                        onChanged: (val) => email = val,
                        validator: (val) =>
                            val!.contains('@') ? null : 'Enter valid email',
                      ),
                      const SizedBox(height: 16),

                      // Password
                      TextFormField(
                        decoration: _inputDecoration('Password'),
                        style: const TextStyle(color: Colors.black87),
                        obscureText: true,
                        onChanged: (val) => password = val,
                        validator: (val) =>
                            val!.length >= 6 ? null : 'Minimum 6 characters',
                      ),
                      const SizedBox(height: 24),

                      // Button
                      isLoading
                          ? const CircularProgressIndicator(
                              color: Color(0xFFef3167),
                            )
                          : SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFef3167), // pink
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 6,
                                ),
                                child: const Text(
                                  'Login',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),

                      const SizedBox(height: 14),

                      // 🔥 Error Message
                      if (errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            border: Border.all(
                                color: const Color(0xFFef3167), width: 2),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 10,
                                offset: const Offset(2, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error, color: Color(0xFFef3167)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  errorMessage!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Register
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/signup');
                        },
                        child: const Text(
                          'Don’t have an account? Register here',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFef3167),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint, // 👈 placeholder instead of label
      hintStyle: const TextStyle(color: Colors.black54),
      filled: true,
      fillColor: Colors.white, // input box white
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none, // no border line
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFef3167), width: 2),
      ),
    );
  }
}
