import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 's_chatp.dart';
import 's_inventoryp.dart';
import 's_profilep.dart';
import 's_dashboard.dart';

class SellerHomePage extends StatelessWidget {
  const SellerHomePage({super.key});
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Sunset background
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(255, 243, 154, 95),
              Color.fromARGB(255, 235, 77, 4),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'Welcome Seller!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4A148C),
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _sellerTile(
                        context,
                        icon: Icons.dashboard,
                        title: 'Dashboard',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const s_dashboard(),
                            ),
                          );
                        },
                      ),
                      _sellerTile(
                        context,
                        icon: Icons.store,
                        title: 'Inventory',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              
                               builder: (_) => s_inventoryp(sellerId: FirebaseAuth.instance.currentUser!.uid),
                            ),
                          );
                        },
                      ),
                      _sellerTile(
                        context,
                        icon: Icons.chat,
                        title: 'Chats',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const s_chatp()),
                          );
                        },
                      ),
                      _sellerTile(
                        context,
                        icon: Icons.person,
                        title: 'Profile',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => s_profilep(
                               
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sellerTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 14,
        ),
        leading: Icon(icon, color: Color(0xFFFFB200), size: 30),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'Poppins',
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
