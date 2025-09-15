// lib/screens/s_dashboard.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Import seller orders/details page so we can navigate to order details
import 'seller_orders_page.dart';

class s_dashboard extends StatefulWidget {
  const s_dashboard({super.key});

  @override
  State<s_dashboard> createState() => _s_dashboardState();
}

class _s_dashboardState extends State<s_dashboard> {
  DateTimeRange? selectedRange;
  final sellerId = FirebaseAuth.instance.currentUser!.uid;

  int totalProducts = 0;
  int totalOrders = 0; // number of orders that include this seller's items
  double revenue = 0.0; // revenue for this seller (sum of their item subtotals)
  int newCustomers = 0;

  List<Map<String, dynamic>> recentOrders = [];
  List<Map<String, dynamic>> bestSellers = [];

  @override
  void initState() {
    super.initState();
    // Show current month analysis by default
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    selectedRange = DateTimeRange(start: startOfMonth, end: endOfMonth);
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    if (selectedRange == null) return;

    final start = selectedRange!.start;
    final end = selectedRange!.end;

    // Products
    final productSnap = await FirebaseFirestore.instance
        .collection('products')
        .where('sellerId', isEqualTo: sellerId)
        .get();
    totalProducts = productSnap.size;

    // Orders (fetch by createdAt range then filter locally for seller's items)
    Query ordersQuery = FirebaseFirestore.instance.collection('orders');

    // Use createdAt if present
    ordersQuery = ordersQuery
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('createdAt', descending: true);

    final orderSnap = await ordersQuery.get();

    // Reset counters
    revenue = 0.0;
    final buyers = <String>{};
    recentOrders = [];

    final Map<String, int> productCounts = {};
    int ordersWithSeller = 0;

    for (final doc in orderSnap.docs) {
      // SAFELY cast doc.data() to Map<String, dynamic>
      final rawData = doc.data();
      final data = (rawData is Map) ? Map<String, dynamic>.from(rawData.cast<String, dynamic>()) : <String, dynamic>{};

      final items = (data['items'] is List) ? List.from(data['items']) : <dynamic>[];

      // compute seller-specific subtotal for this order
      double sellerOrderSubtotal = 0.0;
      int sellerItemQtyTotal = 0;

      for (final raw in items) {
        final item = (raw is Map) ? Map<String, dynamic>.from(raw.cast<String, dynamic>()) : <String, dynamic>{};
        final itemSellerId = (item['sellerId'] ?? item['seller_id'])?.toString() ?? '';
        if (itemSellerId == sellerId) {
          // quantity and price fields may vary; try common keys
          final qtyField = item['quantity'] ?? item['qty'] ?? 1;
          final priceField = item['price'] ?? item['amount'] ?? item['total'] ?? 0;

          final q = (qtyField is num) ? qtyField.toInt() : int.tryParse(qtyField.toString()) ?? 1;
          final p = (priceField is num) ? priceField.toDouble() : double.tryParse(priceField.toString()) ?? 0.0;

          sellerOrderSubtotal += p * q;
          sellerItemQtyTotal += q;

          // best sellers counting by product name (fallback to productId)
          final prodName = (item['name'] ?? item['productName'] ?? item['productId'] ?? 'Unknown').toString();
          productCounts[prodName] = (productCounts[prodName] ?? 0) + q;
        }
      }

      if (sellerOrderSubtotal > 0.0) {
        // this order includes at least one item from this seller
        ordersWithSeller += 1;
        revenue += sellerOrderSubtotal;

        // customer id: try common keys
        final custIdRaw = data['userId'] ?? data['customer_id'] ?? data['customerId'] ?? data['user_id'];
        final custId = custIdRaw?.toString() ?? '';
        if (custId.isNotEmpty) buyers.add(custId);

        // createdAt fallback
        DateTime date = DateTime.now();
        final ts = data['createdAt'] ?? data['timestamp'];
        if (ts is Timestamp) {
          date = ts.toDate();
        } else if (ts is int) {
          date = DateTime.fromMillisecondsSinceEpoch(ts);
        }

        // push summary for recentOrders (keep order id so we can fetch full doc when tapping)
        recentOrders.add({
          'id': doc.id,
          'status': (data['orderStatus'] ?? '').toString(),
          'amount': sellerOrderSubtotal,
          'date': date,
        });
      }
    }

    totalOrders = ordersWithSeller;
    newCustomers = buyers.length;

    // keep only top 5 recent orders
    recentOrders.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
    if (recentOrders.length > 5) recentOrders = recentOrders.take(5).toList();

    // Best sellers (top 3 by qty)
    final sorted = productCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    bestSellers = sorted.take(3).map((e) => {'name': e.key, 'qty': e.value}).toList();

    if (mounted) setState(() {});
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2022),
      lastDate: DateTime.now(),
      initialDateRange: selectedRange,
    );
    if (picked != null) {
      setState(() => selectedRange = picked);
      await _fetchDashboardData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final rangeText = selectedRange == null
        ? "This Month"
        : "${DateFormat.yMMMd().format(selectedRange!.start)} → ${DateFormat.yMMMd().format(selectedRange!.end)}";

    return Scaffold(
      backgroundColor: const Color(0xFFD0E3FF), // blue
      appBar: AppBar(
        title: const Text('Seller Dashboard'),
        backgroundColor: const Color(0xFFef3167), // pink
        actions: [
          IconButton(icon: const Icon(Icons.date_range), onPressed: _pickDateRange),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // -------- Stats Card --------
            _cardWrapper(
              title: "Overview ($rangeText)",
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 0.98, // taller to avoid tiny overflows
                children: [
                  _statItem("Products", "$totalProducts", Icons.store_rounded),
                  _statItem("Orders", "$totalOrders", Icons.shopping_cart_rounded),
                  _statItem("Revenue", "₹${revenue.toStringAsFixed(0)}", Icons.monetization_on_rounded),
                  _statItem("Customers", "$newCustomers", Icons.people_alt_rounded),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // -------- Recent Orders Card --------
            _cardWrapper(
              title: "Recent Orders",
              child: recentOrders.isEmpty
                  ? const SizedBox(
                      height: 44,
                      child: Center(
                        child: Text("No recent orders", style: TextStyle(fontSize: 14)),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: recentOrders.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _orderTile(recentOrders[i]),
                    ),
            ),

            const SizedBox(height: 20),

            // -------- Best Sellers Card (horizontal list) --------
            _cardWrapper(
              title: "Best Selling Products",
              child: bestSellers.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text("No sales data"),
                    )
                  : SizedBox(
                      height: 110,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: bestSellers.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) => _bestSellerCard(bestSellers[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Widgets ----------

  Widget _cardWrapper({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(2, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              )),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _statItem(String title, String value, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFef3167), // pink mini-card
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 6,
            offset: const Offset(2, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16), // tiny bottom cushion
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // glowing circle behind icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.fade,
            style: const TextStyle(
              fontSize: 12, // tighter
              height: 1.1, // tighter line height
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderTile(Map<String, dynamic> order) {
    return InkWell(
      onTap: () async {
        final id = order['id']?.toString();
        if (id == null || id.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order id missing')));
          }
          return;
        }

        try {
          final docSnap = await FirebaseFirestore.instance.collection('orders').doc(id).get();
          if (!docSnap.exists) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order not found')));
            return;
          }
          final data = docSnap.data() ?? <String, dynamic>{};

          // Navigate to seller-facing order details page
          if (mounted) {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => OrderDetailsPage(orderId: id, orderData: Map<String, dynamic>.from(data), mySellerId: sellerId),
            ));
          }
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to open order: $e')));
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFef3167).withOpacity(0.92),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 6,
              offset: const Offset(2, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Text(
              "#${order['id'].toString().substring(0, order['id'].toString().length > 6 ? 6 : order['id'].toString().length)}",
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            Text(
              "₹${(order['amount'] as double).toStringAsFixed(0)}",
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: ((order['status'] ?? '') == "delivered" ? const Color.fromARGB(255, 15, 102, 18) : const Color.fromARGB(255, 133, 39, 7))
                    .withOpacity(0.40),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                (order['status'] ?? '').toString(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: (order['status'] ?? '') == "delivered" ? const Color.fromARGB(255, 65, 246, 71) : const Color.fromARGB(255, 246, 204, 185),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bestSellerCard(Map<String, dynamic> product) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(2, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.star, color: Color(0xFFef3167), size: 24),
          const SizedBox(height: 6),
          Text(
            product['name'],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          Text(
            "${product['qty']} sold",
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
