// lib/orders_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

class OrdersPage extends StatelessWidget {
  final String uid;
  const OrdersPage({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('orders')
        .where('customerId', isEqualTo: uid);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Your Orders"),
        backgroundColor: Colors.pinkAccent,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.pink));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text("No orders yet.", style: TextStyle(color: Colors.black54)));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final data = docs[i].data();
              final total = (data['total'] ?? 0).toString();
              final status = (data['status'] ?? 'Processing').toString();
              final items = (data['items'] as List?) ?? [];

              return Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Colors.pinkAccent, width: 1),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  title: Text(
                    "Order #${docs[i].id}",
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  subtitle: Text(
                    "${items.length} items · ₹$total",
                    style: const TextStyle(color: Colors.black54),
                  ),
                  trailing: Chip(
                    label: Text(status, style: const TextStyle(color: Colors.white)),
                    backgroundColor: Colors.pinkAccent,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OrderDetailsPage(orderId: docs[i].id),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class OrderDetailsPage extends StatelessWidget {
  final String orderId;
  const OrderDetailsPage({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance.collection('orders').doc(orderId);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Order Details"),
        backgroundColor: Colors.pinkAccent,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: ref.snapshots(), // live updates from seller
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.pink));
          }
          final data = snap.data?.data();
          if (data == null) {
            return const Center(child: Text("Order not found", style: TextStyle(color: Colors.black54)));
          }

          final items = (data['items'] as List?) ?? [];

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
                  subtitle: Text("Status: ${data['status'] ?? 'Processing'}",
                      style: const TextStyle(color: Colors.black54)),
                  trailing: Text("₹${data['total'] ?? 0}",
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                ),
              ),

              const SizedBox(height: 20),
              const Text("Items", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 12),

              ...items.map((it) {
                final map = Map<String, dynamic>.from(it as Map);
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: map['imageUrl'] != null
                        ? CachedNetworkImage(
                            imageUrl: map['imageUrl'],
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            placeholder: (c, _) => const CircularProgressIndicator(strokeWidth: 2),
                            errorWidget: (c, _, __) => const Icon(Icons.image, size: 40),
                          )
                        : const Icon(Icons.shopping_bag, size: 40, color: Colors.pinkAccent),
                    title: Text(map['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("Qty: ${map['qty'] ?? 1} · ₹${map['price'] ?? 0}",
                        style: const TextStyle(color: Colors.black54)),
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
                      Text(data['address'] ?? "No address provided",
                          style: const TextStyle(color: Colors.black87)),
                      const SizedBox(height: 12),
                      const Text("Payment Method",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 6),
                      Text(data['paymentMethod'] ?? "N/A", style: const TextStyle(color: Colors.black87)),
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
