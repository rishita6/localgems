import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class s_profilep extends StatelessWidget {
  const s_profilep({super.key});

  @override
  Widget build(BuildContext context) {
    final String uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF2B1B17), // dark background
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text("Profile not found", style: TextStyle(color: Colors.white)),
            );
          }

          final user = snapshot.data!;
          final name = user['businessName'] ?? 'Business Name';
          final category = user['category'] ?? 'Category';
          final bio = user['description'] ?? 'No bio yet';
          final location = user['location'] ?? '';
          final priceRange = user['priceRange'] ?? '';
          final imageUrl = user['profileImage'] ?? '';

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: profile image + name/category/bio + edit/logout
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 35,
                        backgroundColor: Colors.white,
                        backgroundImage: imageUrl.isNotEmpty
                            ? NetworkImage(imageUrl)
                            : const AssetImage('lib/assets/placeholder.png')
                                as ImageProvider,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold)),
                            Text(category,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 14)),
                            const SizedBox(height: 4),
                            Text(bio,
                                style: const TextStyle(
                                    color: Colors.white60, fontSize: 13)),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.white),
                            onPressed: () {
                              Navigator.pushNamed(context, '/edit_profile');
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.logout, color: Colors.white),
                            onPressed: () {
                              FirebaseAuth.instance.signOut();
                              Navigator.pushReplacementNamed(context, '/login');
                            },
                          ),
                        ],
                      )
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Message button
                  Center(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/message_page');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF72634),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40, vertical: 12),
                      ),
                      child: const Text('Message',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),

                  const Divider(color: Colors.white30, height: 32),

                  // Location & price
                  Text("LOCATION", style: _sectionTitleStyle()),
                  Text(location, style: _sectionValueStyle()),

                  const SizedBox(height: 12),
                  Text("Price range", style: _sectionTitleStyle()),
                  Text(priceRange, style: _sectionValueStyle()),

                  const SizedBox(height: 20),

                  // Top products / best seller
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Top products / Best seller",
                          style: _sectionTitleStyle()),
                      IconButton(
                        icon: const Icon(Icons.add_circle,
                            color: Colors.white, size: 28),
                        onPressed: () {
                          Navigator.pushNamed(context, '/add_product');
                        },
                      )
                    ],
                  ),

                  // Display products in grid
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .collection('products')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }
                      if (snapshot.data!.docs.isEmpty) {
                        return const Text("No products yet",
                            style: TextStyle(color: Colors.white70));
                      }

                      final products = snapshot.data!.docs;

                      return GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3, // 3 items per row
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 0.8,
                        ),
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          final data =
                              products[index].data() as Map<String, dynamic>;
                          return GestureDetector(
                            onTap: () {
                              // Optional: open product details
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(8),
                                          topRight: Radius.circular(8)),
                                      child: data['image'] != null
                                          ? Image.network(
                                              data['image'],
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                            )
                                          : Container(
                                              color: Colors.grey[800],
                                              child: const Icon(Icons.image,
                                                  color: Colors.white54),
                                            ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(4.0),
                                    child: Text(
                                      data['name'] ?? '',
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  TextStyle _sectionTitleStyle() {
    return const TextStyle(
        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16);
  }

  TextStyle _sectionValueStyle() {
    return const TextStyle(color: Colors.white70, fontSize: 14);
  }
}
