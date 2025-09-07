// lib/payments_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'common_widgets.dart';

class PaymentsPage extends StatefulWidget {
  final String uid;
  const PaymentsPage({super.key, required this.uid});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  late final Razorpay _razorpay;
  bool _loading = false;

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

  void _openRazorpay(double amount) {
    final user = FirebaseAuth.instance.currentUser;
    var options = {
      'key': 'rzp_test_123456789', // TODO: replace with your key
      'amount': (amount * 100).toInt(),
      'name': 'LocalGems',
      'description': 'Add payment method',
      'prefill': {
        'contact': user?.phoneNumber ?? '',
        'email': user?.email ?? '',
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Razorpay open error: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to open payment gateway')));
    }
  }

  void _handleSuccess(PaymentSuccessResponse res) async {
    // Save a simple record indicating a verified Razorpay payment method
    final uid = widget.uid;
    final user = FirebaseAuth.instance.currentUser;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('payment_methods')
          .add({
        'brand': 'Razorpay',
        'last4': '',
        'holder': user?.displayName ?? '',
        'paymentId': res.paymentId,
        'status': 'verified',
        'createdAt': Timestamp.now(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment method added')));
      }
    } catch (e) {
      debugPrint('Error saving payment method: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved payment failed')));
    }
  }

  void _handleError(PaymentFailureResponse res) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment failed: ${res.message ?? 'Unknown'}')));
  }

  void _handleExternalWallet(ExternalWalletResponse res) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('External wallet: ${res.walletName}')));
  }

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance.collection('users').doc(widget.uid).collection('payment_methods');

    return DarkScaffold(
      title: 'Payment Methods',
      child: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: ref.orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFEF3167)));
                }

                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) return const EmptyState(message: 'No payment methods saved.');

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final d = doc.data();
                    final brand = (d['brand'] ?? 'Card').toString();
                    final last4 = (d['last4'] ?? '••••').toString();
                    final holder = (d['holder'] ?? '').toString();
                    final status = (d['status'] ?? '').toString();

                    return Dismissible(
                      key: ValueKey(doc.id),
                      background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), color: const Color(0xFFEF3167), child: const Icon(Icons.delete, color: Colors.white)),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) async {
                        await doc.reference.delete();
                        return true;
                      },
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          leading: CircleAvatar(
                            radius: 24,
                            child: Text(brand[0].toUpperCase()),
                            backgroundColor: const Color(0xFFD0E3FF),
                          ),
                          title: Text('$brand · $last4', style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(holder, style: const TextStyle(color: Color(0xFF6B7280))),
                          trailing: Text(status.toUpperCase(), style: const TextStyle(color: Color(0xFFEF3167), fontWeight: FontWeight.w700)),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Add payment button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openRazorpay(10.0), // small verification amount
                icon: const Icon(Icons.add_card),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14.0),
                  child: Text('Add Payment Method (Test)', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF3167),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
