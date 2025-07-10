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
        final updatedPills =
            await FirebaseManager.getPills(userId: targetUserId);

        // Check if there are actual changes before notifying
        bool hasChanges = _pills.length != updatedPills.length;

        if (!hasChanges) {
          // Compare each pill to see if there are changes
          for (int i = 0; i < _pills.length; i++) {
            if (i >= updatedPills.length ||
                _pills[i].id != updatedPills[i].id ||
                _pills[i].takenDates.length !=
                    updatedPills[i].takenDates.length ||
                _pills[i].missed != updatedPills[i].missed) {
              hasChanges = true;
              break;
            }
          }
        }

        // Update the pills list
        _pills = updatedPills;
        _isLoading = false;

        // Always notify listeners to ensure UI updates
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
      // Update local list immediately for better UI responsiveness
      final index = _pills.indexWhere((p) => p.id == pill.id);
      if (index >= 0) {
        _pills[index] = pill;
        notifyListeners();
      }

      // Use the original FirebaseManager update method to preserve notifications
      await FirebaseManager.updatePill(pill);

      // Reload pills to keep UI in sync across all tabs
      await loadPills(_displayUserId);
    } catch (e) {
      print('Error updating pill: $e');
      // Make sure we reload data even if there was an error
      await loadPills(_displayUserId);
    }
  }

  // Mark pill as taken with all the original functionality
  Future<void> markPillAsTaken(PillModel pill, String timeKey) async {
    try {
      // Check time window validation
      final now = DateTime.now();
      final pillTime = DateTime(
        now.year,
        now.month,
        now.day,
        pill.times.first.hour,
        pill.times.first.minute,
      );

      // Calculate time difference in minutes
      final timeDifference = now.difference(pillTime).inMinutes;

      // Check if we're outside the allowed window (15 minutes before to 15 minutes after)
      if (timeDifference < -15 || timeDifference > 15) {
        // Throw an exception to be caught by the calling method
        throw Exception(
            'Cannot mark pill as taken outside the allowed time window (15 minutes before to 15 minutes after scheduled time)');
      }

      // Get the original pill from our list
      final originalPill = _pills.firstWhere((p) => p.id == pill.id);

      // Create a copy with the updated taken status
      final updatedPill = originalPill.copyWith();
      updatedPill.markTimeTaken(timeKey, DateTime.now().toUtc());

      // Update the pill in our local list immediately
      final index = _pills.indexWhere((p) => p.id == pill.id);
      if (index >= 0) {
        _pills[index] = updatedPill;
        notifyListeners();
      }

      // Update via Firebase to preserve notifications
      await FirebaseManager.updatePill(updatedPill);

      // Reload pills to ensure consistency across all tabs
      await loadPills(_displayUserId);
    } catch (e) {
      print('Error marking pill as taken: $e');
      // Re-throw the exception so the calling method can handle it
      rethrow;
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
      // First check for missed pills using Firebase Manager
      await FirebaseManager.checkForMissedPills();

      // Then reload pills to update the UI
      await loadPills(_displayUserId);
    } catch (e) {
      print('Error checking for missed pills: $e');
      // Make sure we reload data even if there was an error
      await loadPills(_displayUserId);
    }
  }
}
