import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MessagingTab extends StatefulWidget {
  static const routeName = "Messaging";
  const MessagingTab({super.key});

  @override
  State<MessagingTab> createState() => _MessagingTabState();
}

class _MessagingTabState extends State<MessagingTab> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _currentUserEmail;
  String? _guardianEmail;
  String? _chatPartnerName;
  Stream<QuerySnapshot>? _messagesStream;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    try {
      // Get current user's email
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      _currentUserEmail = currentUser.email;

      // Get user's data from Firestore
      final userDoc = await _firestore
          .collection('users')
          .where('email', isEqualTo: _currentUserEmail)
          .get();

      if (userDoc.docs.isNotEmpty) {
        final userData = userDoc.docs.first.data();
        _guardianEmail = userData['sharedUsers'] as String?;

        if (_guardianEmail != null) {
          // Get guardian's name
          final guardianDoc = await _firestore
              .collection('users')
              .where('email', isEqualTo: _guardianEmail)
              .get();

          if (guardianDoc.docs.isNotEmpty) {
            setState(() {
              _chatPartnerName =
                  guardianDoc.docs.first.data()['name'] as String?;
            });
          }

          // Set up messages stream
          _messagesStream = _firestore
              .collection('chats')
              .doc(_getChatId())
              .collection('messages')
              .orderBy('timestamp', descending: true)
              .snapshots();
        }
      }
    } catch (e) {
      print('Error initializing chat: $e');
    }
  }

  String _getChatId() {
    // Create a unique chat ID by combining both user emails
    final emails = [_currentUserEmail, _guardianEmail]..sort();
    return '${emails[0]}_${emails[1]}';
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty ||
        _currentUserEmail == null ||
        _guardianEmail == null) return;

    try {
      final chatId = _getChatId();
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
        'text': _messageController.text,
        'senderEmail': _currentUserEmail,
        'timestamp': FieldValue.serverTimestamp(),
      });

      _messageController.clear();
    } catch (e) {
      print('Error sending message: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey,
              child: Icon(Icons.person, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 8),
            Text(_chatPartnerName ?? 'Loading...'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Something went wrong'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data?.docs ?? [];

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message =
                        messages[index].data() as Map<String, dynamic>;
                    final isMe = message['senderEmail'] == _currentUserEmail;

                    // Handle null timestamp (happens for messages still processing on server side)
                    final timestamp = message['timestamp'];
                    final messageTime = timestamp != null
                        ? (timestamp as Timestamp).toDate()
                        : DateTime.now();

                    return _buildMessageBubble(
                      ChatMessage(
                        text: message['text'] as String,
                        isMe: isMe,
                        time: messageTime,
                      ),
                    );
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Align(
      alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: message.isMe ? Colors.blue : Colors.grey[300],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: message.isMe ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(message.time),
              style: TextStyle(
                fontSize: 12,
                color: message.isMe ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'Type a message...',
                border: InputBorder.none,
              ),
              maxLines: null,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class ChatMessage {
  final String text;
  final bool isMe;
  final DateTime time;

  ChatMessage({
    required this.text,
    required this.isMe,
    required this.time,
  });
}
