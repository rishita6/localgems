import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 's_chatp.dart';
import 's_inventoryp.dart';
import 's_profilep.dart';
import 's_dashboard.dart';
import 'seller_orders_page.dart';

class SellerHomePage extends StatelessWidget {
  const SellerHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD0E3FF), // 🔵 Blue background
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// Welcome Text
              const Text(
                'Welcome Seller!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Montserrat',
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Manage your store, products, and chats all in one place.',
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'Poppins',
                  color: Colors.black.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 18),

              /// Smaller Tiles in Grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.2,
                children: [
                  _pinkTile(
                    context,
                    icon: Icons.dashboard_rounded,
                    title: 'Dashboard',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const s_dashboard()),
                      );
                    },
                  ),
                  _pinkTile(
                    context,
                    icon: Icons.inventory_2_rounded,
                    title: 'Inventory',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => s_inventoryp(
                            sellerId: FirebaseAuth.instance.currentUser!.uid,
                          ),
                        ),
                      );
                    },
                  ),
                  _pinkTile(
                    context,
                    icon: Icons.shopping_bag_rounded,
                    title: 'Orders',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => SellerOrdersPage()),
                      );
                    },
                  ),
                  _pinkTile(
                    context,
                    icon: Icons.chat_bubble_rounded,
                    title: 'Chats',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const s_chatp()),
                      );
                    },
                  ),
                  _pinkTile(
                    context,
                    icon: Icons.person_pin_rounded,
                    title: 'Profile',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => s_profilep()),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Pink Tile with Floating Icon Style
  Widget _pinkTile(BuildContext context,
      {required IconData icon,
      required String title,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 248, 240, 243), // 💖 Pink tile
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(2, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            /// Icon Circle with light bg + soft shadow
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 231, 81, 124).withOpacity(0.9), // lighter circle bg
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.1),
                    blurRadius: 8,
                    spreadRadius: 2,
                    offset: const Offset(2, 4),
                  ),
                ],
              ),
              child: Icon(icon, size: 24, color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'Montserrat',
                color: Color.fromARGB(255, 16, 16, 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
