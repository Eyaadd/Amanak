import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider/fall_detection_provider.dart';
import '../firebase/firebase_manager.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FallDetectionTab extends StatefulWidget {
  static const String routeName = '/fall-detection';

  const FallDetectionTab({super.key});

  @override
  State<FallDetectionTab> createState() => _FallDetectionTabState();
}

class _FallDetectionTabState extends State<FallDetectionTab> {
  @override
  void initState() {
    super.initState();
    _initializeFallDetection();
  }

  Future<void> _initializeFallDetection() async {
    final userData = await FirebaseManager.getNameAndRole(FirebaseAuth.instance.currentUser!.uid);
    final userRole = userData['role'] ?? '';
    
    if (userRole.toLowerCase() == 'elder') {
      print('👤 Elder user detected in FallDetectionTab, initializing monitoring...');
      final fallDetectionProvider = Provider.of<FallDetectionProvider>(context, listen: false);
      await fallDetectionProvider.startMonitoring();
      print('✅ Fall detection monitoring initialized');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FallDetectionProvider>(
      builder: (context, fallDetectionProvider, child) {
        final isMonitoring = fallDetectionProvider.isMonitoring;
        final currentActivity = fallDetectionProvider.currentActivity;
        final confidence = fallDetectionProvider.confidence;
        final isFallDetected = fallDetectionProvider.isFallDetected;
        final isStale = fallDetectionProvider.isStale;

        return Scaffold(
          appBar: AppBar(
            title: Text('Fall Detection Monitor'),
            centerTitle: true,
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Card
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isFallDetected 
                      ? Colors.red.shade100 
                      : isStale 
                        ? Colors.grey.shade100
                        : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isFallDetected 
                        ? Colors.red 
                        : isStale
                          ? Colors.grey
                          : Colors.green,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isFallDetected 
                              ? Icons.warning 
                              : isStale
                                ? Icons.sync_problem
                                : Icons.check_circle,
                            color: isFallDetected 
                              ? Colors.red 
                              : isStale
                                ? Colors.grey
                                : Colors.green,
                            size: 24,
                          ),
                          SizedBox(width: 8),
                          Text(
                            isFallDetected 
                              ? 'Fall Detected!' 
                              : isStale
                                ? 'Monitoring Status Unknown'
                                : 'Activity Monitoring',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isFallDetected 
                                ? Colors.red 
                                : isStale
                                  ? Colors.grey
                                  : Colors.black,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Current Activity: ${currentActivity.toUpperCase()}',
                        style: TextStyle(
                          fontSize: 16,
                          color: isStale ? Colors.grey : Colors.black,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Confidence: ${(confidence * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 16,
                          color: isStale ? Colors.grey : Colors.black,
                        ),
                      ),
                      if (isStale) ...[
                        SizedBox(height: 8),
                        Text(
                          'Last update more than 5 seconds ago',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                      if (isFallDetected) ...[
                        SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              fallDetectionProvider.clearFallDetection();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              'I\'m OK - Clear Alert',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 24),
                
                // Monitoring Toggle
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Monitoring Settings',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Enable Fall Detection',
                            style: TextStyle(fontSize: 16),
                          ),
                          Switch(
                            value: isMonitoring,
                            onChanged: (value) {
                              if (value) {
                                fallDetectionProvider.startMonitoring();
                              } else {
                                fallDetectionProvider.stopMonitoring();
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
