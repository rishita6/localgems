// lib/s_profilep.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'edit_seller_profile.dart';
import 'login_page.dart';
import 's_inventoryp.dart';
import 'customer_product_page.dart';
import 'chatpage.dart';
import 'location_page.dart'; // to open map when pressing 'Show on Map'

class s_profilep extends StatefulWidget {
  final String? sellerId;
  const s_profilep({super.key, this.sellerId});

  @override
  State<s_profilep> createState() => _s_profilepState();
}

class _s_profilepState extends State<s_profilep> {
  bool _isFavorite = false;
  String? _sellerName, _sellerCategory, _sellerImage;

  // theme colors
  static const bgBlue = Color(0xFFD0E3FF);
  static const accentPink = Color(0xFFEF3167);
  static const cardWhite = Color(0xFFFFFFFF);
  static const textDark = Color(0xFF172032);
  static const textSoft = Color(0xFF6B7280);

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

  // ----------------- helpers: parse lat/lng safely -----------------
  double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  /// Tries to read lat/lng from location map or top-level fields
  Map<String, double>? _readLatLngFromData(Map<String, dynamic>? data) {
    if (data == null) return null;
    final loc = data['location'];
    if (loc is Map) {
      final lat = _parseDouble(loc['lat']);
      final lng = _parseDouble(loc['lng']);
      if (lat != null && lng != null) return {'lat': lat, 'lng': lng};
    }
    // fallback: top-level lat/lng
    final latRoot = _parseDouble(data['lat']);
    final lngRoot = _parseDouble(data['lng']);
    if (latRoot != null && lngRoot != null) return {'lat': latRoot, 'lng': lngRoot};
    return null;
  }

  /// Try to open seller on map. If `data` doesn't include location, fetch the user doc.
  Future<void> _openSellerOnMap({required String sellerId, Map<String, dynamic>? data}) async {
    try {
      // try data first
      Map<String, double>? latlng = _readLatLngFromData(data);
      if (latlng == null) {
        // fetch the seller doc from firestore
        final doc = await FirebaseFirestore.instance.collection('users').doc(sellerId).get();
        final d = doc.data() as Map<String, dynamic>?;
        latlng = _readLatLngFromData(d);
      }

      if (latlng != null) {
        final lat = latlng['lat']!;
        final lng = latlng['lng']!;
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => LocationPage(mode: 'find', initialLat: lat, initialLng: lng)),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seller has not set a location')));
      }
    } catch (e) {
      debugPrint('openSellerOnMap error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to open map for seller')));
    }
  }

  // ----------------- Reviews: submit and recompute -----------------
  Future<void> _submitReview({
    required String sellerId,
    required String userId,
    required double rating,
    required String comment,
  }) async {
    final reviewRef = FirebaseFirestore.instance
        .collection('users')
        .doc(sellerId)
        .collection('reviews')
        .doc(userId); // one review per user

    await reviewRef.set({
      'userId': userId,
      'rating': rating,
      'comment': comment,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // recompute avg
    final reviewsSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(sellerId)
        .collection('reviews')
        .get();

    if (reviewsSnap.docs.isNotEmpty) {
      double sum = 0;
      for (final d in reviewsSnap.docs) {
        final r = d['rating'];
        sum += (r is num) ? r.toDouble() : double.tryParse(r?.toString() ?? '0') ?? 0;
      }
      final avg = sum / reviewsSnap.docs.length;
      await FirebaseFirestore.instance.collection('users').doc(sellerId).update({
        'avgRating': avg,
        'totalReviews': reviewsSnap.docs.length,
      });
    }
  }

  // show reviews modal
Future<void> _showReviewsModal(String sellerId) async {
  final me = FirebaseAuth.instance.currentUser?.uid;
  // Fetch existing review (if any) before opening modal so we can prefill
  double initialRating = 5.0;
  final TextEditingController controller = TextEditingController();

  if (me != null) {
    try {
      final existing = await FirebaseFirestore.instance
          .collection('users')
          .doc(sellerId)
          .collection('reviews')
          .doc(me)
          .get();
      if (existing.exists) {
        final data = existing.data();
        final r = data?['rating'];
        final c = data?['comment'];
        if (r != null) {
          initialRating = (r is num) ? r.toDouble() : double.tryParse(r.toString()) ?? 5.0;
        }
        if (c != null) {
          controller.text = c.toString();
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch existing review: $e');
    }
  }

  final isCustomer = me != null && me != sellerId;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      // use StatefulBuilder inside modal so local UI updates are immediate
      return StatefulBuilder(
        builder: (context, setModalState) {
          double rating = initialRating;

          return DraggableScrollableSheet(
            initialChildSize: 0.75,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            builder: (_, controllerScroll) {
              return Container(
                decoration: const BoxDecoration(
                  color: cardWhite,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Expanded(child: Text('Customer Reviews', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                        StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance.collection('users').doc(sellerId).snapshots(),
                          builder: (c, s) {
                            final doc = s.data;
                            final avg = (doc?.data() as Map<String, dynamic>?)?['avgRating'];
                            final total = (doc?.data() as Map<String, dynamic>?)?['totalReviews'] ?? 0;
                            final avgD = (avg is num) ? avg.toDouble() : double.tryParse(avg?.toString() ?? '') ?? 0.0;
                            return Text('${avgD.toStringAsFixed(1)} • ${total ?? 0} reviews', style: const TextStyle(color: textSoft));
                          },
                        )
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(sellerId)
                            .collection('reviews')
                            .orderBy('createdAt', descending: true)
                            .snapshots(),
                        builder: (_, snap) {
                          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                          final docs = snap.data!.docs;
                          if (docs.isEmpty) return const Center(child: Text('No reviews yet'));
                          return ListView.separated(
                            controller: controllerScroll,
                            itemCount: docs.length,
                            separatorBuilder: (_, __) => const Divider(),
                            itemBuilder: (_, i) {
                              final r = docs[i].data() as Map<String, dynamic>;
                              final ratingVal = (r['rating'] is num) ? (r['rating'] as num).toDouble() : double.tryParse(r['rating']?.toString() ?? '0') ?? 0;
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: bgBlue,
                                  child: Text(
                                    (r['comment'] ?? '').toString().isNotEmpty
                                        ? (r['comment'].toString()[0].toUpperCase())
                                        : 'U',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: Row(children: [
                                  Row(children: List.generate(5, (j) => Icon(j < ratingVal ? Icons.star : Icons.star_border, color: Colors.amber, size: 16))),
                                  const SizedBox(width: 8),
                                  Text('${ratingVal.toStringAsFixed(1)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                ]),
                                subtitle: Text(r['comment'] ?? ''),
                              );
                            },
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 12),
                    if (isCustomer)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Leave a review', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),

                          // Stars (use setModalState so only modal updates)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (i) {
                              return IconButton(
                                icon: Icon(i < rating ? Icons.star : Icons.star_border, color: Colors.amber),
                                onPressed: () {
                                  setModalState(() => rating = i + 1.0);
                                },
                              );
                            }),
                          ),

                          // comment input — use controller we prefilled earlier
                          TextField(
                            controller: controller,
                            decoration: const InputDecoration(labelText: 'Write your comments (optional)'),
                          ),
                          const SizedBox(height: 8),

                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: accentPink),
                            onPressed: () async {
                              final meId = FirebaseAuth.instance.currentUser?.uid;
                              if (meId == null) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please login to review')));
                                return;
                              }
                              final comment = controller.text.trim();
                              // call your existing submit helper
                              await _submitReview(sellerId: sellerId, userId: meId, rating: rating, comment: comment);
                              if (!mounted) return;
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Review submitted')));
                            },
                            child: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Submit review',style: TextStyle(color: cardWhite, fontWeight: FontWeight.bold))),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            },
          );
        },
      );
    },
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

    return Scaffold(
      backgroundColor: bgBlue,
      // transparent app bar with back button added (keeps layout visually similar)
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: textDark,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
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

            String locationText = '';
            if (data['location'] is Map) {
              final loc = data['location'] as Map;
              locationText = (loc['address'] ?? '')?.toString() ?? '';
            } else {
              locationText = (data['address'] ?? '')?.toString() ?? '';
            }

            final priceRange = (data['priceRange'] ?? '').toString();
            final imageUrl = (data['profileImage'] ?? '').toString();
            final avgRatingRaw = data['avgRating'];
            final totalReviewsRaw = data['totalReviews'];

            final avgRating = (avgRatingRaw is num) ? avgRatingRaw.toDouble() : double.tryParse(avgRatingRaw?.toString() ?? '') ?? 0.0;
            final totalReviews = (totalReviewsRaw is num) ? (totalReviewsRaw as int) : int.tryParse(totalReviewsRaw?.toString() ?? '') ?? 0;

            _sellerName = name;
            _sellerCategory = category;
            _sellerImage = imageUrl;

            return Column(
              children: [
                // header top: single card with avatar & info
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: cardWhite, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)]),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: bgBlue,
                        backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                        child: imageUrl.isEmpty ? const Icon(Icons.storefront, size: 34, color: Colors.white) : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark)),
                          const SizedBox(height: 6),
                          if (category.isNotEmpty) Text(category, style: const TextStyle(color: accentPink, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          if (bio.isNotEmpty) Text(bio, style: const TextStyle(color: textSoft, fontSize: 13, height: 1.3)),
                        ]),
                      ),
                      // three-dot menu only for seller owner
                      Column(
                        children: [
                          if (uid == currentUid)
                            PopupMenuButton<String>(
                              icon: Icon(Icons.more_vert, color: textDark),
                              onSelected: (val) async {
                                if (val == "edit") {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const EditSellerProfile()));
                                } else if (val == "logout") {
                                  await FirebaseAuth.instance.signOut();
                                  if (!mounted) return;
                                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => login_page()));
                                }
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(value: "edit", child: Text("Edit Profile")),
                                const PopupMenuItem(value: "logout", child: Text("Logout")),
                              ],
                            )
                          else
                            IconButton(
                              icon: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border, color: _isFavorite ? accentPink : textSoft),
                              onPressed: () => _toggleFavorite(uid),
                            )
                        ],
                      )
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // message button (full width, white bg + pink border, improved style)
                if (uid != currentUid)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: accentPink, width: 2),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(28),
                          onTap: () => _openChatWithSeller(sellerId: uid, sellerName: name),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.chat, color: accentPink),
                                const SizedBox(width: 12),
                                Text('Message', style: TextStyle(color: accentPink, fontWeight: FontWeight.w700, fontSize: 16)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 12),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      // single info card: location / price / rating row
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: cardWhite, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('LOCATION', style: TextStyle(fontWeight: FontWeight.bold, color: textDark)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(child: Text(locationText.isNotEmpty ? locationText : 'Not set', style: const TextStyle(color: textDark))),
                                ElevatedButton(
                                  onPressed: () => _openSellerOnMap(sellerId: uid, data: data),
                                  style: ElevatedButton.styleFrom(backgroundColor: accentPink, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                                  child: const Text('see on map', style: TextStyle(color: Colors.white)),
                                )
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text('Price range', style: const TextStyle(fontWeight: FontWeight.bold, color: textDark)),
                            const SizedBox(height: 6),
                            Text(priceRange.isNotEmpty ? priceRange : '-', style: const TextStyle(color: textDark)),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text('Ratings', style: TextStyle(fontWeight: FontWeight.bold, color: textDark)),
                                const SizedBox(width: 12),
                                // stars for avg rating
                                Row(children: List.generate(5, (i) {
                                  return Icon(i < avgRating.round() ? Icons.star : Icons.star_border, color: Colors.amber, size: 18);
                                })),
                                const SizedBox(width: 8),
                                Text(avgRating > 0 ? avgRating.toStringAsFixed(1) : '-', style: const TextStyle(fontWeight: FontWeight.w600)),
                                const Spacer(),
                                // chevron => show all reviews
                                IconButton(
                                  icon: const Icon(Icons.chevron_right_rounded),
                                  onPressed: () => _showReviewsModal(uid),
                                )
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // See all products button
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
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      const Text("Top products / Best seller", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textDark)),
                      const SizedBox(height: 12),

                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('top_products').where('seller_id', isEqualTo: uid).snapshots(),
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
                                  border: Border.all(color: bgBlue),
                                ),
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

                      const SizedBox(height: 24),
                    ],
                  ),
                )
              ],
            );
          },
        ),
      ),
    );
  }
}
