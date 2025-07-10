import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/fall_detection_service.dart';
import '../widgets/fall_alert_dialog.dart';

class FallDetectionProvider with ChangeNotifier {
  String _currentActivity = 'unknown';
  double _confidence = 0.0;
  bool _isFallDetected = false;
  bool _isStale = true;
  Timer? _updateTimer;
  bool _isShowingDialog = false;

  String get currentActivity => _currentActivity;
  double get confidence => _confidence;
  bool get isFallDetected => _isFallDetected;
  bool get isMonitoring => FallDetectionService.isMonitoring;
  bool get isStale => _isStale;

  Future<void> startMonitoring() async {
    print('🎯 Starting fall detection monitoring in provider');
    await FallDetectionService.initialize();
    await FallDetectionService.startMonitoring();

    // Check for updates more frequently (every 500ms)
    _updateTimer?.cancel();
    _updateTimer =
        Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      try {
        final prediction = await FallDetectionService.getLastPrediction();
        if (!timer.isActive)
          return; // Check if timer is still active before updating

        updatePrediction(
          prediction['activity'] as String,
          prediction['confidence'] as double,
          prediction['is_stale'] as bool,
        );
      } catch (e) {
        print('❌ Error updating fall detection status: $e');
        // Don't stop the timer on error, just log it
      }
    });

    notifyListeners();
  }

  Future<void> stopMonitoring() async {
    print('🛑 Stopping fall detection monitoring in provider');
    _updateTimer?.cancel();
    await FallDetectionService.stopMonitoring();
    _currentActivity = 'unknown';
    _confidence = 0.0;
    _isFallDetected = false;
    _isStale = true;
    notifyListeners();
  }

  void updatePrediction(String activity, double confidence, bool isStale) {
    final shouldUpdate = _currentActivity != activity ||
        _confidence != confidence ||
        _isStale != isStale ||
        _isFallDetected != (activity.toLowerCase() == 'falling');

    if (shouldUpdate) {
      print('📊 Updating fall detection status:');
      print('   - Activity: $activity');
      print('   - Confidence: ${(confidence * 100).toStringAsFixed(1)}%');
      print('   - Is Stale: $isStale');

      _currentActivity = activity;
      _confidence = confidence;
      final wasFallDetected = _isFallDetected;
      _isFallDetected = activity.toLowerCase() == 'falling';
      _isStale = isStale;

      // Check if this is a new fall detection
      if (_isFallDetected && !wasFallDetected && !_isShowingDialog) {
        _handleFallDetection();
      }

      notifyListeners();
    }
  }

  void clearFallDetection() {
    if (_isFallDetected) {
      _isFallDetected = false;
      notifyListeners();
    }
  }

  Future<void> _handleFallDetection() async {
    _isShowingDialog = true;
    bool userResponded = false;

    // Get the current context using the navigator key
    final context = FallDetectionService.navigatorKey.currentContext;
    if (context == null) {
      print('❌ No context available for showing fall alert dialog');
      _isShowingDialog = false;
      await FallDetectionService.sendFallDetectionNotification();
      return;
    }

    // Show the dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return FallAlertDialog(
          onConfirm: () {
            userResponded = true;
            _isShowingDialog = false;
            clearFallDetection();
          },
          onTimeout: () async {
            if (!userResponded) {
              _isShowingDialog = false;
              await FallDetectionService.sendFallDetectionNotification();
            }
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }
}
