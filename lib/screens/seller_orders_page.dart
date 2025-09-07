import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// ===============================
/// THEME (Blue + Pink)
/// ===============================
class _Palette {
  static const blueBg = Color(0xFFD0E3FF); // page background
  static const pink = Color(0xFFEF3167); // primary accent
  static const textDark = Color(0xFF222222);
  static const textSoft = Color(0xFF6B7280);
  static const white = Colors.white;

  // semantic
  static const green = Color(0xFF27AE60);
  static const blue = Color(0xFF1F87FF);
  static const orange = Color(0xFFFF8F00);
  static const red = Color(0xFFE53935);
  static const grey = Color(0xFF9E9E9E);
}

/// ===============================================================
/// SELLER ORDERS PAGE
/// ===============================================================
class SellerOrdersPage extends StatelessWidget {
  SellerOrdersPage({super.key});

  static const List<String> _statuses = <String>[
    'placed',
    'in_transit',
    'delivered',
    'delayed',
    'cancelled',
  ];

  @override
  Widget build(BuildContext context) {
    final sellerUid = FirebaseAuth.instance.currentUser?.uid;

    return DefaultTabController(
      length: _statuses.length,
      child: Scaffold(
        backgroundColor: _Palette.blueBg,
        appBar: AppBar(
          backgroundColor: _Palette.pink,
          elevation: 1,
          title: const Text(
            'Manage Orders',
            style: TextStyle(
              color: Color.fromARGB(255, 254, 253, 253),
              fontWeight: FontWeight.w800,
            ),
          ),
          iconTheme:
              const IconThemeData(color: Color.fromARGB(255, 243, 241, 241)),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh, color: _Palette.textDark),
              onPressed: () => (context as Element).reassemble(),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: const Color.fromARGB(255, 244, 242, 242),
            indicatorWeight: 3,
            labelColor: const Color.fromARGB(255, 250, 249, 250),
            unselectedLabelColor: const Color.fromARGB(255, 12, 12, 12),
            tabs: _statuses
                .map((s) => Tab(text: s.replaceAll('_', ' ').toUpperCase()))
                .toList(),
          ),
        ),
        body: TabBarView(
          children: _statuses
              .map((status) => _OrdersTab(status: status, sellerUid: sellerUid))
              .toList(),
        ),
      ),
    );
  }
}

/// ===============================
/// SINGLE TAB
/// ===============================
class _OrdersTab extends StatefulWidget {
  const _OrdersTab({required this.status, required this.sellerUid});
  final String status;
  final String? sellerUid;

  @override
  State<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<_OrdersTab> {
  final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  Future<void> _refresh() async {
    await FirebaseFirestore.instance.collection('orders').limit(1).get();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if ((widget.sellerUid ?? '').isEmpty) {
      return const _EmptyView(
        icon: Icons.lock_outline,
        title: 'Please sign in to view orders',
      );
    }

    final query = FirebaseFirestore.instance
        .collection('orders')
        .where('orderStatus', isEqualTo: widget.status);

    return RefreshIndicator(
      color: _Palette.pink,
      onRefresh: _refresh,
      child: StreamBuilder<QuerySnapshot>(
        stream: query.orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _Palette.pink),
            );
          }
          if (snap.hasError) {
            return _EmptyView(
              icon: Icons.error_outline,
              title: 'Failed to load orders',
              subtitle: snap.error.toString(),
              subtitleColor: _Palette.red,
            );
          }

          final allDocs = snap.data?.docs ?? const <QueryDocumentSnapshot>[];

          final sellerDocs = allDocs.where((doc) {
            final data = (doc.data() as Map<String, dynamic>?) ?? {};
            final items = (data['items'] as List?) ?? const [];
            return items.any((e) {
              final m = (e as Map).cast<String, dynamic>();
              return (m['sellerId'] ?? m['seller_id']) == widget.sellerUid;
            });
          }).toList();

          if (sellerDocs.isEmpty) {
            return _EmptyView(
              icon: Icons.inbox_outlined,
              title: 'No ${widget.status.replaceAll('_', ' ')} orders yet',
              subtitle: 'Pull down to refresh',
              subtitleColor: _Palette.textSoft,
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
            itemCount: sellerDocs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final doc = sellerDocs[i];
              final data = (doc.data() as Map<String, dynamic>?) ?? {};

              final ts = data['createdAt'];
              final createdAt = ts is Timestamp ? ts.toDate() : DateTime.now();

              final items = (data['items'] as List?) ?? const [];
              final Map<String, dynamic> myItem = items
                  .cast<Map>()
                  .map((m) => m.cast<String, dynamic>())
                  .firstWhere(
                    (m) =>
                        (m['sellerId'] ?? m['seller_id']) == widget.sellerUid,
                    orElse: () => items.isNotEmpty
                        ? (items.first as Map).cast<String, dynamic>()
                        : <String, dynamic>{},
                  );

              final name = (myItem['name'] ?? 'Product').toString();
              final imageUrl = (myItem['imageUrl'] ?? '').toString();

              final totalRaw = data['totalAmount'] ?? 0;
              final total = (totalRaw is num)
                  ? totalRaw.toDouble()
                  : double.tryParse(totalRaw.toString()) ?? 0.0;

              final addr =
                  (data['address'] as Map?)?.cast<String, dynamic>() ?? {};
              final customer = (addr['label'] ?? addr['city'] ?? 'Customer')
                  .toString();

              final paymentStatus =
                  (data['paymentStatus'] ?? 'pending').toString();
              final paymentMethod =
                  (data['paymentMethod'] ?? 'cod').toString();

              return _OrderCard(
                orderId: doc.id,
                docData: data,
                title: name,
                imageUrl: imageUrl,
                subtitle:
                    'Placed on ${DateFormat.yMMMd().format(createdAt)}\nCustomer: $customer',
                amount: _money.format(total),
                status: widget.status,
                paymentStatus: paymentStatus,
                paymentMethod: paymentMethod,
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => OrderDetailsPage(
                      orderId: doc.id,
                      orderData: data,
                      mySellerId: widget.sellerUid!,
                    ),
                  ));
                },
                onActionChanged: (_) {},
              );
            },
          );
        },
      ),
    );
  }
}

/// ===============================
/// ORDER CARD (white card, now with actions)
/// ===============================
class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.orderId,
    required this.docData,
    required this.title,
    required this.imageUrl,
    required this.subtitle,
    required this.amount,
    required this.status,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.onTap,
    required this.onActionChanged,
  });

  final String orderId;
  final Map<String, dynamic> docData; // full order document data
  final String title;
  final String imageUrl;
  final String subtitle;
  final String amount;
  final String status;
  final String paymentStatus;
  final String paymentMethod;
  final VoidCallback onTap;
  final ValueChanged<String> onActionChanged;

  Color _statusColor(String s) {
    switch (s) {
      case 'placed':
        return _Palette.blue;
      case 'in_transit':
        return _Palette.pink;
      case 'delivered':
        return _Palette.green;
      case 'delayed':
        return _Palette.orange;
      case 'cancelled':
        return _Palette.grey;
      default:
        return _Palette.textSoft;
    }
  }

  Future<void> _changeStatus(BuildContext context, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update({'orderStatus': newStatus, 'updatedAt': FieldValue.serverTimestamp()});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order status updated to ${newStatus.replaceAll('_', ' ')}')),
      );
      onActionChanged(newStatus);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: \$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sColor = _statusColor(status);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _Palette.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _Palette.textSoft.withOpacity(0.2)),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    )
                  : const Icon(Icons.shopping_bag_outlined,
                      color: _Palette.textSoft, size: 40),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // title + status pill + actions
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: _Palette.textDark,
                          ),
                        ),
                      ),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: sColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status.replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: sColor,
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      // action menu
                      PopupMenuButton<String>(
                        tooltip: 'Change status',
                        onSelected: (s) => _changeStatus(context, s),
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'placed', child: Text('Placed')),
                          const PopupMenuItem(value: 'in_transit', child: Text('In Transit')),
                          const PopupMenuItem(value: 'delivered', child: Text('Delivered')),
                          const PopupMenuItem(value: 'delayed', child: Text('Delayed')),
                          const PopupMenuItem(value: 'cancelled', child: Text('Cancelled')),
                        ],
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6.0),
                          child: Icon(Icons.more_vert, size: 18, color: _Palette.textSoft),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _Palette.textSoft,
                      fontSize: 12.5,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        amount,
                        style: const TextStyle(
                          color: _Palette.pink,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: (paymentStatus == "paid"
                                  ? _Palette.green
                                  : _Palette.orange)
                              .withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          paymentStatus.toUpperCase(),
                          style: TextStyle(
                            color: paymentStatus == "paid"
                                ? _Palette.green
                                : _Palette.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ===============================
/// ORDER DETAILS PAGE
/// ===============================
class OrderDetailsPage extends StatelessWidget {
  const OrderDetailsPage({super.key, required this.orderId, required this.orderData, required this.mySellerId});

  final String orderId;
  final Map<String, dynamic> orderData;
  final String mySellerId;

  @override
  Widget build(BuildContext context) {
    final items = (orderData['items'] as List?) ?? [];
    final myItem = items
        .cast<Map>()
        .map((m) => m.cast<String, dynamic>())
        .firstWhere(
          (m) => (m['sellerId'] ?? m['seller_id']) == mySellerId,
          orElse: () => items.isNotEmpty ? (items.first as Map).cast<String, dynamic>() : <String, dynamic>{},
        );

    final imageUrl = (myItem['imageUrl'] ?? '').toString();
    final name = (myItem['name'] ?? 'Product').toString();
    final qty = (myItem['quantity'] ?? myItem['qty'] ?? 1).toString();

    final totalRaw = orderData['totalAmount'] ?? 0;
    final total = (totalRaw is num)
        ? totalRaw.toDouble()
        : double.tryParse(totalRaw.toString()) ?? 0.0;

    final addr = (orderData['address'] as Map?)?.cast<String, dynamic>() ?? {};
    final addressLines = <String>[];
    if (addr['label'] != null) addressLines.add(addr['label']);
    if (addr['line1'] != null) addressLines.add(addr['line1']);
    if (addr['city'] != null) addressLines.add(addr['city']);
    if (addr['pincode'] != null) addressLines.add((addr['pincode']).toString());

    final paymentMethod = (orderData['paymentMethod'] ?? 'cod').toString();
    final paymentStatus = (orderData['paymentStatus'] ?? 'pending').toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order details'),
        backgroundColor: _Palette.pink,
      ),
      backgroundColor: _Palette.blueBg,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              color: _Palette.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _Palette.textSoft.withOpacity(0.15)),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: imageUrl.isNotEmpty
                          ? Image.network(imageUrl, width: 80, height: 80, fit: BoxFit.cover)
                          : const Icon(Icons.shopping_bag_outlined, size: 80, color: _Palette.textSoft),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text('Quantity: \$qty', style: const TextStyle(color: _Palette.textSoft)),
                        ],
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Text('Total: ${NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(total)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _Palette.pink)),
                const SizedBox(height: 8),
                Text('Payment: ${paymentMethod.toUpperCase()} • ${paymentStatus.toUpperCase()}', style: const TextStyle(color: _Palette.textSoft)),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                const Text('Delivery address', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                if (addressLines.isNotEmpty)
                  Text(addressLines.join(', '), style: const TextStyle(color: _Palette.textSoft)),
                if (addressLines.isEmpty) Text('Address not provided', style: const TextStyle(color: _Palette.textSoft)),
                const SizedBox(height: 12),

                // allow seller to change status from details too
                const SizedBox(height: 8),
                const Text('Order actions', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: _Palette.pink),
                      onPressed: () async {
                        await FirebaseFirestore.instance.collection('orders').doc(orderId).update({'orderStatus': 'in_transit', 'updatedAt': FieldValue.serverTimestamp()});
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked in transit')));
                        }
                      },
                      child: const Text('Mark In Transit'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: _Palette.green),
                      onPressed: () async {
                        await FirebaseFirestore.instance.collection('orders').doc(orderId).update({'orderStatus': 'delivered', 'updatedAt': FieldValue.serverTimestamp()});
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked delivered')));
                        }
                      },
                      child: const Text('Mark Delivered'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: _Palette.orange),
                      onPressed: () async {
                        await FirebaseFirestore.instance.collection('orders').doc(orderId).update({'orderStatus': 'delayed', 'updatedAt': FieldValue.serverTimestamp()});
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked delayed')));
                        }
                      },
                      child: const Text('Mark Delayed'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: _Palette.red),
                      onPressed: () async {
                        await FirebaseFirestore.instance.collection('orders').doc(orderId).update({'orderStatus': 'cancelled', 'updatedAt': FieldValue.serverTimestamp()});
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked cancelled')));
                        }
                      },
                      child: const Text('Cancel Order'),
                    ),
                  ],
                ),

              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ===============================
/// EMPTY VIEW
/// ===============================
class _EmptyView extends StatelessWidget {
  const _EmptyView({
    required this.icon,
    required this.title,
    this.subtitle,
    this.subtitleColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? subtitleColor;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 100),
        Icon(icon, size: 72, color: _Palette.textSoft.withOpacity(0.6)),
        const SizedBox(height: 12),
        Center(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _Palette.textDark,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Center(
            child: Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: subtitleColor ?? _Palette.textSoft,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
