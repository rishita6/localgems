import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class EditSellerProfile extends StatefulWidget {
  final String? uid;
  const EditSellerProfile({super.key, this.uid});

  @override
  State<EditSellerProfile> createState() => _EditSellerProfileState();
}

class _EditSellerProfileState extends State<EditSellerProfile> {
  static const Color kBg = Color(0xFFD0E3FF); // lavender
  static const Color kCard = Color(0xFFFFFCF9); // cream-white
  static const Color kAccent = Color(0xFFEF3167); // pink button
  static const Color kTextDark = Color(0xFF222222);
  static const Color kTextSoft = Color(0xFF666666);

  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  bool _saving = false;

  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final contactCtrl = TextEditingController();
  final businessNameCtrl = TextEditingController();
  final descriptionCtrl = TextEditingController();
  final locationCtrl = TextEditingController();
  final priceRangeCtrl = TextEditingController();
  String category = '';
  String profileImageUrl = '';

  final List<String> categories = const [
    'Food & Beverages',
    'Clothing',
    'Accessories',
    'Handicrafts',
    'Home Decor',
    'Grocery',
    'Books',
    'Stationery',
    'Personal Care',
    'Other',
  ];

  static const String cloudName = 'dwncvfoiq';
  static const String uploadPreset = 'flutter_localgems';

  @override
  void initState() {
    super.initState();
    _loadSeller();
  }

  Future<String> _effectiveUid() async {
    return widget.uid ?? FirebaseAuth.instance.currentUser!.uid;
  }

  Future<void> _loadSeller() async {
    final uid = await _effectiveUid();
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();

    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      nameCtrl.text = data['name'] ?? '';
      emailCtrl.text = data['email'] ?? '';
      contactCtrl.text = data['contact'] ?? '';
      businessNameCtrl.text = data['businessName'] ?? '';
      descriptionCtrl.text = data['description'] ?? '';
      locationCtrl.text = data['location'] ?? '';
      priceRangeCtrl.text = data['priceRange'] ?? '';
      category = (data['category'] ?? '').toString();
      profileImageUrl = data['profileImage'] ?? '';
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final uid = await _effectiveUid();
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'name': nameCtrl.text.trim(),
      'email': emailCtrl.text.trim(),
      'contact': contactCtrl.text.trim(),
      'businessName': businessNameCtrl.text.trim(),
      'description': descriptionCtrl.text.trim(),
      'location': locationCtrl.text.trim(),
      'priceRange': priceRangeCtrl.text.trim(),
      'category': category,
      'profileImage': profileImageUrl,
    });

    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickAndUploadImage() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    final file = File(picked.path);
    final uri =
        Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
    final req = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final res = await req.send();
    final body = await res.stream.bytesToString();
    final decoded = json.decode(body);
    final url = decoded['secure_url']?.toString() ?? '';
    if (url.isNotEmpty) setState(() => profileImageUrl = url);
  }

  InputDecoration _decor(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: kTextSoft, fontSize: 13),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: kAccent, width: 2)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: kTextDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Edit Profile',
            style: TextStyle(
                color: kTextDark, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kAccent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Avatar + camera
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundImage: profileImageUrl.isNotEmpty
                            ? NetworkImage(profileImageUrl)
                            : const AssetImage('lib/assets/placeholder.png')
                                as ImageProvider,
                        backgroundColor: Colors.grey.shade300,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: InkWell(
                          onTap: _pickAndUploadImage,
                          borderRadius: BorderRadius.circular(22),
                          child: Container(
                            decoration: const BoxDecoration(
                                color: kAccent, shape: BoxShape.circle),
                            padding: const EdgeInsets.all(8),
                            child: const Icon(Icons.camera_alt,
                                size: 20, color: Colors.white),
                          ),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Form
                  Form(
                    key: _formKey,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: kCard,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Column(
                        children: [
                          TextFormField(
                              controller: nameCtrl,
                              style: const TextStyle(color: kTextDark),
                              decoration: _decor("Owner Name"),
                              validator: (v) =>
                                  v!.isEmpty ? 'Required' : null),
                          const SizedBox(height: 14),
                          TextFormField(
                              controller: businessNameCtrl,
                              style: const TextStyle(color: kTextDark),
                              decoration: _decor("Business Name"),
                              validator: (v) =>
                                  v!.isEmpty ? 'Required' : null),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            value: category.isNotEmpty ? category : null,
                            dropdownColor: kCard,
                            items: categories
                                .map((c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c,
                                        style: const TextStyle(
                                            color: kTextDark))))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => category = v ?? ''),
                            decoration: _decor("Category"),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: descriptionCtrl,
                            maxLines: 3,
                            style: const TextStyle(color: kTextDark),
                            decoration: _decor("Description"),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                              controller: contactCtrl,
                              style: const TextStyle(color: kTextDark),
                              keyboardType: TextInputType.phone,
                              decoration: _decor("Contact")),
                          const SizedBox(height: 14),
                          TextFormField(
                              controller: emailCtrl,
                              style: const TextStyle(color: kTextDark),
                              keyboardType: TextInputType.emailAddress,
                              decoration: _decor("Email")),
                          const SizedBox(height: 14),
                          TextFormField(
                              controller: locationCtrl,
                              style: const TextStyle(color: kTextDark),
                              decoration: _decor("Location")),
                          const SizedBox(height: 14),
                          TextFormField(
                              controller: priceRangeCtrl,
                              style: const TextStyle(color: kTextDark),
                              keyboardType: TextInputType.number,
                              decoration: _decor("Price Range")),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _saving ? null : _save,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kAccent,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                              child: _saving
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2))
                                  : const Text("Save Changes",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
    );
  }
}
