import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:sensors_plus/sensors_plus.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const String API_URL = 'https://fall-detection-production-02fa.up.railway.app/predict/';
  static const String FALL_DETECTION_TASK = 'fall_detection_task';
  static const int SAMPLING_RATE = 50; // 50Hz
  static const int WINDOW_SIZE = 100; // 100 samples per window
  static const Duration SAMPLING_INTERVAL = Duration(milliseconds: 20); // 1000ms/50Hz = 20ms
  
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
  static const int SENSOR_SYNC_THRESHOLD = 100; // 100ms threshold for sensor synchronization
  static bool _gyroscopeAvailable = false;
  static int _gyroscopeReadingsCount = 0;
  static int _accelerometerReadingsCount = 0;

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
          print('✅ Received gyroscope event: x=${event.x}, y=${event.y}, z=${event.z}');
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

      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: true
      );
      print('✅ Workmanager initialized successfully');
      _isInitialized = true;
    } catch (e) {
      print('❌ Error initializing service: $e');
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
    print('📊 Gyroscope status: ${_gyroscopeAvailable ? "Available" : "Not available"}');
    
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
          print('📊 Accelerometer reading #$_accelerometerReadingsCount: x=${event.x}, y=${event.y}, z=${event.z}');
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
            print('📊 Gyroscope reading #$_gyroscopeReadingsCount: x=${event.x}, y=${event.y}, z=${event.z}');
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

    // Process data every 2 seconds
    _processingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!_isMonitoring) {
        print('⚠️ Monitoring stopped, cancelling timer');
        timer.cancel();
        return;
      }

      print('📊 Sensor stats:');
      print('   - Accelerometer readings: $_accelerometerReadingsCount');
      print('   - Gyroscope readings: $_gyroscopeReadingsCount');
      print('   - Buffer size: ${_sensorBuffer.length}');

      if (_sensorBuffer.length >= WINDOW_SIZE) {
        print('📊 Processing ${_sensorBuffer.length} sensor readings');
        await _processSensorData();
      } else {
        print('⚠️ Not enough sensor data yet. Current buffer size: ${_sensorBuffer.length}');
      }
    });

    print('✅ Sensor listeners and processing timer set up successfully');
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
      final gyroX = _gyroscopeAvailable && _lastGyroEvent != null ? _lastGyroEvent!.x : 0.0;
      final gyroY = _gyroscopeAvailable && _lastGyroEvent != null ? _lastGyroEvent!.y : 0.0;
      final gyroZ = _gyroscopeAvailable && _lastGyroEvent != null ? _lastGyroEvent!.z : 0.0;

      final reading = {
        'ax': _lastAccelEvent!.x,
        'ay': _lastAccelEvent!.y,
        'az': _lastAccelEvent!.z,
        'wx': gyroX,
        'wy': gyroY,
        'wz': gyroZ,
        'timestamp': currentTime.toDouble(),
      };

      _sensorBuffer.add(reading);
      _lastReadingTime = currentTime;

      // Log sensor values periodically
      if (_sensorBuffer.length % 50 == 0) {
        print('📊 Current sensor values:');
        print('   Accelerometer: x=${_lastAccelEvent!.x}, y=${_lastAccelEvent!.y}, z=${_lastAccelEvent!.z}');
        print('   Gyroscope: x=$gyroX, y=$gyroY, z=$gyroZ (Available: $_gyroscopeAvailable)');
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

      await Workmanager().cancelAll();
      print('✅ Fall detection monitoring stopped successfully');
    } catch (e) {
      print('❌ Error stopping monitoring: $e');
    }
  }

  // Process sensor data and send to API
  static Future<void> _processSensorData() async {
    if (!_isMonitoring || _sensorBuffer.length < WINDOW_SIZE) return;

    try {
      // Take the last 100 readings
      final dataToSend = _sensorBuffer.sublist(
        _sensorBuffer.length - WINDOW_SIZE
      );

      print('🔄 Sending data to fall detection API...');
      print('📊 Sample count: ${dataToSend.length}');
      print('📍 First reading: ${dataToSend.first}');
      print('📍 Last reading: ${dataToSend.last}');

      // Create the request body
      final body = jsonEncode({
        'sensor_data': dataToSend,
      });

      // Create a client that follows redirects
      final client = http.Client();
      try {
        var currentUrl = API_URL;
        var maxRedirects = 5;
        var redirectCount = 0;
        http.Response? response;

        while (redirectCount < maxRedirects) {
          response = await client.post(
            Uri.parse(currentUrl),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: body,
          ).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException('API request timed out');
            },
          );

          print('📡 API Response Status: ${response.statusCode}');
          print('📡 API Response Headers: ${response.headers}');

          if (response.statusCode >= 200 && response.statusCode < 300) {
            break;
          } else if (response.statusCode >= 300 && response.statusCode < 400) {
            final location = response.headers['location'];
            if (location == null) {
              throw Exception('Redirect location not found');
            }
            currentUrl = location;
            redirectCount++;
            print('🔄 Following redirect to: $currentUrl');
          } else {
            throw Exception('API Error: Status ${response.statusCode}');
          }
        }

        if (response == null || redirectCount >= maxRedirects) {
          throw Exception('Too many redirects');
        }

        if (response.statusCode >= 200 && response.statusCode < 300) {
          if (response.body.isNotEmpty) {
            final data = jsonDecode(response.body);
            final predictedClass = data['predicted_class'] as String;
            final confidence = (data['confidence'] as num).toDouble();

            print('🎯 Prediction Result:');
            print('   - Activity: $predictedClass');
            print('   - Confidence: ${(confidence * 100).toStringAsFixed(1)}%');

            // Save prediction result
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('last_activity', predictedClass);
            await prefs.setDouble('last_confidence', confidence);
            await prefs.setInt('last_prediction_time', DateTime.now().millisecondsSinceEpoch);

            if (predictedClass.toLowerCase() == 'falling') {
              print('⚠️ FALL DETECTED!');
              await _sendFallDetectionNotification();
            }
          } else {
            print('⚠️ API returned empty response body');
          }
        } else {
          print('❌ API Error: Status ${response.statusCode}');
          print('❌ Error Response: ${response.body}');
          print('❌ Response Headers: ${response.headers}');
        }
      } finally {
        client.close();
      }
    } catch (e) {
      print('❌ Error processing sensor data: $e');
      print('❌ Stack trace: ${StackTrace.current}');
    }
  }

  static Future<void> _sendFallDetectionNotification() async {
    // Implement notification logic using your existing notification service
  }

  static Future<Map<String, dynamic>> getLastPrediction() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastPredictionTime = prefs.getInt('last_prediction_time') ?? 0;
      final timeSinceLastPrediction = DateTime.now().millisecondsSinceEpoch - lastPredictionTime;

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