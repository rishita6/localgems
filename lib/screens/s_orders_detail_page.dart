// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:intl/intl.dart';

// class OrderDetailsPage extends StatelessWidget {
//   final String orderId;
//   const OrderDetailsPage({super.key, required this.orderId});

//   @override
//   Widget build(BuildContext context) {
//     final currency =
//         NumberFormat.currency(locale: 'en_IN', symbol: '₹');

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("Order Details"),
//         backgroundColor: const Color(0xFFD32F2F),
//       ),
//       body: FutureBuilder<DocumentSnapshot>(
//         future: FirebaseFirestore.instance
//             .collection('orders')
//             .doc(orderId)
//             .get(),
//         builder: (context, snap) {
//           if (snap.connectionState == ConnectionState.waiting) {
//             return const Center(child: CircularProgressIndicator());
//           }

//           if (!snap.hasData || !snap.data!.exists) {
//             return const Center(child: Text("Order not found"));
//           }

//           final data = snap.data!.data() as Map<String, dynamic>;
//           final items = (data['items'] ?? []) as List;
//           final address = (data['address'] ?? {}) as Map;
//           final total = (data['totalAmount'] ?? 0).toDouble();

//           return ListView(
//             padding: const EdgeInsets.all(16),
//             children: [
//               _buildCard(
//                 title: "Customer",
//                 children: [
//                   Text("Name: ${address['name'] ?? '-'}"),
//                   Text("City: ${address['city'] ?? '-'}"),
//                   Text("Phone: ${address['phone'] ?? '-'}"),
//                   Text("Pin: ${address['pincode'] ?? '-'}"),
//                 ],
//               ),
//               const SizedBox(height: 12),
//               _buildCard(
//                 title: "Order Info",
//                 children: [
//                   Text("Order ID: $orderId"),
//                   Text("Status: ${data['orderStatus'] ?? '-'}"),
//                   Text("Payment: ${data['paymentmethod'] ?? '-'}"),
//                   Text("Total: ${currency.format(total)}"),
//                 ],
//               ),
//               const SizedBox(height: 12),
//               const Text("Items",
//                   style: TextStyle(
//                       fontWeight: FontWeight.bold, fontSize: 16)),
//               const SizedBox(height: 6),
//               ...items.map((raw) {
//                 final item = raw as Map;
//                 return ListTile(
//                   leading: (item['imageUrl'] != null &&
//                           (item['imageUrl'] as String).isNotEmpty)
//                       ? Image.network(item['imageUrl'],
//                           width: 42, height: 42, fit: BoxFit.cover)
//                       : const Icon(Icons.inventory_2_outlined),
//                   title: Text(item['name'] ?? 'Unknown'),
//                   subtitle: Text(
//                       "Qty: ${item['quantity'] ?? 0}  •  ₹${item['price'] ?? "-"}"),
//                 );
//               }).toList(),
//             ],
//           );
//         },
//       ),
//     );
//   }

//   Widget _buildCard({required String title, required List<Widget> children}) {
//     return Card(
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
//       elevation: 2,
//       child: Padding(
//         padding: const EdgeInsets.all(12),
//         child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(title,
//                   style: const TextStyle(
//                       fontWeight: FontWeight.bold, fontSize: 16)),
//               const SizedBox(height: 8),
//               ...children,
//             ]),
//       ),
//     );
//   }
// }
