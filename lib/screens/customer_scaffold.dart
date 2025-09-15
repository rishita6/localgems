// lib/customer_scaffold.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'addToCart.dart';
import 'favorites_page.dart';

/// App colors (Blue + Pink theme — single place to tweak)
class AppColors {
  // Primary page background (soft blue)
  static const bg = Color(0xFFD0E3FF);

  // Primary accent (pink)
  static const accent = Color(0xFFEF3167);

  // Cream card background used across UI
  static const card = Color(0xFFFFFBF7);

  // Text colors
  static const textDark = Color(0xFF222222);
  static const textSoft = Color(0xFF6B7280);

  // White alias for contrast on colored bars
  static const white = Colors.white;
}

/// A common scaffold for all customer pages
class CustomerScaffold extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onNavTap;
  final Widget body;

  /// Optional: set of page indexes where AppBar should be hidden.
  final Set<int> hideAppBarForIndexes;

  /// Optional: set of page indexes where BottomNavigationBar should be hidden.
  final Set<int> hideBottomNavForIndexes;

  /// Optional: override location label
  final String locationLabel;

  const CustomerScaffold({
    super.key,
    required this.currentIndex,
    required this.onNavTap,
    required this.body,
    this.hideAppBarForIndexes = const {},
    this.hideBottomNavForIndexes = const {},
    this.locationLabel = 'Your Location',
  });

  // helper: fetch saved addresses (labels only) for the signed-in user
  Future<List<Map<String, dynamic>>> _fetchSavedAddresses() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('addresses')
        .orderBy('createdAt', descending: true)
        .get();

    return snap.docs.map((d) {
      final data = d.data();
      return {
        'id': d.id,
        'label': (data['label'] ?? 'Address').toString(),
        // keep a short preview (not full address) if you stored `fullAddress` or `line1`
        'preview': (data['label'] ?? data['fullAddress'] ?? data['line1'] ?? '').toString(),
        'lat': data['lat'],
        'lng': data['lng'],
      };
    }).toList();
  }

  // show address picker bottom sheet (labels only)
  Future<void> _showAddressPicker(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      // Ask user to login
      showModalBottomSheet(
        context: context,
        builder: (ctx) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Please login to select a saved address', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    // Optionally navigate to login screen here
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                  child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('OK', style: TextStyle(color: AppColors.white))),
                )
              ]),
            ),
          );
        },
      );
      return;
    }

    // Fetch addresses once
    final addresses = await _fetchSavedAddresses();

    await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4)),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('Select address',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (addresses.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        const Text('No saved addresses found.'),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add_location_alt),
                          label: const Text('Add from map'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            // user can open LocationPage from wherever; we simply close sheet
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: addresses.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (c, i) {
                        final a = addresses[i];
                        final label = a['label'] ?? 'Address';
                        final preview = a['preview'] ?? '';
                        return ListTile(
                          title: Text(label,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          subtitle: preview.isNotEmpty ? Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis) : null,
                          leading: const Icon(Icons.place_outlined, color: AppColors.accent),
                          onTap: () {
                            Navigator.pop(ctx, a['id'] as String?);
                            // show short feedback
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Selected: $label')),
                            );
                          },
                          trailing: IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () {
                              // open edit address flow: we don't change file names here
                              Navigator.pop(ctx);
                              // developer note: navigate to your EditAddressPage here
                            },
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final showAppBar = !hideAppBarForIndexes.contains(currentIndex);
    final showBottomNav = !hideBottomNavForIndexes.contains(currentIndex);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: showAppBar
          ? AppBar(
              backgroundColor: AppColors.accent,
              elevation: 1,
              title: Row(
                children: [
                  const Icon(Icons.location_on, color: AppColors.white, size: 20),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      // OPEN saved address picker (labels-only, no full address shown)
                      _showAddressPicker(context);
                    },
                    child: Row(
                      children: [
                        Text(
                          locationLabel,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_drop_down, color: AppColors.white),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.favorite_border, color: AppColors.white),
                  onPressed: () {
                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    if (uid != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FavoriteStoresPage(uid: uid),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Please login first")),
                      );
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.shopping_cart, color: AppColors.white),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddToCart(),
                      ),
                    );
                  },
                ),
              ],
            )
          : null,
      body: body,
      bottomNavigationBar: showBottomNav
          ? BottomNavigationBar(
              currentIndex: currentIndex,
              onTap: onNavTap,
              backgroundColor: AppColors.card,
              selectedItemColor: AppColors.accent,
              unselectedItemColor: AppColors.textSoft,
              type: BottomNavigationBarType.fixed,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
                BottomNavigationBarItem(icon: Icon(Icons.search), label: "Search"),
                BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: "Chat"),
                BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
              ],
            )
          : null,
    );
  }
}
