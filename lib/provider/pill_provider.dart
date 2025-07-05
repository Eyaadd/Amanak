import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:amanak/firebase/firebase_manager.dart';
import 'package:amanak/models/pill_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PillProvider extends ChangeNotifier {
  List<PillModel> _pills = [];
  String _displayUserId = "";
  String _displayName = "";
  String _currentUserRole = "";
  bool _isReadOnly = false;
  bool _isLoading = true;

  // Getters
  List<PillModel> get pills => _pills;
  String get displayUserId => _displayUserId;
  String get displayName => _displayName;
  String get currentUserRole => _currentUserRole;
  bool get isReadOnly => _isReadOnly;
  bool get isLoading => _isLoading;

  // Initialize provider and load pills
  Future<void> initialize() async {
    await checkUserRoleAndLoadData();
  }

  // Check user role and load appropriate data
  Future<void> checkUserRoleAndLoadData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;

      if (currentUserId != null) {
        // Get user data for the current user
        final userData = await FirebaseManager.getNameAndRole(currentUserId);
        final userRole = userData['role'] ?? '';
        final sharedUserEmail = userData['sharedUsers'] ?? '';

        _currentUserRole = userRole;
        _displayUserId = currentUserId;
        _displayName = userData['name'] ?? 'User';

        if (userRole.toLowerCase() == 'guardian' &&
            sharedUserEmail.isNotEmpty) {
          // If guardian, find the elder user's ID by their email
          final elderData =
              await FirebaseManager.getUserByEmail(sharedUserEmail);
          if (elderData != null) {
            _displayUserId = elderData['id'] ?? '';
            if (_displayUserId.isNotEmpty) {
              _isReadOnly = true;
              _displayName = elderData['name'] ?? 'Elder';
            }
          }
        }

        // Load pills for either current user (elder) or shared user (for guardian)
        await loadPills(_displayUserId);
      }
    } catch (e) {
      print('Error checking user role: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load pills from Firebase
  Future<void> loadPills([String? userId]) async {
    _isLoading = true;
    notifyListeners();

    try {
      final targetUserId = userId ?? FirebaseAuth.instance.currentUser?.uid;
      if (targetUserId != null) {
        // Get pills from Firebase
        _pills = await FirebaseManager.getPills(userId: targetUserId);
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      print('Error loading pills: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update a pill
  Future<void> updatePill(PillModel pill) async {
    try {
      // Use the original FirebaseManager update method to preserve notifications
      await FirebaseManager.updatePill(pill);

      // Reload pills to keep UI in sync
      await loadPills(_displayUserId);
    } catch (e) {
      print('Error updating pill: $e');
    }
  }

  // Mark pill as taken with all the original functionality
  Future<void> markPillAsTaken(PillModel pill, String timeKey) async {
    try {
      // Get the original pill from our list
      final originalPill = _pills.firstWhere((p) => p.id == pill.id);

      // Create a copy with the updated taken status
      final updatedPill = originalPill.copyWith();
      updatedPill.markTimeTaken(timeKey, DateTime.now());

      // Update via Firebase to preserve notifications
      await updatePill(updatedPill);
    } catch (e) {
      print('Error marking pill as taken: $e');
    }
  }

  // Add a new pill
  Future<String> addPill(PillModel pill) async {
    try {
      // Use the original add method to preserve scheduling notifications
      final pillId = await FirebaseManager.addPill(pill);

      // Reload pills to keep UI in sync
      await loadPills(_displayUserId);

      return pillId;
    } catch (e) {
      print('Error adding pill: $e');
      return "";
    }
  }

  // Delete a pill
  Future<void> deletePill(String pillId) async {
    try {
      await FirebaseManager.deletePill(pillId);
      await loadPills(_displayUserId);
    } catch (e) {
      print('Error deleting pill: $e');
    }
  }

  // Check for missed pills
  Future<void> checkForMissedPills() async {
    try {
      await FirebaseManager.checkForMissedPills();
      await loadPills(_displayUserId);
    } catch (e) {
      print('Error checking for missed pills: $e');
    }
  }
}
