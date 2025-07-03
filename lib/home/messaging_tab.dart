import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:amanak/notifications/noti_service.dart';
import 'package:amanak/firebase/firebase_manager.dart';
import 'package:amanak/provider/my_provider.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import 'dart:math';
import 'package:amanak/services/encryption_service.dart';

class MessagingTab extends StatefulWidget {
  static const routeName = "Messaging";
  const MessagingTab({super.key});

  @override
  State<MessagingTab> createState() => _MessagingTabState();
}

class _MessagingTabState extends State<MessagingTab>
    with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotiService _notiService = NotiService();
  final EncryptionService _encryptionService = EncryptionService();
  String? _currentUserEmail;
  String? _currentUserId;
  String? _currentUserName;
  String? _guardianEmail;
  String? _guardianId;
  String? _chatPartnerName;
  Stream<QuerySnapshot>? _messagesStream;

  // Parameters that can be passed when navigating from a notification
  String? _notificationChatId;
  String? _notificationSenderId;
  String? _notificationSenderName;

  // Track the last message ID to detect new messages
  String? _lastMessageId;
  bool _isListeningForMessages = false;

  // Track if the messaging tab is currently active
  bool _isActive = false;

  // Keep track of the last tab index
  int _lastTabIndex = -1;

  // Map to store decrypted messages to avoid repeated decryption
  final Map<String, String> _decryptedMessages = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Don't mark as active immediately - will be updated in didChangeDependencies
    _initializeChat();

    // Check for any pending message notifications
    _checkPendingMessageNotifications();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _isActive = false; // Mark as inactive when closed
    _messageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Update active state based on app lifecycle
    _isActive = state == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Update active status based on current selected tab
    final provider = Provider.of<MyProvider>(context);

    // Check if tab index has changed
    if (_lastTabIndex != provider.selectedIndexHome) {
      _lastTabIndex = provider.selectedIndexHome;
      _isActive =
          _lastTabIndex == 2; // Check if messaging tab (index 2) is selected
      print('Tab changed. Messaging tab active: $_isActive');
    }

    // Check for arguments passed via navigation
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      _notificationChatId = args['chatId'];
      _notificationSenderId = args['senderId'];
      _notificationSenderName = args['senderName'];

      // If we have sender information from notification, update the UI
      if (_notificationSenderName != null) {
        setState(() {
          _chatPartnerName = _notificationSenderName;
        });
      }

      // If we have a chat ID from notification, set up the stream directly
      if (_notificationChatId != null) {
        _setupMessageStream(_notificationChatId!);
      }
    }
  }

  Future<void> _checkPendingMessageNotifications() async {
    try {
      if (!_notiService.isInitialized) {
        await _notiService.initNotification();
      }
      await _notiService.checkPendingMessageNotifications();
    } catch (e) {
      print('Error checking for pending message notifications: $e');
    }
  }

  Future<void> _initializeChat() async {
    try {
      // Get current user's email
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      _currentUserEmail = currentUser.email;
      _currentUserId = currentUser.uid;

      // Get user's data from Firestore
      final userData = await FirebaseManager.getNameAndRole(currentUser.uid);
      _currentUserName = userData['name'];
      _guardianEmail = userData['sharedUsers'] as String?;

      // Skip loading chat partner data if already provided via notification
      if (_notificationSenderName == null && _guardianEmail != null) {
        // Get guardian's name and ID
        final guardianData =
            await FirebaseManager.getUserByEmail(_guardianEmail!);

        if (guardianData != null) {
          setState(() {
            _chatPartnerName = guardianData['name'];
            _guardianId = guardianData['id'];
          });
        }
      }

      // Skip setting up message stream if already done via notification
      if (_messagesStream == null && _guardianEmail != null) {
        // Set up messages stream
        final chatId = _getChatId();

        // Initialize encryption for this chat
        await _encryptionService.initializeEncryption(chatId);

        _setupMessageStream(chatId);
      }
    } catch (e) {
      print('Error initializing chat: $e');
    }
  }

  void _setupMessageStream(String chatId) {
    // Set up the message stream
    _messagesStream = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();

    // Listen for new messages
    _listenForNewMessages(chatId);
  }

  void _listenForNewMessages(String chatId) {
    if (_isListeningForMessages) return;
    _isListeningForMessages = true;

    _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isNotEmpty) {
        final latestMessage = snapshot.docs.first;
        final messageData = latestMessage.data();
        final messageId = latestMessage.id;

        // Check if this is a new message (not from current user)
        if (_lastMessageId != messageId &&
            messageData['senderEmail'] != _currentUserEmail) {
          print('New message received: ${messageData['text']}');

          // Get sender name
          String senderName = _chatPartnerName ?? 'User';

          // Get message text
          final messageText = messageData['text'] as String? ?? '';

          // Send notification for the incoming message
          // Only if not active or app is in background
          if (!_isActive) {
            await _sendIncomingMessageNotification(senderName, messageText);
          } else {
            print('User is active in chat, not sending notification');
          }

          // Update last message ID
          _lastMessageId = messageId;
        } else if (_lastMessageId == null) {
          // Initialize last message ID without sending notification
          _lastMessageId = messageId;
          print('Initialized last message ID: $messageId');
        }
      }
    }, onError: (error) {
      print('Error listening for new messages: $error');
    });
  }

  Future<void> _sendIncomingMessageNotification(
      String senderName, String messageText) async {
    try {
      // Make sure notification service is initialized
      if (!_notiService.isInitialized) {
        await _notiService.initNotification();
      }

      // Only send notification if the user is not actively viewing the chat
      if (_currentUserId != null && !_isActive) {
        // Get chat ID for decryption
        final chatId = _getChatId();

        // Ensure message is decrypted before showing in notification
        String decryptedText = messageText;
        if (messageText.isNotEmpty &&
            _encryptionService.isLikelyEncrypted(messageText)) {
          decryptedText =
              await _encryptionService.decryptMessage(messageText, chatId);
        }

        // Send notification with decrypted message
        await _notiService.sendFcmNotification(
          userId: _currentUserId!,
          title: "New Message",
          body: "$senderName: $decryptedText",
          data: {
            'type': 'message',
            'chatId': chatId,
            'senderId': _guardianId ?? '',
            'senderName': senderName,
          },
        );
      }
    } catch (e) {
      print('Error sending incoming message notification: $e');
    }
  }

  String _getChatId() {
    // If we have a chat ID from notification, use that
    if (_notificationChatId != null) {
      return _notificationChatId!;
    }

    // Otherwise create chat ID from emails
    final emails = [_currentUserEmail, _guardianEmail]..sort();
    return '${emails[0]}_${emails[1]}';
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();

    if (messageText.isEmpty ||
        _currentUserEmail == null ||
        _guardianEmail == null) return;

    try {
      final chatId = _getChatId();

      // Encrypt the message before sending
      final encryptedText =
          await _encryptionService.encryptMessage(messageText, chatId);

      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
        'text': encryptedText,
        'senderEmail': _currentUserEmail,
        'timestamp': FieldValue.serverTimestamp(),
      });

      _messageController.clear();

      // We no longer need to send notification here as the listener will handle it
    } catch (e) {
      print('Error sending message: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    if (_currentUserEmail == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(localizations.messages),
          backgroundColor: theme.primaryColor,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Text(localizations.loading),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_chatPartnerName ?? localizations.messages,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _initializeChat,
          ),
        ],
      ),
      body: Container(
        color: Colors.white,
        child: Column(
          children: [
            Expanded(
              child: _messagesStream == null
                  ? Center(child: Text(localizations.loading))
                  : StreamBuilder<QuerySnapshot>(
                      stream: _messagesStream,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(child: Text(localizations.error));
                        }
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        }
                        final messages = snapshot.data?.docs ?? [];

                        return FutureBuilder<List<ChatMessage>>(
                            future: _processMessages(messages),
                            builder: (context, messagesSnapshot) {
                              if (messagesSnapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return Center(
                                    child: CircularProgressIndicator());
                              }

                              final chatMessages = messagesSnapshot.data ?? [];

                              // Sort messages by time
                              chatMessages
                                  .sort((a, b) => a.time.compareTo(b.time));
                              return _buildSimpleMessageList(chatMessages);
                            });
                      },
                    ),
            ),
            _buildSimpleMessageInput(),
          ],
        ),
      ),
    );
  }

  // Process messages to decrypt them
  Future<List<ChatMessage>> _processMessages(
      List<QueryDocumentSnapshot> docs) async {
    final chatId = _getChatId();
    final List<ChatMessage> result = [];

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final ts = data['timestamp'] as Timestamp?;

      if (ts == null) continue; // Skip messages without a timestamp

      final localTime = ts.toDate().toLocal();
      final encryptedText = data['text'] ?? '';

      // Decrypt the message
      final decryptedText =
          await _encryptionService.decryptMessage(encryptedText, chatId);

      result.add(ChatMessage(
        text: decryptedText,
        isMe: data['senderEmail'] == _currentUserEmail,
        time: localTime,
      ));
    }

    return result;
  }

  Widget _buildSimpleMessageList(List<ChatMessage> messages) {
    if (messages.isEmpty) {
      return Center(child: Text('No messages yet'));
    }
    List<Widget> messageWidgets = [];
    DateTime? lastDate;
    // Iterate from oldest to newest
    for (int i = 0; i < messages.length; i++) {
      final msg = messages[i];
      final msgDate = DateTime(msg.time.year, msg.time.month, msg.time.day);
      if (lastDate == null || msgDate != lastDate) {
        messageWidgets.add(_buildDateSeparator(msg.time));
        lastDate = msgDate;
      }
      messageWidgets.add(_buildSimpleMessageBubble(msg));
    }
    return ListView(
      reverse: true, // Newest at bottom
      padding: EdgeInsets.only(top: 12, bottom: 8),
      children: messageWidgets.reversed
          .toList(), // Reverse widgets for correct display
    );
  }

  Widget _buildSimpleMessageBubble(ChatMessage message) {
    final isMe = message.isMe;
    final theme = Theme.of(context);
    final avatar = _buildAvatar(isMe ? _currentUserName : _chatPartnerName);
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 10),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            avatar,
            SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? theme.primaryColor : Colors.grey[200],
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 0),
                  bottomRight: Radius.circular(isMe ? 0 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black87,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    _formatTime(message.time),
                    style: TextStyle(
                      fontSize: 11,
                      color: isMe ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) ...[
            SizedBox(width: 6),
            avatar,
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar(String? name) {
    if (name == null || name.isEmpty) {
      return CircleAvatar(
        radius: 16,
        backgroundColor: Colors.grey[300],
        child: Icon(Icons.person, color: Colors.grey[700], size: 16),
      );
    }
    final initials = name
        .trim()
        .split(' ')
        .map((e) => e.isNotEmpty ? e[0] : '')
        .take(2)
        .join()
        .toUpperCase();
    final color =
        Colors.primaries[(name.hashCode.abs()) % Colors.primaries.length];
    return CircleAvatar(
      radius: 16,
      backgroundColor: color.withOpacity(0.8),
      child: Text(initials,
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }

  Widget _buildSimpleMessageInput() {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.10),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: localizations.askQuestion,
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                maxLines: null,
                style: TextStyle(fontSize: 15),
              ),
            ),
          ),
          SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: theme.primaryColor,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(Icons.send, color: Colors.white),
              onPressed: _sendMessage,
              splashRadius: 22,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildDateSeparator(DateTime date) {
    final now = DateTime.now();
    final dateOnly = DateTime(date.year, date.month, date.day);
    final nowOnly = DateTime(now.year, now.month, now.day);
    String label;
    if (dateOnly == nowOnly) {
      label = AppLocalizations.of(context)!.today;
    } else if (nowOnly.difference(dateOnly).inDays == 1) {
      label = 'Yesterday';
    } else {
      label = '${date.day}/${date.month}/${date.year}';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(label,
                style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          ),
        ],
      ),
    );
  }

  // Update active status when tab changes
  void _updateActiveStatus() {
    final provider = Provider.of<MyProvider>(context, listen: false);
    final isMessagingTabSelected = provider.selectedIndexHome == 2;

    // Only update if changed
    if (_isActive != isMessagingTabSelected) {
      setState(() {
        _isActive = isMessagingTabSelected;
      });

      // Debug
      print('Messaging tab active status updated: $_isActive');
    }
  }

  // Helper method to decrypt a message, with caching
  Future<String> _getDecryptedMessage(
      String messageId, String encryptedText) async {
    // Check if we already decrypted this message
    if (_decryptedMessages.containsKey(messageId)) {
      return _decryptedMessages[messageId]!;
    }

    // If not, decrypt it
    try {
      final chatId = _getChatId();
      final decryptedText =
          await _encryptionService.decryptMessage(encryptedText, chatId);

      // Cache the decrypted message
      _decryptedMessages[messageId] = decryptedText;

      return decryptedText;
    } catch (e) {
      print('Error decrypting message: $e');
      return encryptedText; // Return original text if decryption fails
    }
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

class BubbleTailPainter extends CustomPainter {
  final Color color;
  final bool isMe;
  BubbleTailPainter({required this.color, required this.isMe});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    if (isMe) {
      path.moveTo(0, 0);
      path.lineTo(10, 0);
      path.lineTo(0, 10);
      path.close();
      canvas.drawPath(path, paint);
    } else {
      path.moveTo(10, 0);
      path.lineTo(0, 0);
      path.lineTo(10, 10);
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
