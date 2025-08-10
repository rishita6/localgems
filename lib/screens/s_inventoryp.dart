import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;


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
    setState(() => imageUrl = resData['secure_url']);
  }

  Future<void> _addProduct() async {
    if (!_formKey.currentState!.validate() || imageUrl.isEmpty) return;

    setState(() => isLoading = true);

    await FirebaseFirestore.instance.collection('products').add({
      'sellerId': widget.sellerId,
      'name': name,
      'description': description,
      'price': double.parse(price),
      'stock': int.parse(stock),
      'imageUrl': imageUrl,
      'createdAt': Timestamp.now(),
    });

    setState(() {
      isLoading = false;
      name = '';
      description = '';
      price = '';
      stock = '';
      imageUrl = '';
      imageFile = null;
    });
    Navigator.pop(context); // Close the form
  }

  void _openAddProductForm() {
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16, right: 16, top: 20),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 50,
                    backgroundImage: imageUrl.isNotEmpty
                        ? NetworkImage(imageUrl)
                        : const AssetImage('assets/placeholder.png') as ImageProvider,
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Product Name'),
                  validator: (val) => val!.isEmpty ? 'Required' : null,
                  onChanged: (val) => name = val,
                ),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                  validator: (val) => val!.isEmpty ? 'Required' : null,
                  onChanged: (val) => description = val,
                ),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Price'),
                  keyboardType: TextInputType.number,
                  validator: (val) => val!.isEmpty ? 'Required' : null,
                  onChanged: (val) => price = val,
                ),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Stock (units)'),
                  keyboardType: TextInputType.number,
                  validator: (val) => val!.isEmpty ? 'Required' : null,
                  onChanged: (val) => stock = val,
                ),
                const SizedBox(height: 20),
                isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _addProduct,
                        child: const Text("Add Product"),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteProduct(String docId) async {
    await FirebaseFirestore.instance.collection('products').doc(docId).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _openAddProductForm,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('products')
            .where('sellerId', isEqualTo: widget.sellerId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("Error"));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final products = snapshot.data!.docs;

          if (products.isEmpty) {
            return const Center(child: Text("No products yet."));
          }

          return ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, index) {
              final data = products[index].data() as Map<String, dynamic>;
              final docId = products[index].id;

              return Card(
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(data['imageUrl']),
                  ),
                  title: Text(data['name']),
                  subtitle: Text('₹${data['price']} • Stock: ${data['stock']}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteProduct(docId),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
