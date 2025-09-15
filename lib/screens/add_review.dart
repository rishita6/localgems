import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddReviewWidget extends StatefulWidget {
  final String sellerId;
  const AddReviewWidget({super.key, required this.sellerId});

  @override
  State<AddReviewWidget> createState() => _AddReviewWidgetState();
}

class _AddReviewWidgetState extends State<AddReviewWidget> {
  int _rating = 0; // use int instead of double
  final TextEditingController _commentCtrl = TextEditingController();
  bool _loading = false;

  Future<void> _submitReview() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a rating")),
      );
      return;
    }

    setState(() => _loading = true);

    final reviewRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.sellerId)
        .collection('reviews')
        .doc(uid); // one review per user

    await reviewRef.set({
      'userId': uid,
      'rating': _rating,
      'comment': _commentCtrl.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    // update avg rating
    final reviewsSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.sellerId)
        .collection('reviews')
        .get();

    if (reviewsSnap.docs.isNotEmpty) {
      final ratings = reviewsSnap.docs.map((d) => (d['rating'] ?? 0) as int).toList();
      final avg = ratings.reduce((a, b) => a + b) / ratings.length;
      await FirebaseFirestore.instance.collection('users').doc(widget.sellerId).update({
        'avgRating': avg,
        'totalReviews': ratings.length,
      });
    }

    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Review submitted!")));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Leave a Review"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ⭐ Star Rating Row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final starIndex = i + 1;
              return GestureDetector(
                onTap: () => setState(() => _rating = starIndex),
                child: Icon(
                  starIndex <= _rating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 36,
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _commentCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: "Write your review",
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(
          onPressed: _loading ? null : _submitReview,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF3167)),
          child: _loading
              ? const SizedBox(
                  width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text("Submit"),
        )
      ],
    );
  }
}
