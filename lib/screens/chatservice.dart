import 'package:cloud_firestore/cloud_firestore.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Send a message
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String receiverId,
    required String message,
  }) async {
    final timestamp = FieldValue.serverTimestamp();

    final chatRef = _firestore.collection('chats').doc(chatId);
    final msgRef = chatRef.collection('messages').doc();

    await _firestore.runTransaction((tx) async {
      tx.set(msgRef, {
        'senderId': senderId,
        'receiverId': receiverId,
        'text': message,
        'timestamp': timestamp,
      });

      tx.set(chatRef, {
        'lastMessage': message,
        'lastTimestamp': timestamp,
        'participants': [senderId, receiverId],
        'unread.$receiverId': FieldValue.increment(1), // 🔥 increment unread
      }, SetOptions(merge: true));
    });
  }

  /// Reset unread count when user opens chat
  Future<void> markAsRead(String chatId, String userId) async {
    await _firestore.collection('chats').doc(chatId).set({
      'unread.$userId': 0,
    }, SetOptions(merge: true));
  }

  /// Get messages stream
  Stream<QuerySnapshot> getMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  /// Get chat list stream
  Stream<QuerySnapshot> getUserChats(String userId) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .orderBy('lastTimestamp', descending: true)
        .snapshots();
  }
}
