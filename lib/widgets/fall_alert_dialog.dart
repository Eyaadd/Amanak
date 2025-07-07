import 'package:flutter/material.dart';
import 'package:amanak/provider/fall_detection_provider.dart';
import 'package:provider/provider.dart';

class FallAlertDialog extends StatefulWidget {
  final VoidCallback onConfirm;
  final VoidCallback onTimeout;

  const FallAlertDialog({
    Key? key,
    required this.onConfirm,
    required this.onTimeout,
  }) : super(key: key);

  @override
  State<FallAlertDialog> createState() => _FallAlertDialogState();
}

class _FallAlertDialogState extends State<FallAlertDialog> {
  late int _countdown;
  static const int _totalTime = 10; // 10 seconds countdown

  @override
  void initState() {
    super.initState();
    _countdown = _totalTime;
    _startCountdown();
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _countdown--;
        });
        if (_countdown > 0) {
          _startCountdown();
        } else {
          widget.onTimeout();
          Navigator.of(context).pop();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent dismissing by back button
      child: AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red[700], size: 28),
            const SizedBox(width: 8),
            const Text('Fall Detected!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Are you okay?',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 16),
            Text(
              'Notifying guardian in $_countdown seconds...',
              style: TextStyle(
                color: Colors.red[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              widget.onConfirm();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              minimumSize: const Size(120, 45),
            ),
            child: const Text(
              'I\'m Okay',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
      ),
    );
  }
}
