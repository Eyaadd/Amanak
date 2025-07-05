import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:amanak/models/user_model.dart';
import 'package:amanak/firebase/firebase_manager.dart';
import 'package:amanak/services/fcm_service.dart';
import 'package:amanak/widgets/success_dialog.dart';
import 'package:amanak/login_screen.dart';

class GuardianUserAssignment extends StatefulWidget {
  static const routeName = "GuardianUserAssignment";
  final UserModel user;

  const GuardianUserAssignment({super.key, required this.user});

  @override
  State<GuardianUserAssignment> createState() => _GuardianUserAssignmentState();
}

class _GuardianUserAssignmentState extends State<GuardianUserAssignment> {
  final TextEditingController _userEmailController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<bool> _validateUserEmail(String email) async {
    try {
      // Check if user exists in Firestore
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .where('role', isEqualTo: 'user')
          .get();

      if (querySnapshot.docs.isEmpty) {
        setState(() {
          _errorMessage =
              'No user found with this email or the user is not a regular user';
        });
        return false;
      }

      // Check if user is already linked to another guardian
      final userData = querySnapshot.docs.first.data();
      if (userData['sharedUsers'] != null &&
          userData['sharedUsers'].toString().isNotEmpty) {
        setState(() {
          _errorMessage = 'This user is already linked to another guardian';
        });
        return false;
      }

      return true;
    } catch (e) {
      setState(() {
        _errorMessage = 'Error validating user email';
      });
      return false;
    }
  }

  Future<void> _assignUser() async {
    final userEmail = _userEmailController.text.trim();

    if (userEmail.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a user email';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Validate the user email
      final isValid = await _validateUserEmail(userEmail);
      if (!isValid) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Update the guardian's user model with the shared user email
      final updatedUser = UserModel(
        name: widget.user.name,
        email: widget.user.email,
        id: widget.user.id,
        role: widget.user.role,
        sharedUsers: userEmail,
      );

      // Update in Firestore
      await FirebaseManager.updateEvent(updatedUser);

      // Link the user with the guardian
      await FirebaseManager.linkUser(
        widget.user.id,
        userEmail,
        widget.user.email,
      );

      // Initialize FCM token
      final fcmService = FCMService();
      await fcmService.initialize();

      // Show success dialog and navigate to login
      if (mounted) {
        showSuccessDialog(context);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error assigning user: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actionsIconTheme: const IconThemeData(color: Color(0xFF101623)),
        centerTitle: true,
        title: Text(
          "Assign User",
          style: Theme.of(context)
              .textTheme
              .titleMedium!
              .copyWith(color: const Color(0xFF101623)),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                "As a guardian, you need to assign yourself to a user",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                "Please enter the email of the user you want to monitor",
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium!
                    .copyWith(color: const Color(0xFF717784)),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _userEmailController,
                decoration: InputDecoration(
                  hintText: "Enter user's email",
                  errorText: _errorMessage,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _assignUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Complete Registration"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _userEmailController.dispose();
    super.dispose();
  }
}
