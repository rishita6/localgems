// lib/payments_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
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

  // UPI fields
  final TextEditingController _upiController = TextEditingController();
  String? _preferredMethodId; // stored in user doc, read on load

  // consistent card size
  static const double cardHeight = 150;
  static const double cardMinWidth = 260;
  static const double cardMaxWidth = 340;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handleError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    _loadPreferredMethod();
  }

  Future<void> _loadPreferredMethod() async {
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid ?? widget.uid;
      final doc = await FirebaseFirestore.instance.collection('users').doc(currentUid).get();
      if (doc.exists) {
        setState(() {
          _preferredMethodId = doc.data()?['preferred_payment_method_id'] as String?;
        });
      }
    } catch (e) {
      debugPrint('loadPreferredMethod error: $e');
    }
  }

  CollectionReference<Map<String, dynamic>> _methodsRefFor(String uid) {
    return FirebaseFirestore.instance.collection('users').doc(uid).collection('payment_methods');
  }

  @override
  void dispose() {
    _razorpay.clear();
    _upiController.dispose();
    super.dispose();
  }

  // kept razorpay handlers in case you use them elsewhere (no UI button here)
  void _handleSuccess(PaymentSuccessResponse res) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? widget.uid;
    final user = FirebaseAuth.instance.currentUser;

    try {
      final docRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('payment_methods')
          .add({
        'type': 'card',
        'brand': 'Razorpay',
        'last4': '',
        'holder': user?.displayName ?? '',
        'paymentId': res.paymentId,
        'status': 'verified',
        'createdAt': Timestamp.now(),
      });

      await FirebaseFirestore.instance.collection('users').doc(currentUid).update({'preferred_payment_method_id': docRef.id});

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

  // ---------- UPI methods management ----------
  Future<void> _addUpiMethod() async {
    final upi = _upiController.text.trim();
    if (upi.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid UPI ID')));
      return;
    }
    setState(() => _loading = true);
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid ?? widget.uid;
      final docRef = await _methodsRefFor(currentUid).add({
        'type': 'upi',
        'upi': upi,
        'label': upi,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'saved',
      });

      // set as preferred automatically when saving new UPI
      await FirebaseFirestore.instance.collection('users').doc(currentUid).update({'preferred_payment_method_id': docRef.id});

      _upiController.clear();
      setState(() {
        _preferredMethodId = docRef.id;
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('UPI saved and set as preferred')));
    } catch (e) {
      debugPrint('Save UPI failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save UPI: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setPreferredMethod(String? methodId) async {
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid ?? widget.uid;
      await FirebaseFirestore.instance.collection('users').doc(currentUid).update({'preferred_payment_method_id': methodId});
      setState(() {
        _preferredMethodId = methodId;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preferred payment method updated')));
    } catch (e) {
      debugPrint('Set preferred failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to set preferred: $e')));
    }
  }

  // Utility: build UPI intent URI (to pay a seller)
  Uri _buildUpiUriForPayment({required String payeeUpi, required String payeeName, required String amount, String note = 'Payment', String? tr}) {
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

  // Launch UPI app to pay the provided seller UPI.
  Future<bool> launchUpiPayment({required String sellerUpi, required String sellerName, required double amount, String? orderId}) async {
    if (!Platform.isAndroid) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('UPI intents are most reliable on Android devices')));
      return false;
    }
    final uri = _buildUpiUriForPayment(
      payeeUpi: sellerUpi,
      payeeName: sellerName,
      amount: amount.toStringAsFixed(2),
      note: orderId != null ? 'Order:$orderId' : 'Payment',
      tr: orderId,
    );
    final parsed = Uri.parse(uri.toString());
    try {
      if (await canLaunchUrl(parsed)) {
        await launchUrl(parsed);
        return true;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No UPI app found on device')));
        return false;
      }
    } catch (e) {
      debugPrint('launchUpiPayment error: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to open UPI app')));
      return false;
    }
  }

  // ---------- UI helpers ----------
  Widget _noMethodsPlaceholder() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(child: const Icon(Icons.account_balance_wallet_outlined), backgroundColor: const Color(0xFFD0E3FF)),
            const SizedBox(width: 12),
            Expanded(child: Text('No saved UPI methods. Save one above to use it at checkout.', style: TextStyle(color: Colors.black87))),
          ],
        ),
      ),
    );
  }

  Widget _buildUpiListFromDocs(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
      scrollDirection: Axis.horizontal,
      itemCount: docs.length,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (context, i) {
        final doc = docs[i];
        final d = doc.data();
        final upi = (d['upi'] ?? '') as String;
        final label = (d['label'] ?? upi) as String;
        final isPreferred = doc.id == _preferredMethodId;

        return ConstrainedBox(
          constraints: const BoxConstraints(minWidth: cardMinWidth, maxWidth: cardMaxWidth),
          child: SizedBox(
            height: cardHeight, // consistent height
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween, // space between top info and actions
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // top row: avatar + label + preferred badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(radius: 20, child: Text(label.isNotEmpty ? label[0].toUpperCase() : 'U'), backgroundColor: const Color(0xFFD0E3FF)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // use Text with soft wrapping for long labels
                              Text('UPI · $label', style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 6),
                              Text(upi, style: const TextStyle(color: Color(0xFF6B7280)), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        if (isPreferred)
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0, top: 2),
                            child: Column(
                              children: const [
                                Text('SAVED', style: TextStyle(color: Color(0xFFEF3167), fontWeight: FontWeight.bold)),
                                SizedBox(height: 4),
                                Text('Preferred', style: TextStyle(fontSize: 11, color: Colors.black54)),
                              ],
                            ),
                          ),
                      ],
                    ),

                    // bottom row: actions
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: upi));
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('UPI copied')));
                          },
                          icon: const Icon(Icons.copy, size: 18),
                          label: const Text('Copy'),
                        ),
                        const Spacer(),
                        SizedBox(
                          height: 36,
                          child: ElevatedButton(
                            onPressed: () => _setPreferredMethod(doc.id),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isPreferred ? Colors.grey.shade300 : const Color(0xFFEF3167),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text(isPreferred ? 'Preferred' : 'Set Preferred', style: TextStyle(color: isPreferred ? Colors.black87 : Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    // prefer signed-in user uid to avoid mismatch
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? widget.uid;
    debugPrint('PaymentsPage: widget.uid=${widget.uid}, currentUid=$currentUid');
    final collectionRef = _methodsRefFor(currentUid);

    return DarkScaffold(
      title: 'Payment Methods',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // UPI input + Save button (top)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _upiController,
                    decoration: const InputDecoration(
                      hintText: 'Add UPI ID (e.g. name@bank)',
                      border: UnderlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _loading ? null : _addUpiMethod,
                  child: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Save'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF3167)),
                )
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text('Saved UPI Methods', style: Theme.of(context).textTheme.titleMedium),
          ),
          const SizedBox(height: 8),

          // Robust StreamBuilder with fallback; consistent card sizes
          SizedBox(
            height: cardHeight + 24, // list area height (card + padding)
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: collectionRef.where('type', isEqualTo: 'upi').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  debugPrint('payment methods stream error: ${snap.error}');
                  // fallback: simple stream without orderBy; filter client-side
                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: collectionRef.snapshots(),
                    builder: (ctx2, snap2) {
                      if (snap2.hasError) {
                        debugPrint('fallback payment methods stream error: ${snap2.error}');
                        return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text('Unable to load payment methods: ${snap2.error}', style: const TextStyle(color: Colors.red)),
                        );
                      }

                      if (snap2.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: Color(0xFFEF3167)));
                      }

                      final docs = (snap2.data?.docs ?? []).where((d) => (d.data()['type'] ?? '') == 'upi').toList();
                      if (docs.isEmpty) return _noMethodsPlaceholder();
                      return _buildUpiListFromDocs(docs);
                    },
                  );
                }

                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFEF3167)));
                }

                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) return _noMethodsPlaceholder();
                return _buildUpiListFromDocs(docs);
              },
            ),
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
