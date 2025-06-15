import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:amanak/firebase/firebase_manager.dart';
import 'dart:async';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _setupPeriodicChecks();
  }

  // Set up periodic checks for missed pills
  void _setupPeriodicChecks() {
    // Check for missed pills every 15 minutes
    Timer.periodic(Duration(minutes: 15), (timer) {
      if (mounted) {
        _checkForMissedPills();
      }
    });

    // Also check immediately on startup
    _checkForMissedPills();
  }

  // Check for missed pills
  Future<void> _checkForMissedPills() async {
    try {
      await FirebaseManager.checkForMissedPills();
    } catch (e) {
      print('Error checking for missed pills: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Implementation of build method
    return Scaffold(
      body: Center(
        child: Text('Home Screen'),
      ),
    );
  }
}
