// lib/favorites_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'common_widgets.dart';
import 's_profilep.dart'; // navigate to store profile

class FavoriteStoresPage extends StatelessWidget {
  final String uid;
  const FavoriteStoresPage({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    final favRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('favorite_stores');

    return DarkScaffold(
      title: 'Favorite Stores',
      child: Container(
        color: const Color(0xFFD0E3FF), // blue theme background
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: favRef.orderBy('storeName').snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFFEF3167)),
              );
            }

            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    SizedBox(height: 60),
                    Icon(Icons.favorite_border, size: 72, color: Color(0xFF6B7280)),
                    SizedBox(height: 18),
                    Text('No favorite stores yet', style: TextStyle(fontSize: 18, color: Color(0xFF6B7280))),
                    SizedBox(height: 8),
                    Text('Tap the heart on a store to save it here.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF6B7280)))
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final favDoc = docs[index];
                final fav = favDoc.data();

                final localStoreName = (fav['storeName'] ?? '').toString();
                final localSellerName = (fav['name'] ?? fav['sellerName'] ?? '').toString();
                final localCategory = (fav['category'] ?? '').toString();
                final localImageUrl = (fav['imageUrl'] ?? '').toString();
                final storeId = (fav['storeId'] ?? '').toString();

                Widget buildTile({
                  required String storeName,
                  required String sellerName,
                  required String category,
                  required String imageUrl,
                }) {
                  final imageProvider = (imageUrl.isNotEmpty)
                      ? NetworkImage(imageUrl)
                      : const AssetImage('./lib/assets/placeholder.png') as ImageProvider;

                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        // navigate to store details if we have storeId
                        if (storeId.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => s_profilep(sellerId: storeId)),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Store id not available to open profile')));
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundImage: imageProvider,
                              backgroundColor: const Color(0xFFD0E3FF),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    storeName.isNotEmpty ? storeName : 'Store',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF222222)),
                                  ),
                                  const SizedBox(height: 4),
                                  if (sellerName.isNotEmpty)
                                    Text(sellerName, style: const TextStyle(color: Color(0xFF6B7280))),
                                  if (category.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6.0),
                                      child: Text(category, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                                    ),
                                ],
                              ),
                            ),

                            IconButton(
                              icon: const Icon(Icons.favorite, color: Color(0xFFEF3167)),
                              onPressed: () async {
                                await favDoc.reference.delete();
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removed from favorites')));
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                final hasLocalInfo = localStoreName.isNotEmpty || localSellerName.isNotEmpty || localCategory.isNotEmpty || localImageUrl.isNotEmpty;

                if (hasLocalInfo) {
                  return buildTile(
                    storeName: localStoreName,
                    sellerName: localSellerName,
                    category: localCategory,
                    imageUrl: localImageUrl,
                  );
                }

                if (storeId.isNotEmpty) {
                  return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    future: FirebaseFirestore.instance.collection('stores').doc(storeId).get(),
                    builder: (context, storeSnap) {
                      if (storeSnap.connectionState == ConnectionState.waiting) {
                        return Card(
                          child: ListTile(
                            title: Text(localStoreName.isNotEmpty ? localStoreName : 'Loading store...'),
                          ),
                        );
                      }

                      final storeData = storeSnap.data?.data() ?? {};
                      final storeName = localStoreName.isNotEmpty ? localStoreName : (storeData['storeName'] ?? storeData['name'] ?? '').toString();
                      final sellerName = localSellerName.isNotEmpty ? localSellerName : (storeData['ownerName'] ?? storeData['name'] ?? '').toString();
                      final category = localCategory.isNotEmpty ? localCategory : (storeData['category'] ?? '').toString();
                      final imageUrl = localImageUrl.isNotEmpty ? localImageUrl : (storeData['imageUrl'] ?? storeData['profilePic'] ?? '').toString();

                      return buildTile(
                        storeName: storeName,
                        sellerName: sellerName,
                        category: category,
                        imageUrl: imageUrl,
                      );
                    },
                  );
                }

                return buildTile(
                  storeName: localStoreName,
                  sellerName: localSellerName,
                  category: localCategory,
                  imageUrl: localImageUrl,
                );
              },
            );
          },
        ),
      ),
    );
  }
}
