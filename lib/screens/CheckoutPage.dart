// lib/checkout_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import 'payments_page.dart'; // adjust path if needed

class _ThemePalette {
  static const blueBg = Color(0xFFD0E3FF);
  static const pink = Color(0xFFEF3167);
  static const card = Color(0xFFFFFFFF);
  static const textDark = Color(0xFF172032);
  static const textSoft = Color(0xFF6B7280);
}

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  String? selectedAddressId;
  String paymentMethod = "cod"; // "cod" or "online"
  bool isPlacingOrder = false;

  @override
  void initState() {
    super.initState();
  }

  /// ---------------- PLACE ORDER (COD or AFTER PAYMENT) ----------------
  /// Note: this creates the final order doc only after payment (or if COD).
  Future<void> _createOrderRecord({
    required String uid,
    required List<Map<String, dynamic>> orderItems,
    required Map<String, dynamic>? addressData,
    required String paymentMethodValue,
    required String paymentStatusValue,
    required String paymentIdValue,
    required int totalAmount,
    String? sellerId,
  }) async {
    final orderRef = FirebaseFirestore.instance.collection('orders').doc();
    await orderRef.set({
      'userId': uid,
      'items': orderItems,
      'address': addressData,
      'paymentMethod': paymentMethodValue,
      'paymentStatus': paymentStatusValue,
      'paymentId': paymentIdValue,
      'orderStatus': "placed",
      'createdAt': FieldValue.serverTimestamp(),
      'totalAmount': totalAmount,
      if (sellerId != null) 'sellerId': sellerId,
    });
  }

  Future<void> _clearCartForUser(String uid) async {
    final cartSnap = await FirebaseFirestore.instance.collection('users').doc(uid).collection('cart').get();
    for (var doc in cartSnap.docs) {
      await doc.reference.delete();
    }
  }

  /// ---------------- ONLINE CHECKOUT FLOW ----------------
  Future<void> _checkoutOnlineFlow() async {
    setState(() => isPlacingOrder = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      // ensure cart not empty
      final cartSnap = await FirebaseFirestore.instance.collection('users').doc(uid).collection('cart').get();
      if (cartSnap.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your cart is empty')));
        return;
      }

      // ensure address selected
      if (selectedAddressId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a delivery address')));
        return;
      }

      // read preferred payment method id from user doc (optional logic kept)
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final preferredId = userDoc.data()?['preferred_payment_method_id'] as String?;

      if (preferredId == null || preferredId.isEmpty) {
        // if you want to let user enter txn id manually without saved method, you can still proceed.
        // but current UX expects saved UPI — ask user to add one
        await _showAddUpiRequiredDialog();
        return;
      }

      // read the preferred method doc
      final methodDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('payment_methods')
          .doc(preferredId)
          .get();

      if (!methodDoc.exists) {
        await _showAddUpiRequiredDialog();
        return;
      }

      final methodData = methodDoc.data()!;
      final type = methodData['type'] as String? ?? 'card';
      if (type != 'upi') {
        await _showSetUpiPreferredDialog();
        return;
      }

      // Now: determine seller to pay (assumes all cart items are from same seller or uses first item's seller)
      final firstItem = cartSnap.docs.first.data();
      final sellerId = (firstItem['sellerId'] ?? firstItem['seller'] ?? firstItem['sellerUid'])?.toString();
      if (sellerId == null || sellerId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seller information missing for cart items')));
        return;
      }

      // fetch seller data and seller UPI
      final sellerSnap = await FirebaseFirestore.instance.collection('users').doc(sellerId).get();
      if (!sellerSnap.exists) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seller record not found')));
        return;
      }
      final sellerData = sellerSnap.data()!;
      final sellerUpi = (sellerData['upi'] ?? '') as String;
      final sellerName = (sellerData['businessName'] ?? sellerData['name'] ?? 'Seller') as String;
      if (sellerUpi.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seller does not have a UPI ID; cannot pay online')));
        return;
      }

      // calculate total
      final orderItems = cartSnap.docs.map((d) => Map<String, dynamic>.from(d.data())).toList();
      final total = orderItems.fold<int>(0, (sum, item) {
        return (sum + ((item['price'] ?? 0) * (item['quantity'] ?? 1))).toInt();
      });

      // Build UPI uri and launch
      final uri = _buildUpiUriForPayment(
        payeeUpi: sellerUpi,
        payeeName: sellerName,
        amount: (total / 1).toStringAsFixed(2),
        note: 'Order payment to $sellerName',
        tr: null, // optional txn reference (we'll use order id after payment)
      );

      // try to launch UPI app
      try {
        final parsed = Uri.parse(uri.toString());
        if (await canLaunchUrl(parsed)) {
          await launchUrl(parsed);
          // UPI app opened — ask user to paste txn id when done
          final txn = await _askForTxnDialog(sellerUpi, total);
          if (txn != null && txn.isNotEmpty) {
            // create order now with payment recorded
            final addressData = (await FirebaseFirestore.instance.collection('users').doc(uid).collection('addresses').doc(selectedAddressId).get()).data();
            await _createOrderRecord(
              uid: uid,
              orderItems: orderItems,
              addressData: addressData,
              paymentMethodValue: 'upi',
              paymentStatusValue: 'paid',
              paymentIdValue: txn,
              totalAmount: total,
              sellerId: sellerId,
            );
            // clear cart
            await _clearCartForUser(uid);

            if (mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment recorded. Order placed.')));
            }
          } else {
            // user cancelled txn entry — do nothing (order not created)
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment not confirmed — order not placed')));
          }
        } else {
          // no UPI app available — fallback to manual txn entry
          final txn = await _askForTxnDialog(sellerUpi, total);
          if (txn != null && txn.isNotEmpty) {
            final addressData = (await FirebaseFirestore.instance.collection('users').doc(uid).collection('addresses').doc(selectedAddressId).get()).data();
            await _createOrderRecord(
              uid: uid,
              orderItems: orderItems,
              addressData: addressData,
              paymentMethodValue: 'upi',
              paymentStatusValue: 'paid',
              paymentIdValue: txn,
              totalAmount: total,
              sellerId: sellerId,
            );
            await _clearCartForUser(uid);
            if (mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment recorded. Order placed.')));
            }
          } else {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment not confirmed — order not placed')));
          }
        }
      } catch (e) {
        debugPrint('UPI launch error: $e');
        final txn = await _askForTxnDialog(sellerUpi, total);
        if (txn != null && txn.isNotEmpty) {
          final addressData = (await FirebaseFirestore.instance.collection('users').doc(uid).collection('addresses').doc(selectedAddressId).get()).data();
          await _createOrderRecord(
            uid: uid,
            orderItems: orderItems,
            addressData: addressData,
            paymentMethodValue: 'upi',
            paymentStatusValue: 'paid',
            paymentIdValue: txn,
            totalAmount: total,
            sellerId: sellerId,
          );
          await _clearCartForUser(uid);
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment recorded. Order placed.')));
          }
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment not confirmed — order not placed')));
        }
      }
    } catch (e, st) {
      debugPrint('checkoutOnlineFlow error: $e\n$st');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment flow error: $e')));
    } finally {
      if (mounted) setState(() => isPlacingOrder = false);
    }
  }

  Future<void> _showAddUpiRequiredDialog() async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add UPI to pay'),
        content: const Text('You need to add a UPI ID as a payment method before paying online.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentsPage(uid: FirebaseAuth.instance.currentUser!.uid)));
            },
            child: const Text('Add UPI'),
          )
        ],
      ),
    );
  }

  Future<void> _showSetUpiPreferredDialog() async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set a UPI as preferred'),
        content: const Text('Your preferred payment method is not a UPI. Please set one of your saved UPI methods as Preferred to pay.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentsPage(uid: FirebaseAuth.instance.currentUser!.uid)));
            },
            child: const Text('Open Payment Methods'),
          )
        ],
      ),
    );
  }

  // Build UPI URI for paying the seller
  Uri _buildUpiUriForPayment({
    required String payeeUpi,
    required String payeeName,
    required String amount,
    required String note,
    String? tr,
  }) {
    final params = {
      'pa': payeeUpi,
      'pn': payeeName,
      'tn': note,
      'am': amount,
      'cu': 'INR',
    };
    if (tr != null) params['tr'] = tr;
    return Uri(scheme: 'upi', host: 'pay', queryParameters: params);
  }

  Future<String?> _askForTxnDialog(String sellerUpi, int total) async {
    final controller = TextEditingController();
    return showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Please pay ₹$total to UPI ID:"),
            const SizedBox(height: 8),
            SelectableText(sellerUpi, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Enter UPI Transaction ID',
                hintText: 'e.g. TXN12345...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
  }

  /// ---------------- PLACE ORDER (COD) ----------------
  Future<void> _placeOrder({bool paid = false, String? txnId}) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final cartSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('cart')
        .get();

    if (cartSnap.docs.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Your cart is empty")));
      return;
    }

    if (selectedAddressId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Please select an address")));
      return;
    }

    setState(() => isPlacingOrder = true);

    // Fetch address
    final addressDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('addresses')
        .doc(selectedAddressId)
        .get();

    final addressData = addressDoc.data();

    // Prepare order items and totals
    final orderItems = cartSnap.docs.map((doc) => Map<String, dynamic>.from(doc.data())).toList();
    final totalAmount = orderItems.fold(0, (sum, item) {
      return (sum + ((item['price'] ?? 0) * (item['quantity'] ?? 1))).toInt();
    });

    // create order now (COD)
    await _createOrderRecord(
      uid: uid,
      orderItems: orderItems,
      addressData: addressData,
      paymentMethodValue: 'cod',
      paymentStatusValue: paid ? 'paid' : 'pending',
      paymentIdValue: txnId ?? '',
      totalAmount: totalAmount,
      // optional sellerId omitted here (you can add if needed)
    );

    // Clear cart
    for (var doc in cartSnap.docs) {
      await doc.reference.delete();
    }

    setState(() => isPlacingOrder = false);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Order placed successfully!")));
    }
  }

  /// ---------------- CALCULATE TOTAL ----------------
  Future<int> _calculateTotal() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final cartSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('cart')
        .get();

    final orderItems = cartSnap.docs.map((doc) => doc.data()).toList();
    final totalAmount = orderItems.fold(0, (sum, item) {
      return (sum + ((item['price'] ?? 0) * (item['quantity'] ?? 1))).toInt();
    });

    return totalAmount;
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: _ThemePalette.blueBg,
      appBar: AppBar(
        title: const Text(
          "Checkout",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: _ThemePalette.pink,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Delivery Address",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _ThemePalette.textDark)),
                    const SizedBox(height: 12),

                    Expanded(
                      child: Card(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 2,
                        color: _ThemePalette.card,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .doc(uid)
                                .collection('addresses')
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const Center(
                                    child: CircularProgressIndicator());
                              }

                              final addresses = snapshot.data!.docs;
                              if (addresses.isEmpty) {
                                return Center(
                                    child: Text("No address found. Add one!",
                                        style: TextStyle(color: _ThemePalette.textSoft)));
                              }

                              return ListView.separated(
                                itemCount: addresses.length,
                                separatorBuilder: (_, __) => const Divider(),
                                itemBuilder: (context, i) {
                                  final doc = addresses[i];
                                  final data = doc.data() as Map<String, dynamic>;

                                  return RadioListTile<String>(
                                    value: doc.id,
                                    groupValue: selectedAddressId,
                                    onChanged: (val) => setState(() => selectedAddressId = val),
                                    title: Text(
                                      data['label'] ?? 'Address',
                                      style: TextStyle(color: _ThemePalette.textDark, fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: Text(
                                      // keep subtitle concise so UI doesn't break
                                      "${data['label'] ?? data['line1'] ?? ''} ${data['city'] ?? ''}",
                                      style: TextStyle(color: _ThemePalette.textSoft),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    Text("Payment",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _ThemePalette.textDark)),
                    const SizedBox(height: 8),

                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        children: [
                          RadioListTile(
                            value: "cod",
                            groupValue: paymentMethod,
                            onChanged: (val) => setState(() => paymentMethod = val!),
                            title: const Text("Cash on Delivery"),
                          ),
                          const Divider(height: 1),
                          RadioListTile(
                            value: "online",
                            groupValue: paymentMethod,
                            onChanged: (val) => setState(() => paymentMethod = val!),
                            title: const Text("Pay Online (UPI only)"),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Icon(Icons.info_outline, color: _ThemePalette.textSoft),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Online payments use UPI only. Make sure you've added a UPI method in Payment Methods.",
                            style: TextStyle(color: _ThemePalette.textSoft),
                          ),
                        )
                      ],
                    ),
                  ],
                ),
              ),
            ),

            FutureBuilder<int>(
              future: _calculateTotal(),
              builder: (context, snap) {
                final total = snap.hasData ? snap.data! : 0;

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)],
                    borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(18), topRight: Radius.circular(18)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Total Amount", style: TextStyle(color: _ThemePalette.textSoft)),
                            const SizedBox(height: 4),
                            Text("₹$total",
                                style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: _ThemePalette.pink)),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _ThemePalette.pink,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                        ),
                        onPressed: isPlacingOrder
                            ? null
                            : () async {
                                if (paymentMethod == "cod") {
                                  await _placeOrder();
                                } else {
                                  await _checkoutOnlineFlow();
                                }
                              },
                        child: isPlacingOrder
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text("Place Order",
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      )
                    ],
                  ),
                );
              },
            )
          ],
        ),
      ),
    );
  }
}
