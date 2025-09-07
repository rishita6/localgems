// lib/customer_profile_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'OrdersPage.dart';
import 'favorites_page.dart';
import 'addresses_page.dart';
import 'payments_page.dart';
import 'help_page.dart';

/// Local palette class
class _Palette {
  static const blueBg = Color(0xFFD0E3FF);
  static const pink = Color(0xFFEF3167);
  static const card = Color(0xFFFFFFFF);
  static const textDark = Color(0xFF222222);
  static const textSoft = Color(0xFF6B7280);
}

class CustomerProfilePage extends StatefulWidget {
  final String uid;
  const CustomerProfilePage({super.key, required this.uid});

  @override
  State<CustomerProfilePage> createState() => _CustomerProfilePageState();
}

class _CustomerProfilePageState extends State<CustomerProfilePage> {
  String? _name;
  String? _email;
  String? _photo;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomer();
  }

  Future<void> _loadCustomer() async {
    try {
      final snap =
          await FirebaseFirestore.instance.collection('users').doc(widget.uid).get();
      final data = snap.data() ?? {};
      setState(() {
        _name = (data['businessName'] ?? data['name'] ?? 'Guest').toString();
        _email = (data['email'] ?? '').toString();
        _photo = (data['profileImage'] ?? '').toString();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/login');
  }

  Future<void> _openEditProfile() async {
    // Navigate to the edit screen and refresh if user saved changes
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          uid: widget.uid,
          initialName: _name ?? '',
          initialEmail: _email ?? '',
        ),
      ),
    );

    if (result == true) {
      // reload user after successful save
      await _loadCustomer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Palette.blueBg,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _Palette.pink))
            : RefreshIndicator(
                color: _Palette.pink,
                onRefresh: _loadCustomer,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Header card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _Palette.card,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 36,
                              backgroundColor: _Palette.blueBg,
                              backgroundImage: (_photo != null && _photo!.isNotEmpty)
                                  ? NetworkImage(_photo!)
                                  : null,
                              child: (_photo == null || _photo!.isEmpty)
                                  ? Text(
                                      (_name ?? 'G')[0].toUpperCase(),
                                      style: const TextStyle(
                                          fontSize: 26, color: Colors.white),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Hello,',
                                      style: GoogleFonts.poppins(
                                          color: _Palette.textSoft)),
                                  const SizedBox(height: 4),
                                  Text(
                                    _name ?? 'Guest',
                                    style: GoogleFonts.poppins(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: _Palette.textDark),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _email ?? '',
                                    style: GoogleFonts.poppins(
                                        fontSize: 13, color: _Palette.textSoft),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, color: _Palette.textDark),
                              onSelected: (value) async {
                                if (value == 'edit') {
                                  await _openEditProfile();
                                } else if (value == 'logout') {
                                  await _logout();
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(value: 'edit', child: Text('Edit Profile')),
                                PopupMenuItem(value: 'logout', child: Text('Logout')),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Quick actions
                      Row(
                        children: [
                          _QuickAction(
                            icon: Icons.shopping_bag_rounded,
                            title: 'Orders',
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => OrdersPage(uid: widget.uid))),
                          ),
                          const SizedBox(width: 12),
                          _QuickAction(
                            icon: Icons.favorite_rounded,
                            title: 'Stores',
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => FavoriteStoresPage(uid: widget.uid))),
                          ),
                          const SizedBox(width: 12),
                          _QuickAction(
                            icon: Icons.location_on_rounded,
                            title: 'Addresses',
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => AddressesPage(uid: widget.uid))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _QuickAction(
                            icon: Icons.credit_card_rounded,
                            title: 'Payments',
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => PaymentsPage(uid: widget.uid))),
                          ),
                          const SizedBox(width: 12),
                          _QuickAction(
                            icon: Icons.help_outline,
                            title: 'Help',
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => HelpPage(uid: widget.uid))),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(child: SizedBox()),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: _Palette.card,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: _Palette.pink.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: _Palette.pink, size: 20),
                ),
                const SizedBox(height: 8),
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, color: _Palette.textDark)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------
// Edit profile screen
// ------------------------
class EditProfileScreen extends StatefulWidget {
  final String uid;
  final String initialName;
  final String initialEmail;

  const EditProfileScreen({super.key, required this.uid, required this.initialName, required this.initialEmail});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(text: widget.initialName);
  late final TextEditingController _email = TextEditingController(text: widget.initialEmail);
  bool _saving = false;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    try {
      setState(() => _saving = true);
      await FirebaseFirestore.instance.collection('users').doc(widget.uid).set({
        'name': _name.text.trim(),
        'email': _email.text.trim(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pop(context, true); // indicate success
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: _Palette.pink,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: ListView(
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter email';
                  final email = v.trim();
                  if (!RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$").hasMatch(email)) return 'Invalid email';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(backgroundColor: _Palette.pink),
                child: _saving
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
