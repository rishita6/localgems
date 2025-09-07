import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
                      // later: open location picker
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
