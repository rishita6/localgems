import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class add_products extends StatelessWidget {
  final String sellerId;
  const add_products({super.key, required this.sellerId});

  Future<void> _addToTopProducts(
      Map<String, dynamic> itemData, String productId) async {
    try {
      await FirebaseFirestore.instance.collection('top_products').add({
        'product_id': productId, // ✅ Correctly store the products doc.id
        'seller_id': itemData['sellerId'],
        'name': itemData['name'],
        'description': itemData['description'],
        'imageUrl': itemData['imageUrl'],
        'createdAt': DateTime.now(),
      });
    } catch (e) {
      debugPrint("Error adding product: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Choose from Inventory"),
        backgroundColor: Colors.orange,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('products')
            .where('sellerId', isEqualTo: sellerId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                "Error loading inventory",
                style: TextStyle(color: Colors.white),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.orange),
            );
          }

          final items = snapshot.data!.docs;
          if (items.isEmpty) {
            return const Center(
              child: Text(
                "No items in inventory",
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final data = items[index].data() as Map<String, dynamic>;
              final productId = items[index].id; // ✅ Get the actual doc.id

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  image: const DecorationImage(
                    image: AssetImage("./lib/assets/prf1.png"),
                    fit: BoxFit.cover,
                    opacity: 0.1,
                  ),
                  color: Colors.black.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange, width: 1),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      data['imageUrl'] ?? '',
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  ),
                  title: Text(
                    data['name'] ?? '', // ⚠️ you had 'Name' (capital N) earlier
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    "₹${data['price'] ?? 'N/A'}  |  Stock: ${data['stock'] ?? 'N/A'}",
                    style: const TextStyle(color: Colors.orangeAccent),
                  ),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () async {
                      await _addToTopProducts(data, productId);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Added to top products!")),
                      );
                    },
                    child: const Text("Add"),
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
