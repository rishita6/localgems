// lib/orders_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chatpage.dart'; // opens chat with seller

class OrdersPage extends StatelessWidget {
  final String uid;
  const OrdersPage({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    // Primary live query — most of your code writes 'userId' on orders.
    final primaryQuery = FirebaseFirestore.instance
        .collection('orders')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Your Orders"),
        backgroundColor: const Color(0xFFEF3167),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: primaryQuery.snapshots(),
        builder: (context, snap) {
          // Show errors clearly (helps detect Firestore index / security failures).
          if (snap.hasError) {
            final err = snap.error;
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 12),
                    Text('Failed to load orders: $err', textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => OrdersPage(uid: uid))),
                      child: const Text('Retry'),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF3167)),
                    )
                  ],
                ),
              ),
            );
          }

          // While waiting show spinner
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFEF3167)));
          }

          final docs = snap.data?.docs ?? [];

          // If we got live results, show them.
          if (docs.isNotEmpty) {
            return _buildOrderList(context, docs);
          }

          // Primary query returned *no docs* — attempt fallback one-time fetch
          // for orders where the older field name 'customerId' might have been used.
          return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
            future: FirebaseFirestore.instance
                .collection('orders')
                .where('customerId', isEqualTo: uid)
                .orderBy('createdAt', descending: true)
                .get()
                .catchError((e) {
                  // swallow and return empty QuerySnapshot-like value via throwing to FutureBuilder
                  throw e;
                }),
            builder: (context, futSnap) {
              if (futSnap.hasError) {
                // Show fallback error so you can detect index/security issues
                return Center(child: Text('Failed to load orders (fallback): ${futSnap.error}'));
              }
              if (futSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFFEF3167)));
              }

              final fallbackDocs = futSnap.data?.docs ?? [];
              if (fallbackDocs.isNotEmpty) {
                return _buildOrderList(context, fallbackDocs);
              }

              // Nothing found — show empty state
              return const Center(child: Text("No orders yet.", style: TextStyle(color: Colors.black54)));
            },
          );
        },
      ),
    );
  }

  Widget _buildOrderList(BuildContext context, List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final data = docs[i].data();
        // be defensive: totalAmount or total
        final totalAmount = data['totalAmount'] ?? data['total'] ?? 0;
        final totalStr = totalAmount.toString();
        // status could be 'orderStatus' or 'status' or 'paymentStatus'
        final status = (data['orderStatus'] ?? data['status'] ?? data['paymentStatus'] ?? 'placed').toString();
        final items = (data['items'] as List?) ?? [];

        // Try to determine sellerId for chat:
        String? sellerId;
        if (data['sellerId'] != null) sellerId = data['sellerId']?.toString();
        if ((sellerId == null || sellerId.isEmpty) && items.isNotEmpty) {
          final first = items.first;
          if (first is Map) {
            sellerId = (first['sellerId'] ?? first['sellerUid'] ?? first['seller'])?.toString();
          }
        }

        // short txn display (if present)
        final txnRaw = (data['paymentId'] ?? data['txnId'] ?? data['paymentTransactionId']);
        final txnString = txnRaw?.toString() ?? '';

        return Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFEF3167), width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            child: Column(
              children: [
                // Use row with constrained right column to avoid pushing layout.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // left: order title / subtitle (flexible)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // title (may wrap to 2 lines)
                          Text(
                            "Order #${docs[i].id}",
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "${items.length} items · ₹$totalStr",
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // right: status chip + txn (constrained width)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 140),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Chip(
                            label: Text(status, style: const TextStyle(color: Colors.white)),
                            backgroundColor: const Color(0xFFEF3167),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                          ),
                          const SizedBox(height: 8),
                          if (txnString.isNotEmpty)
                            Text(
                              'Txn: ${_shorten(txnString)}',
                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                              textAlign: TextAlign.right,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Buttons: wrap so they stack on small widths instead of overflow
                Padding(
                  padding: const EdgeInsets.only(right: 8.0, left: 8.0, bottom: 10),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.start,
                    children: [
                      // Chat seller button - ensure white text
                      SizedBox(
                        height: 44,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text('Chat seller', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF3167),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            elevation: 2,
                          ),
                          onPressed: () async {
                            if (sellerId == null || sellerId.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seller information not available for this order')));
                              return;
                            }
                            final me = FirebaseAuth.instance.currentUser?.uid;
                            if (me == null) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please login to chat')));
                              return;
                            }

                            // fetch seller name/photo for nicer chat header (best-effort)
                            String sellerName = 'Seller';
                            String? sellerPhoto;
                            try {
                              final snap = await FirebaseFirestore.instance.collection('users').doc(sellerId).get();
                              final d = snap.data();
                              if (d != null) {
                                sellerName = (d['businessName'] ?? d['name'] ?? 'Seller').toString();
                                sellerPhoto = (d['profileImage'] ?? d['profilePhoto'] ?? '')?.toString();
                              }
                            } catch (_) {}

                            final chatId = _chatIdFor(me, sellerId);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatPage(
                                  chatId: chatId,
                                  otherUid: sellerId!,
                                  otherName: sellerName,
                                  otherPhoto: sellerPhoto,
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // Details button
                      SizedBox(
                        height: 44,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.receipt_long),
                          label: const Text('Details'),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                            side: const BorderSide(color: Color(0xFF6B7280)),
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            foregroundColor: const Color(0xFF6B7280),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OrderDetailsPage(orderId: docs[i].id),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _chatIdFor(String a, String b) => a.compareTo(b) < 0 ? '${a}_$b' : '${b}_$a';

  static String _shorten(String s, [int max = 18]) {
    if (s.length <= max) return s;
    return '${s.substring(0, max - 3)}...';
  }
}

class OrderDetailsPage extends StatelessWidget {
  final String orderId;
  const OrderDetailsPage({super.key, required this.orderId});

  String _addressText(dynamic addressField) {
    if (addressField == null) return "No address provided";

    if (addressField is String) return addressField;
    if (addressField is Map) {
      // try common map fields
      final label = addressField['label'] ?? '';
      final addr = addressField['address'] ?? '';
      final line1 = addressField['line1'] ?? '';
      final city = addressField['city'] ?? '';
      final pincode = addressField['pincode'] ?? '';
      final phone = addressField['phone'] ?? '';
      final parts = [label, addr, line1, city, pincode].where((p) => p != null && p.toString().trim().isNotEmpty).map((e) => e.toString()).toList();
      var result = parts.join(', ');
      if (phone != null && phone.toString().trim().isNotEmpty) result += '\nPhone: ${phone.toString()}';
      return result.isNotEmpty ? result : addressField.toString();
    }
    return addressField.toString();
  }

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance.collection('orders').doc(orderId);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Order Details"),
        backgroundColor: const Color(0xFFEF3167),
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: ref.snapshots(), // live updates
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFEF3167)));
          }

          final data = snap.data?.data();
          if (data == null) {
            return const Center(child: Text("Order not found", style: TextStyle(color: Colors.black54)));
          }

          final items = (data['items'] as List?) ?? [];
          // normalize: each item may use 'quantity' or 'qty'
          List<Map<String, dynamic>> normItems = items.map((it) {
            if (it is Map<String, dynamic>) return Map<String, dynamic>.from(it);
            if (it is Map) return Map<String, dynamic>.from(it as Map);
            return <String, dynamic>{};
          }).toList();

          final totalAmount = data['totalAmount'] ?? data['total'] ?? 0;
          final orderStatus = data['orderStatus'] ?? data['status'] ?? data['paymentStatus'] ?? 'placed';

          final addressField = data['address'] ?? data['deliveryAddress'] ?? data['shippingAddress'];

          final transactionId = (data['paymentId'] ?? data['txnId'] ?? data['paymentTransactionId'])?.toString() ?? '';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Order Summary
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 3,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text("Order #$orderId",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  subtitle: Text("Status: $orderStatus",
                      style: const TextStyle(color: Colors.black54)),
                  trailing: Text("₹$totalAmount",
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                ),
              ),

              const SizedBox(height: 20),
              const Text("Items", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 12),

              ...normItems.map((map) {
                final name = map['name'] ?? map['productName'] ?? '';
                final image = map['imageUrl'] ?? map['image'] ?? '';
                final qty = map['quantity'] ?? map['qty'] ?? 1;
                final price = map['price'] ?? map['unitPrice'] ?? 0;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: image != null && image.toString().isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: image.toString(),
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            placeholder: (c, _) => const SizedBox(width: 50, height: 50, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                            errorWidget: (c, _, __) => const Icon(Icons.image, size: 40),
                          )
                        : const Icon(Icons.shopping_bag, size: 40, color: Color(0xFFEF3167)),
                    title: Text(name.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("Qty: $qty · ₹$price", style: const TextStyle(color: Colors.black54)),
                  ),
                );
              }).toList(),

              const SizedBox(height: 20),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: Colors.pink[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Delivery Address",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 6),
                      Text(_addressText(addressField),
                          style: const TextStyle(color: Colors.black87)),
                      const SizedBox(height: 12),
                      const Text("Payment Method",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 6),
                      Text(data['paymentMethod'] ?? "N/A", style: const TextStyle(color: Colors.black87)),
                      const SizedBox(height: 12),
                      if (transactionId.isNotEmpty) ...[
                        const Text("Transaction ID", style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        SelectableText(transactionId, style: const TextStyle(color: Colors.black87)),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
