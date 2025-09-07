import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'chatpage.dart';

class _Palette {
  static const blueBg = Color(0xFFD0E3FF); // page background
  static const pink = Color(0xFFEF3167); // primary accent
  static const textDark = Color(0xFF222222);
  static const textSoft = Color(0xFF6B7280);
  static const cardCream = Color(0xFFFFFBF7); // soft cream for cards
  static const white = Colors.white;
}

class ChatListPage extends StatelessWidget {
  const ChatListPage({super.key});

  Future<Map<String, String>> _getUserBasics(String uid) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data() ?? {};
    final display = (data['businessName'] ?? data['name'] ?? 'User').toString();
    final photo = (data['profileImage'] ?? '').toString();
    return {'name': display, 'photo': photo};
  }

  String _formatTime(dynamic ts) {
    if (ts == null) return '';
    try {
      final dt = (ts is Timestamp) ? ts.toDate() : DateTime.fromMillisecondsSinceEpoch(ts is int ? ts : 0);
      return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: _Palette.blueBg,
      appBar: AppBar(
        title: const Text('Messages', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: _Palette.pink,
        elevation: 1,
        centerTitle: false,
        iconTheme: const IconThemeData(color: _Palette.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: me)
            .orderBy('lastTimestamp', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator(color: _Palette.pink));
          }
          final chats = snap.data!.docs;
          if (chats.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.chat_bubble_outline, size: 64, color: _Palette.textSoft),
                  SizedBox(height: 12),
                  Text('No conversations yet', style: TextStyle(color: _Palette.textSoft)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
            itemCount: chats.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final c = chats[i];
              final participantsRaw = (c['participants'] ?? []);
              final parts = (participantsRaw is List) ? participantsRaw : <dynamic>[];
              final otherUid = parts.firstWhere((x) => x != me, orElse: () => '');

              final lastMsg = (c['lastMessage'] ?? '').toString();
              final time = _formatTime(c['lastTimestamp']);

              return FutureBuilder<Map<String, String>>(
                future: _getUserBasics(otherUid),
                builder: (context, userSnap) {
                  final name = userSnap.data?['name'] ?? 'User';
                  final photo = userSnap.data?['photo'] ?? '';

                  return StreamBuilder<QuerySnapshot>(
                    stream: c.reference.collection('unread').snapshots(),
                    builder: (context, unreadSnap) {
                      int unread = 0;
                      if (unreadSnap.hasData && unreadSnap.data!.docs.isNotEmpty) {
                        final raw = unreadSnap.data!.docs.first.data();
                        if (raw is Map) {
                          unread = (raw[me] ?? 0) is int ? (raw[me] ?? 0) as int : int.tryParse((raw[me] ?? '0').toString()) ?? 0;
                        }
                      }

                      // Card wrapper for consistent theme
                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatPage(
                                chatId: c.id,
                                otherUid: otherUid,
                                otherName: name,
                                otherPhoto: photo,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: _Palette.cardCream,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(2, 3))],
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          child: Row(
                            children: [
                              // avatar with subtle border
                              Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color.fromARGB(255, 4, 4, 4).withOpacity(0.1), width: 0),
                                ),
                                child: CircleAvatar(
                                  radius: 26,
                                  backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                                  backgroundColor: const Color.fromARGB(255, 2, 2, 2),
                                  child: photo.isEmpty
                                      ? Text(
                                          name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                          style: const TextStyle(color: Color.fromARGB(255, 247, 240, 240), fontWeight: FontWeight.w700),
                                        )
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 12),

                              // name + last message
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: _Palette.textDark, fontWeight: FontWeight.w800, fontSize: 16)),
                                    const SizedBox(height: 6),
                                    Text(lastMsg,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: _Palette.textSoft, fontSize: 13)),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 12),

                              // time + unread badge
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(time, style: const TextStyle(color: _Palette.textSoft, fontSize: 12)),
                                  const SizedBox(height: 6),
                                  if (unread > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _Palette.pink,
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 3)],
                                      ),
                                      child: Text(
                                        unread.toString(),
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
