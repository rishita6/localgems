// lib/checkout_page.dart (updated UI - blue & pink theme)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

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
  String paymentMethod = "cod"; // default COD
  bool isPlacingOrder = false;

  late Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handleError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

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

    // Prepare order
    final orderItems = cartSnap.docs.map((doc) => doc.data()).toList();
    final totalAmount = orderItems.fold(0, (sum, item) {
      return (sum + ((item['price'] ?? 0) * (item['quantity'] ?? 1))).toInt();
    });

    final orderRef = FirebaseFirestore.instance.collection('orders').doc();

    await orderRef.set({
      'userId': uid,
      'items': orderItems,
      'address': addressData,
      'paymentMethod': paymentMethod,
      'paymentStatus': paid ? "paid" : "pending",
      'paymentId': txnId ?? "",
      'orderStatus': "placed",
      'createdAt': DateTime.now(),
      'totalAmount': totalAmount,
    });

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

  /// 🔹 Razorpay Checkout
  void _openRazorpay(double amount) {
    var options = {
      'key': 'rzp_test_123456789', // ⚠️ Replace with your Razorpay Key ID
      'amount': (amount * 100).toInt(), // in paise
      'name': 'My Shop',
      'description': 'Order Payment',
      'prefill': {
        'contact': '9876543210',
        'email': 'customer@gmail.com',
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Razorpay error: $e');
    }
  }

  void _handleSuccess(PaymentSuccessResponse res) {
    _placeOrder(paid: true, txnId: res.paymentId);
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Payment Successful ✅")));
  }

  void _handleError(PaymentFailureResponse res) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Payment Failed ❌: ${res.message ?? "Unknown error"}")));
  }

  void _handleExternalWallet(ExternalWalletResponse res) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("External Wallet Selected: ${res.walletName}")));
  }

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

                    // Address list inside card
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
                                      "${data['line1']}, ${data['city']} - ${data['pincode']}\nPhone: ${data['phone']}",
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
                            title: const Text("Pay Online (UPI / Card / Wallet)"),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Note / help
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: _ThemePalette.textSoft),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "You can change the payment method later from order details.",
                            style: TextStyle(color: _ThemePalette.textSoft),
                          ),
                        )
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Bottom bar with total + place order button
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
                            Text('Total', style: TextStyle(color: _ThemePalette.textSoft)),
                            const SizedBox(height: 6),
                            Text('₹$total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _ThemePalette.textDark)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 180,
                        child: ElevatedButton(
                          onPressed: isPlacingOrder
                              ? null
                              : () async {
                                  if (paymentMethod == "cod") {
                                    await _placeOrder(paid: false);
                                  } else if (paymentMethod == "online") {
                                    _openRazorpay(total.toDouble());
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _ThemePalette.pink,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                          child: isPlacingOrder
                              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Place Order', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
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
