// // lib/orders_page.dart
// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:cached_network_image/cached_network_image.dart';

// const _pink = Color(0xFFef3167);
// const _blueBg = Color(0xFFD0E3FF);

// class OrdersPage extends StatelessWidget {
//   final String uid;
//   const OrdersPage({super.key, required this.uid});

//   @override
//   Widget build(BuildContext context) {
//     final query = FirebaseFirestore.instance
//         .collection('orders')
//         .where('customerId', isEqualTo: uid);

//     return Scaffold(
//       backgroundColor: _blueBg,
//       appBar: AppBar(
//         title: const Text("Your Orders"),
//         backgroundColor: _pink,
//         elevation: 0,
//       ),
//       body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
//         stream: query.orderBy('timestamp', descending: true).snapshots(),
//         builder: (context, snap) {
//           if (snap.connectionState == ConnectionState.waiting) {
//             return const Center(child: CircularProgressIndicator(color: _pink));
//           }
//           final docs = snap.data?.docs ?? [];
//           if (docs.isEmpty) {
//             return const Center(
//               child: Text(
//                 "No orders yet.",
//                 style: TextStyle(color: Colors.black54, fontSize: 16),
//               ),
//             );
//           }

//           return ListView.separated(
//             padding: const EdgeInsets.all(16),
//             itemCount: docs.length,
//             separatorBuilder: (_, __) => const SizedBox(height: 12),
//             itemBuilder: (context, i) {
//               final data = docs[i].data();
//               final id = docs[i].id;
//               final total = (data['total'] ?? data['totalAmount'] ?? 0).toString();
//               final status = (data['status'] ??
//                       data['orderStatus'] ??
//                       'Processing')
//                   .toString();
//               final items = (data['items'] as List?) ?? [];

//               return _OrderTile(
//                 orderId: id,
//                 itemCount: items.length,
//                 total: total,
//                 status: status,
//                 thumbUrl: items.isNotEmpty
//                     ? (items.first as Map)['imageUrl']?.toString()
//                     : null,
//                 onTap: () {
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(
//                       builder: (_) => OrderDetailsPage(orderId: id),
//                     ),
//                   );
//                 },
//               );
//             },
//           );
//         },
//       ),
//     );
//   }
// }

// class _OrderTile extends StatelessWidget {
//   final String orderId;
//   final int itemCount;
//   final String total;
//   final String status;
//   final String? thumbUrl;
//   final VoidCallback onTap;

//   const _OrderTile({
//     required this.orderId,
//     required this.itemCount,
//     required this.total,
//     required this.status,
//     required this.thumbUrl,
//     required this.onTap,
//   });

//   Color _statusColor(String s) {
//     final v = s.toLowerCase();
//     if (v.contains('deliver')) return Colors.green;
//     if (v.contains('ship')) return Colors.blue;
//     if (v.contains('cancel')) return Colors.redAccent;
//     if (v.contains('return')) return Colors.deepOrange;
//     return Colors.orange;
//     }

//   @override
//   Widget build(BuildContext context) {
//     final pillColor = _statusColor(status);

//     return InkWell(
//       onTap: onTap,
//       borderRadius: BorderRadius.circular(20),
//       child: Container(
//         decoration: BoxDecoration(
//           color: _pink,
//           borderRadius: BorderRadius.circular(20),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(0.18),
//               blurRadius: 10,
//               offset: const Offset(2, 6),
//             ),
//           ],
//         ),
//         padding: const EdgeInsets.all(14),
//         child: Row(
//           children: [
//             // thumbnail with glow circle
//             Container(
//               padding: const EdgeInsets.all(8),
//               decoration: BoxDecoration(
//                 color: Colors.white.withOpacity(0.18),
//                 shape: BoxShape.circle,
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.white.withOpacity(0.35),
//                     blurRadius: 14,
//                     spreadRadius: 2,
//                   )
//                 ],
//               ),
//               child: ClipRRect(
//                 borderRadius: BorderRadius.circular(18),
//                 child: thumbUrl != null
//                     ? CachedNetworkImage(
//                         imageUrl: thumbUrl!,
//                         width: 36,
//                         height: 36,
//                         fit: BoxFit.cover,
//                         placeholder: (_, __) =>
//                             const SizedBox(width: 36, height: 36, child: CircularProgressIndicator(strokeWidth: 2)),
//                         errorWidget: (_, __, ___) =>
//                             const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 28),
//                       )
//                     : const Icon(Icons.shopping_bag_outlined,
//                         color: Colors.white, size: 28),
//               ),
//             ),
//             const SizedBox(width: 12),

//             // middle text
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     "Order #$orderId",
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                     style: const TextStyle(
//                       color: Colors.white,
//                       fontWeight: FontWeight.w700,
//                       fontSize: 14,
//                     ),
//                   ),
//                   const SizedBox(height: 4),
//                   Text(
//                     "$itemCount items · ₹$total",
//                     style: const TextStyle(color: Colors.white70, fontSize: 12),
//                   ),
//                 ],
//               ),
//             ),

//             const SizedBox(width: 10),

//             // status pill
//             Container(
//               padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//               decoration: BoxDecoration(
//                 color: pillColor.withOpacity(0.18),
//                 borderRadius: BorderRadius.circular(20),
//               ),
//               child: Text(
//                 status,
//                 style: TextStyle(
//                   color: pillColor,
//                   fontWeight: FontWeight.w700,
//                   fontSize: 12,
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class OrderDetailsPage extends StatelessWidget {
//   final String orderId;
//   const OrderDetailsPage({super.key, required this.orderId});

//   @override
//   Widget build(BuildContext context) {
//     final ref = FirebaseFirestore.instance.collection('orders').doc(orderId);

//     return Scaffold(
//       backgroundColor: _blueBg,
//       appBar: AppBar(
//         title: const Text("Order Details"),
//         backgroundColor: _pink,
//         elevation: 0,
//       ),
//       body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
//         stream: ref.snapshots(),
//         builder: (context, snap) {
//           if (snap.connectionState == ConnectionState.waiting) {
//             return const Center(child: CircularProgressIndicator(color: _pink));
//           }
//           final data = snap.data?.data();
//           if (data == null) {
//             return const Center(
//               child: Text("Order not found", style: TextStyle(color: Colors.black54)),
//             );
//           }

//           final items = (data['items'] as List?) ?? [];
//           final status = (data['status'] ??
//                   data['orderStatus'] ??
//                   'Processing')
//               .toString();
//           final total = (data['total'] ?? data['totalAmount'] ?? 0).toString();
//           final address = (data['address'] ?? '').toString();
//           final paymentMethod = (data['paymentMethod'] ??
//                   data['paymentmethod'] ??
//                   'N/A')
//               .toString();

//           return ListView(
//             padding: const EdgeInsets.all(16),
//             children: [
//               // Summary pink card
//               Container(
//                 decoration: BoxDecoration(
//                   color: _pink,
//                   borderRadius: BorderRadius.circular(18),
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.black.withOpacity(0.18),
//                       blurRadius: 10,
//                       offset: const Offset(2, 6),
//                     ),
//                   ],
//                 ),
//                 padding: const EdgeInsets.all(16),
//                 child: Row(
//                   children: [
//                     // glow circle icon
//                     Container(
//                       padding: const EdgeInsets.all(10),
//                       decoration: BoxDecoration(
//                         color: Colors.white.withOpacity(0.18),
//                         shape: BoxShape.circle,
//                         boxShadow: [
//                           BoxShadow(
//                             color: Colors.white.withOpacity(0.35),
//                             blurRadius: 14,
//                             spreadRadius: 2,
//                           )
//                         ],
//                       ),
//                       child: const Icon(Icons.receipt_long,
//                           color: Colors.white, size: 26),
//                     ),
//                     const SizedBox(width: 12),
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text("Order #$orderId",
//                               maxLines: 1,
//                               overflow: TextOverflow.ellipsis,
//                               style: const TextStyle(
//                                   color: Colors.white,
//                                   fontWeight: FontWeight.w800,
//                                   fontSize: 16)),
//                           const SizedBox(height: 4),
//                           Text("₹$total · $status",
//                               style: const TextStyle(
//                                   color: Colors.white70, fontSize: 13)),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),

//               const SizedBox(height: 20),
//               const Text("Items",
//                   style: TextStyle(
//                       fontSize: 16,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.black87)),
//               const SizedBox(height: 12),

//               // item cards
//               ...items.map((it) {
//                 final map = Map<String, dynamic>.from(it as Map);
//                 final name = (map['name'] ?? '').toString();
//                 final qty = (map['qty'] ?? map['quantity'] ?? 1).toString();
//                 final price = (map['price'] ?? 0).toString();
//                 final img = map['imageUrl']?.toString();

//                 return Container(
//                   margin: const EdgeInsets.only(bottom: 12),
//                   decoration: BoxDecoration(
//                     color: Colors.white,
//                     borderRadius: BorderRadius.circular(14),
//                     boxShadow: [
//                       BoxShadow(
//                         color: Colors.black.withOpacity(0.1),
//                         blurRadius: 6,
//                         offset: const Offset(2, 3),
//                       ),
//                     ],
//                   ),
//                   child: ListTile(
//                     contentPadding: const EdgeInsets.all(12),
//                     leading: ClipRRect(
//                       borderRadius: BorderRadius.circular(10),
//                       child: img != null
//                           ? CachedNetworkImage(
//                               imageUrl: img,
//                               width: 54,
//                               height: 54,
//                               fit: BoxFit.cover,
//                               placeholder: (_, __) => const SizedBox(
//                                   width: 24,
//                                   height: 24,
//                                   child: CircularProgressIndicator(strokeWidth: 2)),
//                               errorWidget: (_, __, ___) =>
//                                   const Icon(Icons.image_not_supported, size: 36),
//                             )
//                           : const Icon(Icons.shopping_bag, size: 36, color: _pink),
//                     ),
//                     title: Text(name,
//                         style: const TextStyle(
//                             fontWeight: FontWeight.w700, fontSize: 14)),
//                     subtitle: Text("Qty: $qty · ₹$price",
//                         style: const TextStyle(color: Colors.black54)),
//                   ),
//                 );
//               }),

//               const SizedBox(height: 20),

//               // address & payment card
//               Container(
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.circular(14),
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.black.withOpacity(0.1),
//                       blurRadius: 6,
//                       offset: const Offset(2, 3),
//                     ),
//                   ],
//                 ),
//                 padding: const EdgeInsets.all(16),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const Text("Delivery Address",
//                         style:
//                             TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
//                     const SizedBox(height: 6),
//                     Text(
//                       address.isEmpty ? "No address provided" : address,
//                       style: const TextStyle(color: Colors.black87),
//                     ),
//                     const SizedBox(height: 14),
//                     const Text("Payment Method",
//                         style:
//                             TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
//                     const SizedBox(height: 6),
//                     Text(paymentMethod,
//                         style: const TextStyle(color: Colors.black87)),
//                   ],
//                 ),
//               ),
//             ],
//           );
//         },
//       ),
//     );
//   }
// }
