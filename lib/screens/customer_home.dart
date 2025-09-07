import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import 'customer_profile_page.dart';
import 'search_page.dart';
import 'category_store_pages.dart';
import 'product_detail_page.dart';
import 'customer_chatpage.dart';

import 'customer_scaffold.dart'; // ✅ our new common scaffold

class _Palette {
  // Dominant page background and soft card color to match other screens
  static const blueBg = Color(0xFFD0E3FF); // page background (soft blue)
  static const primaryBlue = Color(0xFF1F87FF); // primary accent (used most)
  static const pink = Color(0xFFEF3167); // secondary accent (used subtly)
  static const pinkSoft = Color(0xFFEF3167); // will be used with opacity where needed
  static const card = Color(0xFFFFFBF7); // cream card
  static const textDark = Color(0xFF222222);
  static const textSoft = Color(0xFF6B7280);
  static const white = Colors.white;
}

class CustomerHomePage extends StatefulWidget {
  const CustomerHomePage({super.key});

  @override
  State<CustomerHomePage> createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage> {
  static const List<String> _categories = [
    'Food & Beverages',
    'Clothing',
    'Accessories',
    'Handicrafts',
    'Home Decor',
    'Grocery',
    'Books',
    'Stationery',
    'Personal Care',
    'Grooming',
    'Other',
  ];

  int _selectedIndex = 0;
  late final String uid;

  @override
  void initState() {
    super.initState();
    uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  Future<String> _fetchName() async {
    if (uid.isEmpty) return 'Customer';
    final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = snap.data() ?? {};
    final raw = (data['name'] ?? 'Customer').toString();
    return raw.isEmpty ? 'Customer' : raw;
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _pages = [
      _HomeContent(fetchName: _fetchName),
      const search_page(),
      const CustomerChatPage1(),
      CustomerProfilePage(uid: uid),
    ];

    return CustomerScaffold(
  currentIndex: _selectedIndex,
  onNavTap: (i) => setState(() => _selectedIndex = i),
  body: _pages[_selectedIndex],
  hideAppBarForIndexes: {1, 2},       // hides AppBar on Search & Chat pages
     // hides bottom nav on Search & Chat pages
);
  }
}

// ==================== HOME CONTENT ====================

class _HomeContent extends StatelessWidget {
  final Future<String> Function() fetchName;
  const _HomeContent({required this.fetchName});

  static const _categories = _CustomerHomePageState._categories;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _Palette.blueBg,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 80),
        children: [
          // Greeting
          FutureBuilder<String>(
            future: fetchName(),
            builder: (context, snap) {
              final name = snap.data ?? 'Customer';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Hello $name 👋🏻",
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: _Palette.textDark,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // subtitle + subtle pink hint (very low opacity)
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          "Discover local gems near you.",
                          style: TextStyle(color: _Palette.textSoft, fontSize: 14),
                        ),
                      ),
                      // subtle decorative dot using pink at low opacity
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(left: 8),
                        decoration: BoxDecoration(
                          color: _Palette.pink.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 20),

          // Categories
          const _SectionHeader(title: "Categories"),
          const SizedBox(height: 12),

          GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: _categories.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, i) {
              final title = _categories[i];
              return _CategoryCard(
                title: title,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CategoryStoresPage(category: title),
                    ),
                  );
                },
              );
            },
          ),

          const SizedBox(height: 26),

          // Recommendations
          const _SectionHeader(title: "Recommended for you"),
          const SizedBox(height: 12),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('top_products').orderBy('createdAt', descending: true).limit(20).snapshots(),
            builder: (context, ss) {
              if (ss.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(color: _Palette.primaryBlue),
                  ),
                );
              }
              if (!ss.hasData || ss.data!.docs.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      "No recommendations yet.",
                      style: TextStyle(color: _Palette.textSoft),
                    ),
                  ),
                );
              }

              final items = ss.data!.docs;

              return MasonryGridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final doc = items[i];
                  final data = doc.data() as Map<String, dynamic>;

                  final name = (data['name'] ?? '').toString();
                  final image = (data['imageUrl'] ?? '').toString();
                  final sellerId = (data['seller_id'] ?? '').toString();
                  final product_id = (data['product_id'] ?? '').toString();

                  num? price;
                  final rawPrice = data['price'];
                  if (rawPrice is num) price = rawPrice;
                  if (rawPrice is String) {
                    final p = num.tryParse(rawPrice);
                    if (p != null) price = p;
                  }

                  return _ProductCard(
                    name: name,
                    imageUrl: image,
                    price: price,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProductDetailPage(
                            productId: product_id,
                            sellerId: sellerId,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

// ==================== UI COMPONENTS ====================

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: _Palette.textDark,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  const _CategoryCard({required this.title, required this.onTap});

  IconData _getCategoryIcon(String title) {
    switch (title) {
      case 'Food & Beverages':
        return Icons.fastfood;
      case 'Clothing':
        return Icons.checkroom;
      case 'Accessories':
        return Icons.watch;
      case 'Handicrafts':
        return Icons.handyman;
      case 'Home Decor':
        return Icons.home;
      case 'Grocery':
        return Icons.local_grocery_store;
      case 'Books':
        return Icons.book;
      case 'Stationery':
        return Icons.create;
      case 'Personal Care':
        return Icons.spa;
      case 'Grooming':
        return Icons.cut;
      default:
        return Icons.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(14),
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: _Palette.card,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 6,
                offset: Offset(2, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_getCategoryIcon(title), color: _Palette.primaryBlue, size: 28),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _Palette.textDark,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final String name;
  final String imageUrl;
  final num? price;
  final VoidCallback onTap;
  const _ProductCard({
    required this.name,
    required this.imageUrl,
    required this.price,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(14),
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: _Palette.card,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 6,
                offset: Offset(2, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        height: 140,
                        color: _Palette.blueBg,
                        alignment: Alignment.center,
                        child: Icon(Icons.image, color: _Palette.textSoft),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _Palette.textDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    if (price != null)
                      Text(
                        "₹${price!.toStringAsFixed(price! % 1 == 0 ? 0 : 2)}",
                        style: const TextStyle(
                          color: _Palette.primaryBlue, // use blue as the main accent for price
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
