import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sensors_plus/sensors_plus.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:amanak/notifications/noti_service.dart';
import 'package:amanak/firebase/firebase_manager.dart';
import 'package:firebase_auth/firebase_auth.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case FallDetectionService.FALL_DETECTION_TASK:
        // Keep the service alive and ensure sensors are running
        await FallDetectionService.ensureServiceRunning();
        break;
    }
    return true;
  });
}

class FallDetectionService {
  // Add navigator key for accessing context
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static const String API_URL =
      'https://fall-detection-production.up.railway.app/predict/';
  static const String FALL_DETECTION_TASK = 'fall_detection_task';
  static const int SAMPLING_RATE = 50; // 50Hz
  static const int WINDOW_SIZE = 100; // 100 samples per window
  static const Duration SAMPLING_INTERVAL =
      Duration(milliseconds: 20); // 1000ms/50Hz = 20ms

  static List<Map<String, double>> _sensorBuffer = [];
  static StreamSubscription? _accelerometerSubscription;
  static StreamSubscription? _gyroscopeSubscription;
  static Timer? _processingTimer;
  static bool _isInitialized = false;
  static bool _isMonitoring = false;
  static final _client = http.Client(); // Create a reusable HTTP client

  // Add variables for sensor synchronization
  static UserAccelerometerEvent? _lastAccelEvent;
  static GyroscopeEvent? _lastGyroEvent;
  static int _lastReadingTime = 0;
  static const int SENSOR_SYNC_THRESHOLD =
      100; // 100ms threshold for sensor synchronization
  static bool _gyroscopeAvailable = false;
  static int _gyroscopeReadingsCount = 0;
  static int _accelerometerReadingsCount = 0;

  // Variables for isolate communication
  static Isolate? _processingIsolate;
  static ReceivePort? _receivePort;
  static SendPort? _sendPort;

  // Initialize the service
  static Future<void> initialize() async {
    print('🚀 Initializing Fall Detection Service');

    // Force reinitialization
    _isInitialized = false;
    _isMonitoring = false;
    await stopMonitoring();

    try {
      // Check sensor availability
      print('📱 Checking sensor availability...');

      bool hasGyroscope = false;
      try {
        print('🔄 Testing gyroscope stream...');
        final gyroStream = gyroscopeEvents;
        await for (var event in gyroStream.timeout(
          const Duration(seconds: 2),
          onTimeout: (sink) {
            sink.close();
            throw TimeoutException('Gyroscope not responding');
          },
        )) {
          print(
              '✅ Received gyroscope event: x=${event.x}, y=${event.y}, z=${event.z}');
          hasGyroscope = true;
          break;
        }
      } catch (e) {
        print('⚠️ Gyroscope check failed: $e');
        print('⚠️ Device might not have a gyroscope or it might be disabled');
        hasGyroscope = false;
      }

      print('📊 Gyroscope available: $hasGyroscope');
      _gyroscopeAvailable = hasGyroscope;

      await Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
      print('✅ Workmanager initialized successfully');

      // Start data processing isolate
      await _startProcessingIsolate();

      _isInitialized = true;
    } catch (e) {
      print('❌ Error initializing service: $e');
      print('❌ Stack trace: ${StackTrace.current}');
    }
  }

  // Start the processing isolate
  static Future<void> _startProcessingIsolate() async {
    if (_processingIsolate != null) {
      await _stopProcessingIsolate();
    }

    try {
      // Create a receive port for communication
      _receivePort = ReceivePort();

      // Create the isolate
      _processingIsolate = await Isolate.spawn(
        _isolateEntryPoint,
        _receivePort!.sendPort,
      );

      // Listen for messages from the isolate
      _receivePort!.listen((message) {
        if (message is SendPort) {
          // Store the isolate's SendPort for communication
          _sendPort = message;
          print('✅ Processing isolate ready to receive data');
        } else if (message is Map<String, dynamic>) {
          // Handle prediction result from isolate
          _handlePredictionResult(message);
        } else {
          print('📊 Message from isolate: $message');
        }
      });

      print('✅ Processing isolate started successfully');
    } catch (e) {
      print('❌ Error starting processing isolate: $e');
      print('❌ Stack trace: ${StackTrace.current}');
    }
  }

  // Stop the processing isolate
  static Future<void> _stopProcessingIsolate() async {
    if (_processingIsolate != null) {
      _processingIsolate!.kill(priority: Isolate.immediate);
      _processingIsolate = null;
    }

    _receivePort?.close();
    _receivePort = null;
    _sendPort = null;
  }

  // Isolate entry point
  @pragma('vm:entry-point')
  static void _isolateEntryPoint(SendPort sendPort) {
    // Create a receive port for this isolate
    final receivePort = ReceivePort();

    // Send the receive port's send port back to the main isolate
    sendPort.send(receivePort.sendPort);

    // Listen for messages from the main isolate
    receivePort.listen((message) async {
      if (message is List<Map<String, double>>) {
        // Process sensor data
        try {
          final result = await _processDataInIsolate(message);
          sendPort.send(result);
        } catch (e) {
          sendPort.send({'error': e.toString()});
        }
      } else if (message == 'shutdown') {
        Isolate.exit();
      }
    });
  }

  // Process data in isolate
  static Future<Map<String, dynamic>> _processDataInIsolate(
      List<Map<String, double>> data) async {
    try {
      print('🔄 Processing data in isolate...');
      print('📊 Sample count: ${data.length}');

      // Create the request body
      final body = jsonEncode({
        'sensor_data': data,
      });

      print('📤 Sending request to API...');
      print('📍 API URL: $API_URL');
      print('📦 Request body length: ${body.length} characters');

      // Create a client
      final client = http.Client();
      try {
        var response = await client
            .post(
          Uri.parse(API_URL),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: body,
        )
            .timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException('API request timed out');
          },
        );

        print('📥 API Response received:');
        print('   Status code: ${response.statusCode}');
        print('   Response headers: ${response.headers}');
        print('   Response body: ${response.body}');

        if (response.statusCode >= 200 && response.statusCode < 300) {
          if (response.body.isNotEmpty) {
            final result = jsonDecode(response.body);

            print('🔍 Parsed API Response:');
            print('   Raw result: $result');
            print('   Type: ${result.runtimeType}');
            if (result is Map) {
              print('   Keys: ${result.keys.toList()}');
              print(
                  '   predicted_class: ${result['predicted_class']} (${result['predicted_class']?.runtimeType})');
              print(
                  '   confidence: ${result['confidence']} (${result['confidence']?.runtimeType})');
            }

            // Check if the required fields exist in the response
            if (result == null) {
              print('❌ API returned null response');
              return {'error': 'API returned null response'};
            }

            final predictedClass =
                result['predicted_class']?.toString() ?? 'unknown';
            final confidence = result['confidence'] != null
                ? (result['confidence'] as num).toDouble()
                : 0.0;

            print('✅ Successfully processed response:');
            print('   Predicted class: $predictedClass');
            print('   Confidence: $confidence');

            return {
              'success': true,
              'predicted_class': predictedClass,
              'confidence': confidence,
              'time': DateTime.now().millisecondsSinceEpoch,
            };
          } else {
            print('❌ Empty response body received');
            return {'error': 'Empty response body'};
          }
        } else {
          print('❌ API Error: Status ${response.statusCode}');
          print('   Response body: ${response.body}');
          return {
            'error': 'API Error: Status ${response.statusCode}',
            'body': response.body,
          };
        }
      } catch (e) {
        print('❌ Error during API request: $e');
        print('❌ Stack trace: ${StackTrace.current}');
        return {'error': e.toString()};
      } finally {
        client.close();
      }
    } catch (e) {
      print('❌ Error processing data in isolate: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      return {'error': e.toString()};
    }
  }

  // Handle prediction result from isolate
  static Future<void> _handlePredictionResult(
      Map<String, dynamic> result) async {
    try {
      if (result.containsKey('success') && result['success'] == true) {
        // Safely handle potentially null values
        final predictedClass =
            result['predicted_class']?.toString() ?? 'unknown';
        final confidence = result['confidence'] != null
            ? (result['confidence'] as num).toDouble()
            : 0.0;
        final timestamp = result['time'] != null
            ? (result['time'] as num).toInt()
            : DateTime.now().millisecondsSinceEpoch;

        print('🎯 Prediction Result:');
        print('   - Activity: $predictedClass');
        print('   - Confidence: ${(confidence * 100).toStringAsFixed(1)}%');
        print('   - Timestamp: $timestamp');

        // Save prediction result
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_activity', predictedClass);
        await prefs.setDouble('last_confidence', confidence);
        await prefs.setInt('last_prediction_time', timestamp);

        if (predictedClass.toLowerCase() == 'falling') {
          print('⚠️ FALL DETECTED!');
          await sendFallDetectionNotification();
        }
      } else if (result.containsKey('error')) {
        print('❌ Error from processing isolate: ${result['error']}');
      }
    } catch (e) {
      print('❌ Error handling prediction result: $e');
      print('❌ Stack trace: ${StackTrace.current}');
    }
  }

  // Ensure service is running (called by background task)
  static Future<void> ensureServiceRunning() async {
    if (!_isMonitoring) {
      await startMonitoring();
    }
  }

  // Start monitoring sensors
  static Future<void> startMonitoring() async {
    if (_isMonitoring) return;
    print('🎯 Starting fall detection monitoring');

    _isMonitoring = true;
    _sensorBuffer = [];

    // Make sure the processing isolate is running
    if (_processingIsolate == null || _sendPort == null) {
      await _startProcessingIsolate();
    }

    try {
      // Start collecting sensor data
      _startSensorCollection();
      print('✅ Sensor collection started');

      // Register background task to keep service alive
      await Workmanager().registerPeriodicTask(
        'fall_detection_keeper',
        FALL_DETECTION_TASK,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: true,
        ),
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );
      print('✅ Background task registered');
    } catch (e) {
      print('❌ Error starting monitoring: $e');
      _isMonitoring = false;
    }
  }

  static void _startSensorCollection() {
    print('📱 Setting up sensor listeners');
    print(
        '📊 Gyroscope status: ${_gyroscopeAvailable ? "Available" : "Not available"}');

    // Reset counters and buffers
    _sensorBuffer.clear();
    _lastAccelEvent = null;
    _lastGyroEvent = null;
    _lastReadingTime = 0;
    _gyroscopeReadingsCount = 0;
    _accelerometerReadingsCount = 0;

    // Configure accelerometer to 50Hz if possible
    _accelerometerSubscription = userAccelerometerEvents.listen(
      (UserAccelerometerEvent event) {
        _accelerometerReadingsCount++;
        if (_accelerometerReadingsCount % 50 == 0) {
          print(
              '📊 Accelerometer reading #$_accelerometerReadingsCount: x=${event.x}, y=${event.y}, z=${event.z}');
        }
        _lastAccelEvent = event;
        _tryAddSensorReading();
      },
      onError: (error) {
        print('❌ Accelerometer error: $error');
      },
      cancelOnError: false,
    );

    // Configure gyroscope to match accelerometer rate
    if (_gyroscopeAvailable) {
      print('🔄 Setting up gyroscope listener...');
      _gyroscopeSubscription = gyroscopeEvents.listen(
        (GyroscopeEvent event) {
          _gyroscopeReadingsCount++;
          if (_gyroscopeReadingsCount % 50 == 0) {
            print(
                '📊 Gyroscope reading #$_gyroscopeReadingsCount: x=${event.x}, y=${event.y}, z=${event.z}');
          }
          _lastGyroEvent = event;
          _tryAddSensorReading();
        },
        onError: (error) {
          print('❌ Gyroscope error: $error');
          print('❌ Gyroscope error stack trace: ${StackTrace.current}');
          _gyroscopeAvailable = false;
        },
        cancelOnError: false,
      );
    } else {
      print('⚠️ Gyroscope not available, using zeros for rotation values');
    }

    // Process data every 2 seconds - reduced from the original implementation
    _processingTimer =
        Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!_isMonitoring) {
        print('⚠️ Monitoring stopped, cancelling timer');
        timer.cancel();
        return;
      }

      if (_sensorBuffer.length >= WINDOW_SIZE) {
        // Send data to isolate for processing instead of processing here
        await _sendDataToIsolate();
      }
    });

    print('✅ Sensor listeners and processing timer set up successfully');
  }

  // Send data to isolate for processing
  static Future<void> _sendDataToIsolate() async {
    if (_sendPort == null || _sensorBuffer.length < WINDOW_SIZE) {
      return;
    }

    try {
      // Take a copy of the buffer to avoid modification during processing
      final dataToSend = List<Map<String, double>>.from(
          _sensorBuffer.sublist(_sensorBuffer.length - WINDOW_SIZE));

      // Send the data to the isolate
      _sendPort!.send(dataToSend);

      print('📊 Sent ${dataToSend.length} readings to processing isolate');
    } catch (e) {
      print('❌ Error sending data to isolate: $e');
    }
  }

  static void _tryAddSensorReading() {
    if (_lastAccelEvent == null) {
      return; // Wait for accelerometer reading
    }

    final currentTime = DateTime.now().millisecondsSinceEpoch;

    // Only add a reading if enough time has passed since the last one
    if (currentTime - _lastReadingTime >= SAMPLING_INTERVAL.inMilliseconds) {
      if (_sensorBuffer.length >= WINDOW_SIZE) {
        _sensorBuffer.removeAt(0);
      }

      // Use actual gyroscope values if available, otherwise use zeros
      final gyroX = _gyroscopeAvailable && _lastGyroEvent != null
          ? _lastGyroEvent!.x
          : 0.0;
      final gyroY = _gyroscopeAvailable && _lastGyroEvent != null
          ? _lastGyroEvent!.y
          : 0.0;
      final gyroZ = _gyroscopeAvailable && _lastGyroEvent != null
          ? _lastGyroEvent!.z
          : 0.0;

      final reading = {
        'ax': _lastAccelEvent!.x,
        'ay': _lastAccelEvent!.y,
        'az': _lastAccelEvent!.z,
        'wx': gyroX,
        'wy': gyroY,
        'wz': gyroZ,
        'time': currentTime.toDouble(),
      };

      _sensorBuffer.add(reading);
      _lastReadingTime = currentTime;

      // Log sensor values periodically - reduced logging frequency
      if (_sensorBuffer.length % 100 == 0) {
        print('📊 Current sensor values:');
        print(
            '   Accelerometer: x=${_lastAccelEvent!.x}, y=${_lastAccelEvent!.y}, z=${_lastAccelEvent!.z}');
        print(
            '   Gyroscope: x=$gyroX, y=$gyroY, z=$gyroZ (Available: $_gyroscopeAvailable)');
      }
    }
  }

  // Stop monitoring
  static Future<void> stopMonitoring() async {
    print('🛑 Stopping fall detection monitoring');
    _isMonitoring = false;

    try {
      _accelerometerSubscription?.cancel();
      _gyroscopeSubscription?.cancel();
      _processingTimer?.cancel();
      _sensorBuffer.clear();
      _lastAccelEvent = null;
      _lastGyroEvent = null;
      _lastReadingTime = 0;
      _client.close(); // Close the HTTP client

      // Stop the processing isolate
      await _stopProcessingIsolate();

      await Workmanager().cancelAll();
      print('✅ Fall detection monitoring stopped successfully');
    } catch (e) {
      print('❌ Error stopping monitoring: $e');
    }
  }

  // The original _processSensorData method is replaced by _sendDataToIsolate and _isolateEntryPoint

  // Make the notification method public
  static Future<void> sendFallDetectionNotification() async {
    try {
      print('📱 Sending fall detection notification...');

      // Get current user
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('❌ No user logged in, cannot send fall notification');
        return;
      }

      // Get notification service
      final notiService = NotiService();
      if (!notiService.isInitialized) {
        await notiService.initNotification();
      }

      // Get user data to find guardian
      final userData = await FirebaseManager.getNameAndRole(currentUser.uid);
      final userName = userData['name'] ?? 'Elder';
      final sharedUserEmail = userData['sharedUsers'] ?? '';

      // Show notification to the elder
      await notiService.showNotification(
        id: NotiService.LOCATION_NOTIFICATION_ID_PREFIX + 1,
        title: "Fall Detected!",
        body:
            "The app has detected a fall. Are you okay? If yes, please dismiss this notification.",
        notificationDetails: notiService.missedPillDetails(),
        payload: "fall_detected:${currentUser.uid}",
      );

      // Notify guardian if needed
      if (sharedUserEmail.isNotEmpty) {
        print('📱 Notifying guardian about fall detection...');
        final guardianData =
            await FirebaseManager.getUserByEmail(sharedUserEmail);

        if (guardianData != null) {
          final guardianId = guardianData['id'] ?? '';
          if (guardianId.isNotEmpty) {
            // Send notification directly to guardian
            await notiService.sendFcmNotification(
              userId: guardianId,
              title: "Fall Alert!",
              body: "$userName may have fallen and might need assistance.",
              data: {
                'type': 'fall_alert',
                'elderName': userName,
                'elderId': currentUser.uid,
              },
            );
          }
        }
      }

      print('✅ Fall detection notifications sent successfully');
    } catch (e) {
      print('❌ Error sending fall detection notification: $e');
      print('❌ Stack trace: ${StackTrace.current}');
    }
  }

  static Future<Map<String, dynamic>> getLastPrediction() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastPredictionTime = prefs.getInt('last_prediction_time') ?? 0;
      final timeSinceLastPrediction =
          DateTime.now().millisecondsSinceEpoch - lastPredictionTime;

      // If no prediction in last 5 seconds, consider it stale
      if (timeSinceLastPrediction > 5000) {
        return {
          'activity': 'unknown',
          'confidence': 0.0,
          'is_stale': true,
        };
      }

      return {
        'activity': prefs.getString('last_activity') ?? 'unknown',
        'confidence': prefs.getDouble('last_confidence') ?? 0.0,
        'is_stale': false,
      };
    } catch (e) {
      print('Error getting last prediction: $e');
      return {
        'activity': 'unknown',
        'confidence': 0.0,
        'is_stale': true,
      };
    }
  }

  static bool get isMonitoring => _isMonitoring;
}
