// lib/screens/chat_page.dart
import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import 'chatservice.dart';

class _Palette {
  static const blueBg = Color(0xFFD0E3FF); // page background
  static const pink = Color(0xFFEF3167); // primary accent
  static const textDark = Color(0xFF222222);
  static const textSoft = Color(0xFF6B7280);
  static const cardCream = Color(0xFFFFFBF7);
  static const white = Colors.white;
}

class ChatPage extends StatefulWidget {
  final String chatId;
  final String otherUid;
  final String otherName;
  final String? otherPhoto;

  const ChatPage({
    super.key,
    required this.chatId,
    required this.otherUid,
    required this.otherName,
    this.otherPhoto,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _me = FirebaseAuth.instance.currentUser!;
  final _msgCtrl = TextEditingController();
  final _chatService = ChatService();
  final _scrollController = ScrollController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Mark as read when opening chat
    _chatService.markAsRead(widget.chatId, _me.uid);
    // small delay then scroll to bottom (if messages exist)
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendText() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);

    await _chatService.sendMessage(
      chatId: widget.chatId,
      senderId: _me.uid,
      receiverId: widget.otherUid,
      message: text,
    );

    _msgCtrl.clear();
    setState(() => _sending = false);

    await Future.delayed(const Duration(milliseconds: 120));
    _scrollToBottom();
  }

  Future<void> _pickAndSendImage() async {
    if (_sending) return;
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600);
    if (picked == null) return;

    setState(() => _sending = true);
    try {
      final file = File(picked.path);
      final url = await _uploadToCloudinary(file);
      if (url != null && url.isNotEmpty) {
        // Write message directly into messages subcollection
        final msgRef = FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.chatId)
            .collection('messages')
            .doc();
        final now = FieldValue.serverTimestamp();
        await msgRef.set({
          'id': msgRef.id,
          'senderId': _me.uid,
          'text': '',
          'imageUrl': url,
          'timestamp': now,
        });

        // update parent chat doc (lastMessage/lastTimestamp)
        await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
          'lastMessage': '[Image]',
          'lastTimestamp': FieldValue.serverTimestamp(),
        });

        await Future.delayed(const Duration(milliseconds: 150));
        _scrollToBottom();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image upload failed')));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _sending = false);
    }
  }

  Future<String?> _uploadToCloudinary(File image) async {
    try {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/dwncvfoiq/image/upload');
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = 'flutter_localgems' // keep your preset
        ..files.add(await http.MultipartFile.fromPath('file', image.path));
      final res = await request.send();
      final body = await res.stream.bytesToString();
      final map = json.decode(body);
      return (map?['secure_url'] ?? '').toString();
    } catch (_) {
      return null;
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    try {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } catch (_) {}
  }

  String _formatTime(dynamic ts) {
    if (ts == null) return '';
    try {
      final dt = (ts is Timestamp) ? ts.toDate() : DateTime.fromMillisecondsSinceEpoch((ts is int) ? ts : 0);
      return DateFormat('hh:mm a').format(dt);
    } catch (_) {
      return '';
    }
  }

  void _openProfile() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfilePage(uid: widget.otherUid)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Palette.blueBg,
      appBar: AppBar(
        backgroundColor: _Palette.pink,
        elevation: 1,
        titleSpacing: 0,
        title: Row(
          children: [
            InkWell(
              onTap: _openProfile,
              borderRadius: BorderRadius.circular(24),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: _Palette.cardCream,
                backgroundImage: (widget.otherPhoto?.isNotEmpty ?? false) ? NetworkImage(widget.otherPhoto!) : null,
                child: (widget.otherPhoto?.isEmpty ?? true)
                    ? Text(widget.otherName[0].toUpperCase(), style: const TextStyle(color: _Palette.pink, fontWeight: FontWeight.bold))
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.otherName, style: const TextStyle(fontWeight: FontWeight.w800, color: _Palette.white)),
                  const SizedBox(height: 2),
                  const Text('Online', style: TextStyle(fontSize: 12, color: _Palette.white)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // messages stream
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatService.getMessages(widget.chatId),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: _Palette.pink));
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.chat_bubble_outline, size: 64, color: _Palette.textSoft),
                        SizedBox(height: 8),
                        Text("Say hello 👋", style: TextStyle(color: _Palette.textSoft)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: false,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final raw = docs[i].data() as Map<String, dynamic>;
                    final isMe = (raw['senderId'] ?? '') == _me.uid;
                    final text = (raw['text'] ?? '').toString();
                    final imageUrl = (raw['imageUrl'] ?? '').toString();
                    final time = _formatTime(raw['timestamp']);

                    // bubble content
                    final bubbleContent = Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (imageUrl.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              // open full-screen viewer
                              Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenImage(url: imageUrl)));
                            },
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.74, maxHeight: 300),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(imageUrl, fit: BoxFit.cover),
                              ),
                            ),
                          ),
                        if (text.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              text,
                              style: TextStyle(color: isMe ? _Palette.white : _Palette.textDark, fontSize: 15),
                            ),
                          ),
                        const SizedBox(height: 6),
                        Text(time, style: TextStyle(color: isMe ? _Palette.white.withOpacity(0.9) : _Palette.textSoft, fontSize: 11)),
                      ],
                    );

                    final bubble = Container(
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.74),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isMe ? _Palette.pink : _Palette.cardCream,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(isMe ? 16 : 6),
                          bottomRight: Radius.circular(isMe ? 6 : 16),
                        ),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4)],
                      ),
                      child: bubbleContent,
                    );

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (!isMe)
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: CircleAvatar(
                                radius: 16,
                                backgroundColor: _Palette.cardCream,
                                backgroundImage: (widget.otherPhoto?.isNotEmpty ?? false) ? NetworkImage(widget.otherPhoto!) : null,
                                child: (widget.otherPhoto?.isEmpty ?? true)
                                    ? Text(widget.otherName[0].toUpperCase(), style: const TextStyle(color: _Palette.textDark))
                                    : null,
                              ),
                            ),
                          bubble,
                          if (isMe) const SizedBox(width: 6),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // input area
          SafeArea(
            top: false,
            child: Container(
              color: _Palette.blueBg,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: _Palette.cardCream,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4)],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _msgCtrl,
                              style: const TextStyle(color: _Palette.textDark),
                              decoration: const InputDecoration(
                                hintText: 'Type a message…',
                                hintStyle: TextStyle(color: _Palette.textSoft),
                                border: InputBorder.none,
                              ),
                              minLines: 1,
                              maxLines: 4,
                            ),
                          ),

                          // image picker / send image
                          IconButton(
                            onPressed: _pickAndSendImage,
                            icon: Icon(Icons.photo, color: _Palette.textSoft),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // send button
                  Material(
                    color: _Palette.pink,
                    shape: const CircleBorder(),
                    child: IconButton(
                      onPressed: _sending ? null : _sendText,
                      icon: Icon(_sending ? Icons.hourglass_empty : Icons.send, color: _Palette.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple full-screen image viewer
class FullScreenImage extends StatelessWidget {
  final String url;
  const FullScreenImage({super.key, required this.url});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black38, elevation: 0),
      body: Center(child: Image.network(url)),
    );
  }
}

/// Lightweight in-file user profile page (safe fallback)
class UserProfilePage extends StatefulWidget {
  final String uid;
  const UserProfilePage({super.key, required this.uid});
  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(widget.uid).get();
    _data = doc.data();
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Palette.blueBg,
      appBar: AppBar(backgroundColor: _Palette.pink, title: const Text('Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _Palette.pink))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundImage: (_data?['profileImage'] ?? '').toString().isNotEmpty ? NetworkImage((_data?['profileImage']).toString()) : null,
                    child: ((_data?['profileImage'] ?? '').toString().isEmpty)
                        ? Text(((_data?['name'] ?? 'U').toString())[0].toUpperCase(), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold))
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text((_data?['businessName'] ?? _data?['name'] ?? 'User').toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text((_data?['email'] ?? '').toString(), style: const TextStyle(color: _Palette.textSoft)),
                  const SizedBox(height: 16),
                  if ((_data?['location'] ?? '').toString().isNotEmpty) Text('Location: ${_data?['location']}', style: const TextStyle(color: _Palette.textDark)),
                ],
              ),
            ),
    );
  }
}
