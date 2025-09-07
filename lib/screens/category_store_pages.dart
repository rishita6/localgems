import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 's_profilep.dart';
import 'customer_scaffold.dart'; // reuse pastel colors

class CategoryStoresPage extends StatelessWidget {
  final String category;
  const CategoryStoresPage({super.key, required this.category});

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
        title: Text(
          category,
          style: const TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'Seller')
            .where('category', isEqualTo: category)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No stores in this category yet",
                style: TextStyle(color: AppColors.textSoft),
              ),
            );
          }

          final stores = snapshot.data!.docs;
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: stores.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final doc = stores[i];
              final data = doc.data() as Map<String, dynamic>;
              final uid = doc.id;
              final name = (data['businessName'] ?? 'Store').toString();
              final dp = (data['profileImage'] ?? '').toString();
              final city = (data['location'] ?? '').toString();
              final cat = (data['category'] ?? '').toString();

              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => s_profilep(sellerId: uid),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 6,
                        offset: Offset(2, 3),
                      ),
                    ],
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.bg,
                      backgroundImage: dp.isNotEmpty
                          ? NetworkImage(dp)
                          : const AssetImage('./lib/assets/placeholder.png')
                              as ImageProvider,
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      [cat, city].where((e) => e.isNotEmpty).join(" • "),
                      style: const TextStyle(color: AppColors.textSoft),
                    ),
                    trailing: const Icon(Icons.chevron_right,
                        color: AppColors.accent),
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
