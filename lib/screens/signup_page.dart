import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  String role = 'Customer';
  String name = '', email = '', password = '', confirmPassword = '';
  String businessName = '', contact = '', category = '', profileImage = '';
  bool isLoading = false;

  File? _profileImageFile;

  final List<String> categories = [
    'Food & Beverages',
    'Clothing',
    'Accessories',
    'Handicrafts',
    'Home Decor',
    'Grocery',
    'Books',
    'Stationery',
    'Personal Care',
    'Grooming',
    'Other'
  ];

  Future<void> pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final url =
          Uri.parse("https://api.cloudinary.com/v1_1/dwncvfoiq/image/upload");

      var request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = 'flutter_localgems'
        ..files.add(await http.MultipartFile.fromPath('file', pickedFile.path));

      final response = await request.send();
      final res = await http.Response.fromStream(response);
      final data = json.decode(res.body);

      if (response.statusCode == 200) {
        setState(() {
          profileImage = data['secure_url'];
          _profileImageFile = File(pickedFile.path);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Image upload failed")),
        );
      }
    }
  }

  Future<void> signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isLoading = true);

    try {
      final userCred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
              email: email.trim(), password: password.trim());

      final userData = {
        'name': name,
        'email': email,
        'role': role,
        'createdAt': Timestamp.now(),
      };

      if (role == 'Seller') {
        userData.addAll({
          'businessName': businessName,
          'contact': contact,
          'category': category,
          'seller_id': userCred.user!.uid,
          'profileImage': profileImage,
        });
      } else {
        userData['customer_id'] = userCred.user!.uid;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCred.user!.uid)
          .set(userData);

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Success"),
          content: const Text("Registration successful! Please login."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/login');
              },
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          /// Background image
          Positioned.fill(
            child: Image.asset(
              './lib/assets/bg.png',
              fit: BoxFit.cover,
            ),
          ),
          Container(color: const Color.fromARGB(255, 120, 159, 220).withOpacity(0.4)),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.9), // black box
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),

                      /// Toggle Role
                      ToggleButtons(
                        borderRadius: BorderRadius.circular(12),
                        selectedColor: Colors.white,
                        fillColor: const Color(0xFFef3167),
                        color: Colors.white70,
                        borderColor: Colors.white38,
                        selectedBorderColor: const Color(0xFFef3167),
                        isSelected: [role == 'Customer', role == 'Seller'],
                        onPressed: (index) {
                          setState(() {
                            role = index == 0 ? 'Customer' : 'Seller';
                          });
                        },
                        children: const [
                          Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Text("Customer",
                                style: TextStyle(fontSize: 16)),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Text("Seller",
                                style: TextStyle(fontSize: 16)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      /// Name
                      _field('Name', (val) => name = val),
                      const SizedBox(height: 3),

                      if (role == 'Seller') ...[
                        const SizedBox(height: 16),

                        /// Seller Profile Image
                        GestureDetector(
                          onTap: pickAndUploadImage,
                          child: CircleAvatar(
                            radius: 45,
                            backgroundImage: _profileImageFile != null
                                ? FileImage(_profileImageFile!)
                                : (profileImage.isNotEmpty
                                    ? NetworkImage(profileImage)
                                    : null) as ImageProvider?,
                            backgroundColor: Colors.grey[300],
                            child: _profileImageFile == null &&
                                    profileImage.isEmpty
                                ? const Icon(Icons.camera_alt,
                                    size: 30, color: Colors.black54)
                                : null,
                          ),
                        ),
                        const SizedBox(height: 16),

                        _field('Business Name', (val) => businessName = val),
                        const SizedBox(height: 3),
                        _field('Contact', (val) => contact = val),
                        const SizedBox(height: 3),

                        SizedBox(
                          height: 60,
                          child: DropdownButtonFormField<String>(
                            value: category.isNotEmpty ? category : null,
                            decoration: _inputDecoration('Category'),
                            dropdownColor: Colors.black,
                            style: const TextStyle(color: Colors.white),
                            items: categories
                                .map((e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(e,
                                          style: const TextStyle(
                                              color: Colors.white)),
                                    ))
                                .toList(),
                            onChanged: (val) =>
                                setState(() => category = val!),
                          ),
                        ),
                        const SizedBox(height: 3),
                      ],

                      _field('Email', (val) => email = val,
                          validator: (v) =>
                              v!.contains('@') ? null : 'Invalid email'),
                      const SizedBox(height: 3),
                      _field('Password', (val) => password = val,
                          obscure: true,
                          validator: (v) =>
                              v!.length < 6 ? 'Minimum 6 characters' : null),
                      const SizedBox(height: 3),
                      _field('Confirm Password', (val) => confirmPassword = val,
                          obscure: true,
                          validator: (v) =>
                              v != password ? 'Passwords do not match' : null),

                      const SizedBox(height: 20),

                      isLoading
                          ? const CircularProgressIndicator(
                              color: Color(0xFFef3167))
                          : SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: signUp,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFef3167),
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text(
                                  'Register',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),

                      const SizedBox(height: 12),

                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacementNamed(context, '/login');
                        },
                        child: const Text(
                          'Already have an account? Login here',
                          style: TextStyle(
                            color: Color(0xFFef3167),
                            fontWeight: FontWeight.w500,
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

  TextFormField _field(String hint, Function(String) onChanged,
      {bool obscure = false, String? Function(String?)? validator}) {
    return TextFormField(
      decoration: _inputDecoration(hint),
      style: _textStyle(),
      obscureText: obscure,
      validator: validator ?? (val) => val!.isEmpty ? 'Required' : null,
      onChanged: onChanged,
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color.fromARGB(179, 5, 5, 5)),
      filled: true,
      fillColor: const Color.fromARGB(255, 247, 245, 245),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none // no outline border
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFef3167), width: 2),
      ),
    );
  }

  TextStyle _textStyle() => const TextStyle(color: Color.fromARGB(255, 1, 1, 1));
}
