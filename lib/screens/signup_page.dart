// Add your imports
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class signup_page extends StatefulWidget {
  const signup_page({super.key});

  @override
  State<signup_page> createState() => _signup_pageState();
}

class _signup_pageState extends State<signup_page> {
  final _formKey = GlobalKey<FormState>();
  String role = 'Customer';
  String name = '', email = '', password = '', confirmPassword = '';
  String businessName = '', contact = '', category = '', location = '', priceRange = '', profileImage = '';
  bool isLoading = false;

  File? _profileImageFile;

  final List<String> categories = [
    'Food & Beverages', 'Clothing', 'Accessories', 'Handicrafts',
    'Home Decor', 'Grocery', 'Books', 'Stationery', 'Personal Care', 'Other'
  ];

  Future<void> pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final url = Uri.parse("https://api.cloudinary.com/v1_1/dwncvfoiq/image/upload");

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
          SnackBar(content: Text("Image upload failed")),
        );
      }
    }
  }

  Future<void> signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isLoading = true);

    try {
      final UserCredential userCred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email.trim(), password: password.trim());

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
          'location': location,
          'priceRange': priceRange,
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration successful! Now login.')),
      );
      Navigator.pushReplacementNamed(context, '/login');
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
          // 🔷 Background Image
          Positioned.fill(
            child: Image.asset(
              './lib/assets/bg.png',
              fit: BoxFit.cover,
            ),
          ),
          // 🔷 Gradient Overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0x6CD05134), Color.fromARGB(108, 188, 87, 5)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          // 🔷 Registration Form Card
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        value: role,
                        style: TextStyle(color: Colors.white),
                        dropdownColor: Colors.black,
                        decoration: _inputDecoration('Register As'),
                        items: ['Customer', 'Seller']
                            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (val) => setState(() => role = val!),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        decoration: _inputDecoration('Name'),
                        style: _textStyle(),
                        validator: (val) => val!.isEmpty ? 'Required' : null,
                        onChanged: (val) => name = val,
                      ),
                      if (role == 'Seller') ...[
                        const SizedBox(height: 10),
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
                            child: _profileImageFile == null && profileImage.isEmpty
                                ? const Icon(Icons.camera_alt, size: 30, color: Colors.black54)
                                : null,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          decoration: _inputDecoration('Business Name'),
                          style: _textStyle(),
                          validator: (val) => val!.isEmpty ? 'Required' : null,
                          onChanged: (val) => businessName = val,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          decoration: _inputDecoration('Contact'),
                          style: _textStyle(),
                          validator: (val) => val!.isEmpty ? 'Required' : null,
                          onChanged: (val) => contact = val,
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: category.isNotEmpty ? category : null,
                          style: TextStyle(color: Colors.white),
                          dropdownColor: Colors.black,
                          decoration: _inputDecoration('Category'),
                          items: categories
                              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (val) => setState(() => category = val!),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          decoration: _inputDecoration('Location'),
                          style: _textStyle(),
                          validator: (val) => val!.isEmpty ? 'Required' : null,
                          onChanged: (val) => location = val,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          decoration: _inputDecoration('Starting Price'),
                          style: _textStyle(),
                          validator: (val) => val!.isEmpty ? 'Required' : null,
                          onChanged: (val) => priceRange = val,
                        ),
                      ],
                      const SizedBox(height: 10),
                      TextFormField(
                        decoration: _inputDecoration('Email'),
                        style: _textStyle(),
                        validator: (val) => val!.contains('@') ? null : 'Invalid email',
                        onChanged: (val) => email = val,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        decoration: _inputDecoration('Password'),
                        style: _textStyle(),
                        obscureText: true,
                        validator: (val) => val!.length < 6 ? 'Minimum 6 characters' : null,
                        onChanged: (val) => password = val,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        decoration: _inputDecoration('Confirm Password'),
                        style: _textStyle(),
                        obscureText: true,
                        validator: (val) => val != password ? 'Passwords do not match' : null,
                      ),
                      const SizedBox(height: 20),
                      isLoading
                          ? const CircularProgressIndicator()
                          : SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: signUp,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF72634), // 🔴 Orange red
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: const Text(
                                  'Register',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Color.fromARGB(245, 234, 222, 234)),
      filled: true,
      fillColor: Color(0xFFF9826C).withOpacity(0.1), // Soft pink
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.black12),
      ),
    );
  }

  TextStyle _textStyle() {
    return TextStyle(color: Color.fromARGB(245, 234, 222, 234));
  }
}
