// lib/s_profilep.dart (UI tweaks only — logic untouched)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'edit_seller_profile.dart';
import 'login_page.dart';
import 's_inventoryp.dart';
import 'customer_product_page.dart';
import 'chatpage.dart';

class s_profilep extends StatefulWidget {
  final String? sellerId;
  const s_profilep({super.key, this.sellerId});

  @override
  State<s_profilep> createState() => _s_profilepState();
}

class _s_profilepState extends State<s_profilep> {
  bool _isFavorite = false;
  String? _sellerName, _sellerCategory, _sellerImage;

  @override
  void initState() {
    super.initState();
    _primeFavoriteState();
  }

  Future<void> _primeFavoriteState() async {
    final me = FirebaseAuth.instance.currentUser?.uid;
    final sellerId = widget.sellerId;
    if (me == null || sellerId == null || me == sellerId) return;

    final favDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(me)
        .collection('favorite_stores')
        .doc(sellerId)
        .get();
    if (mounted) setState(() => _isFavorite = favDoc.exists);
  }

  Future<void> _toggleFavorite(String sellerId) async {
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me == null) return;

    final favRef = FirebaseFirestore.instance
        .collection('users')
        .doc(me)
        .collection('favorite_stores')
        .doc(sellerId);

    if (_isFavorite) {
      await favRef.delete();
      setState(() => _isFavorite = false);
    } else {
      await favRef.set({
        'storeId': sellerId,
        'storeName': _sellerName,
        'category': _sellerCategory,
        'imageUrl': _sellerImage,
        'createdAt': FieldValue.serverTimestamp(),
      });
      setState(() => _isFavorite = true);
    }
  }

  String _chatIdFor(String a, String b) =>
      a.compareTo(b) < 0 ? '${a}_$b' : '${b}_$a';

  Future<void> _openChatWithSeller(
      {required String sellerId, required String sellerName}) async {
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me == null || sellerId == me) return;

    final chatId = _chatIdFor(me, sellerId);
    final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
    final chatSnap = await chatRef.get();

    if (!chatSnap.exists) {
      await chatRef.set({
        'participants': [me, sellerId],
        'lastMessage': '',
        'lastTimestamp': FieldValue.serverTimestamp(),
      });
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          chatId: chatId,
          otherUid: sellerId,
          otherName: sellerName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final uid = widget.sellerId ?? currentUid;

    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text("Not logged in", style: TextStyle(color: Colors.black))),
      );
    }

    const bgBlue = Color(0xFFD0E3FF);
    const accentPink = Color(0xFFEF3167);
    const cardWhite = Color(0xFFFFFFFF);
    const textDark = Color(0xFF172032);
    const textSoft = Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: bgBlue,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              color: Colors.transparent,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    color: textDark,
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  if (uid != currentUid)
                    IconButton(
                      icon: Icon(
                          _isFavorite ? Icons.favorite : Icons.favorite_border),
                      color: _isFavorite ? accentPink : textSoft,
                      onPressed: () => _toggleFavorite(uid),
                    ),
                  if (uid == currentUid)
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: textDark),
                      onSelected: (val) async {
                        if (val == "edit") {
                          Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const EditSellerProfile()));
                        } else if (val == "logout") {
                          await FirebaseAuth.instance.signOut();
                          if (!mounted) return;
                          Navigator.pushReplacement(
                              context, MaterialPageRoute(builder: (_) => login_page()));
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: "edit", child: Text("Edit Profile")),
                        const PopupMenuItem(value: "logout", child: Text("Logout")),
                      ],
                    ),
                ],
              ),
            ),

            Expanded(
              child: FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator(color: accentPink));
                  }
                  if (!snap.data!.exists) {
                    return const Center(child: Text("Profile not found", style: TextStyle(color: textSoft)));
                  }

                  final data = snap.data!.data() as Map<String, dynamic>;
                  final name = (data['businessName'] ?? 'Business').toString();
                  final category = (data['category'] ?? '').toString();
                  final bio = (data['description'] ?? '').toString();
                  final location = (data['location'] ?? '').toString();
                  final priceRange = (data['priceRange'] ?? '').toString();
                  final imageUrl = (data['profileImage'] ?? '').toString();

                  _sellerName = name;
                  _sellerCategory = category;
                  _sellerImage = imageUrl;

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardWhite,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 48,
                              backgroundImage: imageUrl.isNotEmpty
                                  ? NetworkImage(imageUrl)
                                  : const AssetImage('./lib/assets/placeholder.png') as ImageProvider,
                              backgroundColor: bgBlue,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: const TextStyle(color: textDark, fontSize: 20, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  if (category.isNotEmpty) Text(category, style: const TextStyle(color: accentPink, fontWeight: FontWeight.w600)),
                                  if (bio.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(bio, style: const TextStyle(color: textSoft)),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: cardWhite, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Location: $location", style: const TextStyle(color: textDark)),
                            const SizedBox(height: 6),
                            Text("Price Range: $priceRange", style: const TextStyle(color: textDark)),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // White message button with pink border, below price card
                      if (uid != currentUid)
                        Center(
                          child: OutlinedButton.icon(
                            onPressed: () => _openChatWithSeller(sellerId: uid, sellerName: name),
                            icon: const Icon(Icons.chat, color: accentPink),
                            label: const Text("Message", style: TextStyle(color: accentPink, fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: accentPink, width: 2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              backgroundColor: Colors.white,
                            ),
                          ),
                        ),

                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (uid == currentUid) {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => s_inventoryp(sellerId: uid)));
                            } else {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerProductsPage(sellerId: uid)));
                            }
                          },
                          icon: const Icon(Icons.grid_view, color: Colors.white),
                          label: const Text("See all products", style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentPink,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      const Text("Top Products", style: TextStyle(color: textDark, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),

                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('top_products')
                            .where('seller_id', isEqualTo: uid)
                            .snapshots(),
                        builder: (context, ss) {
                          if (!ss.hasData || ss.data!.docs.isEmpty) {
                            return Text("No top products yet", style: TextStyle(color: textSoft));
                          }
                          final items = ss.data!.docs;
                          return MasonryGridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: items.length,
                            itemBuilder: (context, i) {
                              final d = items[i].data() as Map<String, dynamic>;
                              return Container(
                                margin: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                    color: cardWhite,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
                                    border: Border.all(color: bgBlue)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if ((d['imageUrl'] ?? '').toString().isNotEmpty)
                                      ClipRRect(
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                        child: Image.network(d['imageUrl'], height: 120, width: double.infinity, fit: BoxFit.cover),
                                      ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(d['name'] ?? '', style: const TextStyle(color: textDark, fontWeight: FontWeight.bold)),
                                    )
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
