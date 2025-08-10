import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class EditSellerProfile extends StatefulWidget {
  final String uid;
  const EditSellerProfile({super.key, required this.uid});

  @override
  State<EditSellerProfile> createState() => _EditSellerProfileState();
}

class _EditSellerProfileState extends State<EditSellerProfile> {
  final _formKey = GlobalKey<FormState>();

  // Controllers for form fields
  late TextEditingController businessNameController;
  late TextEditingController descriptionController;
  late TextEditingController locationController;
  late TextEditingController priceRangeController;

  String category = '';
  String imageUrl = '';
  File? imageFile;
  bool isLoading = false;

  final List<String> categories = [
    'Food & Beverages', 'Clothing', 'Accessories', 'Handicrafts',
    'Home Decor', 'Grocery', 'Books', 'Stationery', 'Personal Care', 'Other'
  ];

  @override
  void initState() {
    super.initState();
    businessNameController = TextEditingController();
    descriptionController = TextEditingController();
    locationController = TextEditingController();
    priceRangeController = TextEditingController();
    _fetchCurrentDetails();
  }

  Future<void> _fetchCurrentDetails() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(widget.uid).get();
    final data = doc.data();
    if (data != null) {
      setState(() {
        businessNameController.text = data['businessName'] ?? '';
        category = data['category'] ?? '';
        descriptionController.text = data['description'] ?? '';
        locationController.text = data['location'] ?? '';
        priceRangeController.text = data['priceRange'] ?? '';
        imageUrl = data['profilePic'] ?? '';
      });
    }
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        imageFile = File(picked.path);
      });
      await _uploadToCloudinary(imageFile!);
    }
  }

  Future<void> _uploadToCloudinary(File image) async {
    final url = Uri.parse('https://api.cloudinary.com/v1_1/dwncvfoiq/image/upload');
    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = 'flutter_localgems'
      ..files.add(await http.MultipartFile.fromPath('file', image.path));

    final res = await request.send();
    final resBody = await res.stream.bytesToString();
    final responseData = json.decode(resBody);
    setState(() {
      imageUrl = responseData['secure_url'];
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({
      'businessName': businessNameController.text,
      'category': category,
      'description': descriptionController.text,
      'location': locationController.text,
      'priceRange': priceRangeController.text,
      'profilePic': imageUrl,
    });

    setState(() => isLoading = false);
    Navigator.pop(context);
  }

  @override
  void dispose() {
    businessNameController.dispose();
    descriptionController.dispose();
    locationController.dispose();
    priceRangeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Profile")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: CircleAvatar(
                        radius: 60,
                        backgroundImage: imageUrl.isNotEmpty
                            ? NetworkImage(imageUrl)
                            : const AssetImage('./lib/assets/placeholder.png') as ImageProvider,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: businessNameController,
                      decoration: const InputDecoration(labelText: "Business Name"),
                      validator: (val) => val!.isEmpty ? 'Required' : null,
                    ),
                    DropdownButtonFormField<String>(
                      value: category.isNotEmpty ? category : null,
                      decoration: const InputDecoration(labelText: "Category"),
                      items: categories.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (val) => setState(() => category = val!),
                    ),
                    TextFormField(
                      controller: descriptionController,
                      decoration: const InputDecoration(labelText: "Description"),
                      maxLines: 3,
                      validator: (val) => val!.isEmpty ? 'Required' : null,
                    ),
                    TextFormField(
                      controller: locationController,
                      decoration: const InputDecoration(labelText: "Location"),
                      validator: (val) => val!.isEmpty ? 'Required' : null,
                    ),
                    TextFormField(
                      controller: priceRangeController,
                      decoration: const InputDecoration(labelText: "Price Range"),
                      validator: (val) => val!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: _saveProfile,
                      child: const Text('Save Changes'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
