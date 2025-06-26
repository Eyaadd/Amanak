import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final String? type;
  final Map<String, dynamic>? data;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    this.type,
    this.data,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json, String id) {
    return NotificationItem(
      id: id,
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      timestamp: (json['timestamp'] as Timestamp).toDate(),
      isRead: json['isRead'] ?? false,
      type: json['type'],
      data: json['data'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'type': type,
      'data': data,
    };
  }

  NotificationItem copyWith({
    String? title,
    String? message,
    DateTime? timestamp,
    bool? isRead,
    String? type,
    Map<String, dynamic>? data,
  }) {
    return NotificationItem(
      id: this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
      data: data ?? this.data,
    );
  }
}

class NotificationProvider with ChangeNotifier {
  List<NotificationItem> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _error;

  List<NotificationItem> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get error => _error;

  NotificationProvider() {
    // Initialize by fetching notifications when a user is logged in
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      fetchNotifications();
    }

    // Listen to auth state changes
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        fetchNotifications();
        subscribeToNotifications();
      } else {
        _notifications = [];
        _unreadCount = 0;
        notifyListeners();
      }
    });
  }

  // Fetch notifications from Firestore
  Future<void> fetchNotifications() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .get();

      _notifications = snapshot.docs
          .map((doc) => NotificationItem.fromJson(doc.data(), doc.id))
          .toList();

      _calculateUnreadCount();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      print('Error fetching notifications: $e');
      notifyListeners();
    }
  }

  // Subscribe to real-time updates
  void subscribeToNotifications() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen(
      (snapshot) {
        _notifications = snapshot.docs
            .map((doc) => NotificationItem.fromJson(doc.data(), doc.id))
            .toList();
        _calculateUnreadCount();
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        print('Error listening to notifications: $e');
        notifyListeners();
      },
    );
  }

  // Mark a notification as read
  Future<void> markAsRead(String notificationId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});

      // Update local state
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index >= 0) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
        _calculateUnreadCount();
        notifyListeners();
      }
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  // Mark all notifications as read
  Future<void> markAllAsRead() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final batch = FirebaseFirestore.instance.batch();

    // Get all unread notifications
    final unreadNotifications = _notifications.where((n) => !n.isRead).toList();

    for (var notification in unreadNotifications) {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('notifications')
          .doc(notification.id);

      batch.update(docRef, {'isRead': true});
    }

    try {
      await batch.commit();

      // Update local state
      _notifications =
          _notifications.map((n) => n.copyWith(isRead: true)).toList();

      _unreadCount = 0;
      notifyListeners();
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  // Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('notifications')
          .doc(notificationId)
          .delete();

      // Update local state
      _notifications.removeWhere((n) => n.id == notificationId);
      _calculateUnreadCount();
      notifyListeners();
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  // Delete all notifications
  Future<void> deleteAllNotifications() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // Get all notifications
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('notifications')
          .get();

      // Delete in batches
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Update local state
      _notifications = [];
      _unreadCount = 0;
      notifyListeners();
    } catch (e) {
      print('Error deleting all notifications: $e');
    }
  }

  void _calculateUnreadCount() {
    _unreadCount = _notifications.where((n) => !n.isRead).length;
  }
}
