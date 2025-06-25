import 'package:amanak/firebase/firebase_manager.dart';
import 'package:amanak/home_screen.dart';
import 'package:amanak/models/user_model.dart';
import 'package:amanak/screens/language_selection_screen.dart';
import 'package:amanak/signup/signup_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'l10n/app_localizations.dart';

class LoginScreen extends StatefulWidget {
  static const String routeName = "LoginScreen";

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _forgotPasswordEmailController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _isResetLoading = false;

  @override
  void initState() {
    super.initState();
    // Check if user is already logged in on screen init
    _checkCurrentUser();
  }

  void _checkCurrentUser() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      // User is already logged in, navigate to home screen
      Future.microtask(() {
        Navigator.of(context).pushReplacementNamed(HomeScreen.routeName);
      });
    }
  }

  // Show forgot password dialog
  void _showForgotPasswordDialog() {
    // Pre-fill with email from login field if available
    _forgotPasswordEmailController.text = _loginEmailController.text.trim();

    showDialog(
      context: context,
      builder: (context) {
        final localizations = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(localizations.forgotPassword),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter your email address to receive a password reset link',
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _forgotPasswordEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: localizations.email,
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(localizations.cancel),
            ),
            _isResetLoading
                ? Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  )
                : ElevatedButton(
                    onPressed: () => _sendPasswordResetEmail(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                    ),
                    child: Text('Reset Password',
                        style: TextStyle(color: Colors.white)),
                  ),
          ],
        );
      },
    );
  }

  // Send password reset email
  Future<void> _sendPasswordResetEmail(BuildContext dialogContext) async {
    final email = _forgotPasswordEmailController.text.trim();

    // Validate email
    if (_validateEmail(email) != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid email address')),
      );
      return;
    }

    // Set loading state
    setState(() {
      _isResetLoading = true;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      // Close dialog and show success message
      Navigator.pop(dialogContext);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password reset link sent to $email'),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseAuthException catch (e) {
      String errorMessage;

      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found with this email address';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is not valid';
          break;
        default:
          errorMessage = e.message ?? 'An error occurred. Please try again';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isResetLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: 48),
                // Amanak Logo
                Center(
                  child: Image.asset(
                    'assets/images/amanaklogo.png',
                    height: 170,
                    fit: BoxFit.contain,
                  ),
                ),
                SizedBox(height: 20),
                // Welcome message
                Text(
                  localizations.welcomeMessage,
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 32),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 28),
                    child: Column(
                      children: [
                        Text(
                          localizations.login,
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 32),
                        TextField(
                          cursorColor: Theme.of(context).primaryColor,
                          controller: _loginEmailController,
                          decoration: InputDecoration(
                            focusedBorder: OutlineInputBorder(
                                borderSide:
                                    BorderSide(color: Color(0xFFA1A8B0)),
                                borderRadius: BorderRadius.circular(24)),
                            border: OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFFE5E7EB)),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            filled: true,
                            fillColor: Color(0xFFF9FAFB),
                            hintText: localizations.email,
                            hintStyle: Theme.of(context)
                                .textTheme
                                .titleSmall!
                                .copyWith(color: Color(0xFFA1A8B0)),
                            prefixIcon: Icon(Icons.email_outlined),
                            prefixIconColor: Color(0xFFA1A8B0),
                          ),
                        ),
                        SizedBox(height: 16),
                        TextField(
                          cursorColor: Theme.of(context).primaryColor,
                          controller: _loginPasswordController,
                          obscureText: !_isPasswordVisible,
                          decoration: InputDecoration(
                            hintText: localizations.password,
                            hintStyle: Theme.of(context)
                                .textTheme
                                .titleSmall!
                                .copyWith(color: Color(0xFFA1A8B0)),
                            filled: true,
                            fillColor: Color(0xFFF9FAFB),
                            focusedBorder: OutlineInputBorder(
                                borderSide:
                                    BorderSide(color: Color(0xFFA1A8B0)),
                                borderRadius: BorderRadius.circular(24)),
                            border: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: Color(0xFFE5E7EB),
                              ),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            prefixIcon: Icon(Icons.lock_outline),
                            prefixIconColor: Color(0xFFA1A8B0),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isPasswordVisible = !_isPasswordVisible;
                                });
                              },
                            ),
                            suffixIconColor: Color(0xFFA1A8B0),
                          ),
                        ),
                        SizedBox(
                          height: 8,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: _showForgotPasswordDialog,
                              child: Text(
                                localizations.forgotPassword,
                                style: TextStyle(
                                    color: Theme.of(context).primaryColor),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(
                          height: 32,
                        ),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            minimumSize: Size(327, 56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(32),
                            ),
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  localizations.login,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall!
                                      .copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white),
                                ),
                        ),
                        SizedBox(
                          height: 24,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              localizations.dontHaveAccount,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall!
                                  .copyWith(color: Color(0xFF717784)),
                            ),
                            InkWell(
                              onTap: () => Navigator.pushNamed(
                                  context, SignupScreen.routeName),
                              child: Text(
                                localizations.signUp,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    final email = _loginEmailController.text.trim();
    final password = _loginPasswordController.text.trim();

    if (_validateEmail(email) != null || _validatePassword(password) != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter valid email and password')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Sign in with email and password
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Get current user ID
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        // Get the user's current timezone
        final currentTimezone = await FlutterTimezone.getLocalTimezone();

        // Get user data from Firestore
        final userData = await FirebaseManager.getNameAndRole(currentUser.uid);

        // If timezone has changed or is not set, update it
        if (userData['timezone'] != currentTimezone) {
          // Get the full user model
          final userCollection = FirebaseManager.getUsersCollection();
          final userDoc = await userCollection.doc(currentUser.uid).get();

          if (userDoc.exists) {
            final userModel = userDoc.data()!;
            // Update the timezone
            final updatedUser = UserModel(
              id: userModel.id,
              name: userModel.name,
              email: userModel.email,
              role: userModel.role,
              age: userModel.age,
              height: userModel.height,
              sharedUsers: userModel.sharedUsers,
              latitude: userModel.latitude,
              longitude: userModel.longitude,
              lastLocationUpdate: userModel.lastLocationUpdate,
              timezone: currentTimezone,
            );

            // Save the updated user model
            await FirebaseManager.updateEvent(updatedUser);
          }
        }
      }

      // Navigate to language selection screen after login
      Navigator.of(context)
          .pushReplacementNamed(LanguageSelectionScreen.routeName);
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Login failed')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _forgotPasswordEmailController.dispose();
    super.dispose();
  }
}

String? _validateEmail(String email) {
  final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[a-zA-Z]{2,}$');
  if (!regex.hasMatch(email)) return 'Enter a valid email address';
  return null;
}

String? _validatePassword(String password) {
  if (password.length < 6) return 'Password must be at least 6 characters';
  return null;
}
