import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:localgems_proj/screens/addToCart.dart';
import 's_profilep.dart';
import 'customer_scaffold.dart'; // reuse pastel theme

class ProductDetailPage extends StatelessWidget {
  final String productId;
  final String sellerId;
  const ProductDetailPage({
    super.key,
    required this.productId,
    required this.sellerId,
  });

  Future<void> addToCartitem(
    BuildContext context, {
    required String productId,
    required String name,
    required String imageUrl,
    required num price,
    required String sellerId,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      showDialog(
        context: context,
        builder: (_) => const AlertDialog(
          title: Text("Login Required"),
          content: Text("Please login to add products to your cart."),
        ),
      );
      return;
    }

    try {
      final cartRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('cart')
          .doc(productId);

      final snap = await cartRef.get();
      if (snap.exists) {
        await cartRef.update({
          'quantity': FieldValue.increment(1),
        });
      } else {
        await cartRef.set({
          'productId': productId,
          'name': name,
          'imageUrl': imageUrl,
          'price': price,
          'quantity': 1,
          'sellerId': sellerId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Show success dialog
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Added to Cart"),
          content: const Text("Product has been added to your cart."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Continue Shopping"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddToCart()),
                );
              },
              child: const Text("Go to Cart"),
            ),
          ],
        ),
      );
    } catch (e) {
      showDialog(
        context: context,
        builder: (_) => const AlertDialog(
          title: Text("Error"),
          content: Text("Failed to add product to cart."),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Product",
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('products')
            .doc(productId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.accent));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text("Product not found",
                  style: TextStyle(color: AppColors.textSoft)),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final name = (data['name'] ?? '').toString();
          final img = (data['imageUrl'] ?? '').toString();
          final desc = (data['description'] ?? '').toString();
          final price = (data['price'] ?? 0);
          final priceStr =
              (price is num) ? price.toStringAsFixed(0) : price.toString();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: img.isNotEmpty
                      ? Image.network(img,
                          width: double.infinity,
                          height: 240,
                          fit: BoxFit.cover)
                      : Container(
                          height: 240,
                          color: AppColors.bg,
                          child: const Icon(Icons.image,
                              color: AppColors.textSoft),
                        ),
                ),
                const SizedBox(height: 16),
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text("₹ $priceStr",
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    )),
                const SizedBox(height: 8),
                Text(
                  desc,
                  style: const TextStyle(
                    color: AppColors.textSoft,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                // Add to cart button
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          addToCartitem(
                            context,
                            productId: productId,
                            name: name,
                            imageUrl: img,
                            price: price,
                            sellerId: sellerId,
                          );
                        },
                        icon: const Icon(Icons.add_shopping_cart,
                            color: Colors.white),
                        label: const Text(
                          "Add to Cart",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: const StadiumBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Go to store
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => s_profilep(sellerId: sellerId)),
                      );
                    },
                    icon: const Icon(Icons.store_mall_directory_rounded,
                        color: AppColors.accent),
                    label: const Text(
                      "Go to Store",
                      style: TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
