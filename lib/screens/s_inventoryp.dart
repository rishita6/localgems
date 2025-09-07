// lib/screens/s_inventoryp.dart
// Updated: moved star to top-left + StreamBuilder for realtime toggling + removed duplicate star

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class _Palette {
  static const blueBg = Color(0xFFD0E3FF); // page background
  static const pink = Color(0xFFEF3167); // accent
  static const textDark = Color(0xFF222222);
  static const textSoft = Color(0xFF6B7280);
  static const cardCream = Color(0xFFFFFBF7); // soft cream
  static const white = Colors.white;
}

class s_inventoryp extends StatefulWidget {
  final String sellerId;
  const s_inventoryp({super.key, required this.sellerId});

  @override
  State<s_inventoryp> createState() => _s_inventorypState();
}

class _s_inventorypState extends State<s_inventoryp> {
  final _formKey = GlobalKey<FormState>();
  String name = '', description = '', price = '', stock = '';
  File? imageFile;
  String imageUrl = '';
  bool isLoading = false;
  String? editingDocId;

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      imageFile = File(picked.path);
      await _uploadToCloudinary(imageFile!);
    }
  }

  Future<void> _uploadToCloudinary(File image) async {
    final url = Uri.parse('https://api.cloudinary.com/v1_1/dwncvfoiq/image/upload');
    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = 'flutter_localgems'
      ..files.add(await http.MultipartFile.fromPath('file', image.path));

    final response = await request.send();
    final resBody = await response.stream.bytesToString();
    final resData = json.decode(resBody);
    setState(() => imageUrl = (resData['secure_url'] ?? '').toString());
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate() || imageUrl.isEmpty) return;
    setState(() => isLoading = true);

    if (editingDocId == null) {
      final docRef = FirebaseFirestore.instance.collection('products').doc();
      await docRef.set({
        'product_id': docRef.id,
        'sellerId': widget.sellerId,
        'name': name,
        'description': description,
        'price': double.tryParse(price) ?? 0.0,
        'stock': int.tryParse(stock) ?? 0,
        'imageUrl': imageUrl,
        'createdAt': Timestamp.now(),
      });
    } else {
      await FirebaseFirestore.instance.collection('products').doc(editingDocId).update({
        'name': name,
        'description': description,
        'price': double.tryParse(price) ?? 0.0,
        'stock': int.tryParse(stock) ?? 0,
        'imageUrl': imageUrl,
      });
    }

    setState(() {
      isLoading = false;
      name = '';
      description = '';
      price = '';
      stock = '';
      imageUrl = '';
      imageFile = null;
      editingDocId = null;
    });
    if (mounted) Navigator.pop(context);
  }

  void _openProductForm({Map<String, dynamic>? existingData, String? docId}) {
    if (existingData != null) {
      name = (existingData['name'] ?? '').toString();
      description = (existingData['description'] ?? '').toString();
      price = (existingData['price'] ?? '').toString();
      stock = (existingData['stock'] ?? '').toString();
      imageUrl = (existingData['imageUrl'] ?? '').toString();
      editingDocId = docId;
    } else {
      name = description = price = stock = imageUrl = '';
      editingDocId = null;
    }

    showModalBottomSheet(
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      context: context,
      builder: (_) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 20,
        ),
        decoration: BoxDecoration(
          color: _Palette.cardCream,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 48,
                    backgroundImage:
                        imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                    child: imageUrl.isEmpty
                        ? const Icon(Icons.photo, size: 36, color: _Palette.textSoft)
                        : null,
                    backgroundColor: _Palette.white,
                  ),
                ),
                const SizedBox(height: 16),
                _buildTextField("Product Name", name, (val) => name = val),
                const SizedBox(height: 12),
                _buildTextField("Description", description, (val) => description = val, maxLines: 2),
                const SizedBox(height: 12),
                _buildTextField("Price", price, (val) => price = val, keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                _buildTextField("Stock", stock, (val) => stock = val, keyboardType: TextInputType.number),
                const SizedBox(height: 20),
                isLoading
                    ? const CircularProgressIndicator(color: _Palette.pink)
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _Palette.pink,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                        ),
                        onPressed: _saveProduct,
                        child: Text(editingDocId == null ? "Add Product" : "Update Product"),
                      ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, String initialValue, Function(String) onChanged,
      {TextInputType keyboardType = TextInputType.text, int maxLines = 1}) {
    return TextFormField(
      style: const TextStyle(color: _Palette.textDark),
      initialValue: initialValue,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _Palette.textSoft),
        filled: true,
        fillColor: _Palette.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: (val) => (val == null || val.isEmpty) ? 'Required' : null,
      onChanged: onChanged,
    );
  }

  Future<void> _deleteProduct(String docId) async {
    await FirebaseFirestore.instance.collection('products').doc(docId).delete();
    await FirebaseFirestore.instance.collection('top_products').doc(docId).delete();
  }

  Future<void> _toggleTopProduct(String productId, Map<String, dynamic> data) async {
    final ref = FirebaseFirestore.instance.collection('top_products').doc(productId);
    final snap = await ref.get();
    if (snap.exists) {
      await ref.delete();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Removed from Top Products")));
    } else {
      await ref.set({
        'product_id': productId,
        'seller_id': widget.sellerId,
        'name': data['name'],
        'price': data['price'],
        'imageUrl': data['imageUrl'],
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Added to Top Products")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewPadding.bottom + 16.0;

    return Scaffold(
      backgroundColor: _Palette.blueBg,
      appBar: AppBar(
        backgroundColor: _Palette.blueBg,
        elevation: 0,
        leading: const BackButton(color: _Palette.textDark),
        title: const Text("Inventory", style: TextStyle(color: _Palette.textDark, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: _Palette.pink, size: 28),
            onPressed: () => _openProductForm(),
            tooltip: 'Add product',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('products').where('sellerId', isEqualTo: widget.sellerId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Error", style: TextStyle(color: _Palette.textSoft)));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _Palette.pink));
          }

          final products = snapshot.data?.docs ?? [];
          if (products.isEmpty) {
            return const Center(child: Text("No products yet.", style: TextStyle(color: _Palette.textSoft)));
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(12, 8, 12, bottomPad),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.72,
              ),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final doc = products[index];
                final data = (doc.data() as Map<String, dynamic>?) ?? {};
                final docId = doc.id;
                final image = (data['imageUrl'] ?? '').toString();
                final title = (data['name'] ?? 'Product').toString();
                final pr = (data['price'] ?? 0).toString();
                final stk = (data['stock'] ?? 0).toString();

                return GestureDetector(
                  onTap: () => _openProductForm(existingData: data, docId: docId),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _Palette.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(2, 3))],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Stack(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // flexible image region
                              Expanded(
                                child: image.isNotEmpty
                                    ? Image.network(image, fit: BoxFit.cover, width: double.infinity)
                                    : Container(color: Colors.grey[200]),
                              ),

                              // body (title / stock / price)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(title, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _Palette.textDark, fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        // Stock is now never overlapped by the star
                                        Text('Stock: $stk', style: const TextStyle(color: _Palette.textSoft, fontSize: 13)),
                                        Text('₹$pr', style: const TextStyle(color: _Palette.textDark, fontWeight: FontWeight.w700)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          // top-right three-dots
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Material(
                              color: Colors.transparent,
                              child: PopupMenuButton<String>(
                                onSelected: (v) async {
                                  if (v == 'edit') {
                                    _openProductForm(existingData: data, docId: docId);
                                  } else if (v == 'delete') {
                                    await _deleteProduct(docId);
                                  } 
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                                 
                                ],
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(color: const Color.fromARGB(255, 2, 2, 2).withOpacity(0.9), shape: BoxShape.circle),
                                  child: const Icon(Icons.more_horiz, size: 18, color: Color.fromARGB(255, 245, 241, 241)),
                                ),
                              ),
                            ),
                          ),

                          // top-left star (StreamBuilder -> realtime updates)
                          Positioned(
                            left: 8,
                            top: 8,
                            child: StreamBuilder<DocumentSnapshot>(
                              stream: FirebaseFirestore.instance.collection('top_products').doc(docId).snapshots(),
                              builder: (context, topSnap) {
                                final isTop = topSnap.data?.exists ?? false;
                                return InkWell(
                                  onTap: () => _toggleTopProduct(docId, data),
                                  borderRadius: BorderRadius.circular(18),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color.fromARGB(255, 6, 5, 5).withOpacity(0.9),
                                      shape: BoxShape.circle,
                                      boxShadow: [BoxShadow(color: const Color.fromARGB(255, 247, 243, 243).withOpacity(0.06), blurRadius: 2)],
                                    ),
                                    child: Icon(
                                      isTop ? Icons.star : Icons.star_border,
                                      color: isTop ? Colors.amber : const Color.fromARGB(255, 241, 242, 245),
                                      size: 18,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
