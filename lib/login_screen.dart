import 'package:amanak/home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  static const String routeName = "LoginScreen";

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _loginEmailController = TextEditingController();

  final _loginPasswordController = TextEditingController();

  final _signupEmailController = TextEditingController();

  final _signupPasswordController = TextEditingController();

  bool _isPasswordVisible = false;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              // Header Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                child: Container(
                  width: double.infinity,

                  height: 200,
                  color: Colors.white, // Set background color for all children
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Welcome To Amanak",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "Login or Sign up to access your account",
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Tab Bar Section
              TabBar(
                indicator: BoxDecoration(
                  color: Color(0x1A00664F), // Background color with 10% opacity
                  borderRadius: BorderRadius.circular(8), // Optional: adds rounded corners
                ),
                indicatorSize: TabBarIndicatorSize.tab, // Makes the indicator span the full tab width
                labelColor: Colors.black,
                unselectedLabelColor: Colors.grey,
                labelStyle: TextStyle(fontWeight: FontWeight.bold),
                tabs: [
                  Tab(text: "Login"),
                  Tab(text: "Sign Up"),
                ],
              ),


              Expanded(
                child: Container(
                  color: Color(0x1A00664F),
                  child: TabBarView(

                    children: [
                      // Login Tab
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(height: 16),
                            SocialLoginButton(
                              icon: Icons.g_mobiledata,
                              text: "Login with Google",
                            ),
                            SizedBox(height: 16),
                            SocialLoginButton(

                              icon: Icons.apple,
                              text: "Login with Apple",
                            ),
                            SizedBox(height: 16),
                            Divider(thickness: 1, color: Colors.grey.shade300),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                "or continue with email",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            TextField(
                              controller: _loginEmailController,
                              decoration: InputDecoration(
                                fillColor: Colors.white,
                                labelText: "Email Address",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                            ),
                            SizedBox(height: 16),
                            TextField(
                              controller: _loginPasswordController,
                              obscureText: _isPasswordVisible,
                              decoration: InputDecoration(
                                labelText: "Password",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                prefixIcon: Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isPasswordVisible = !_isPasswordVisible;
                                    });
                                  },
                                ),
                              ),
                            ),
                            SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  // Forgot password logic
                                },
                                child: Text(
                                  "Forgot password?",
                                  style: TextStyle(color: Colors.teal),
                                ),
                              ),
                            ),
                            SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () async {
                              final email = _loginEmailController.text.trim();
                              final password = _loginPasswordController.text.trim();

                              if (_validateEmail(email) != null || _validatePassword(password) != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Please enter valid email and password')),
                                );
                                return;
                              }

                              try {
                                UserCredential userCredential = await FirebaseAuth.instance
                                    .signInWithEmailAndPassword(email: email, password: password);
                                Navigator.popAndPushNamed(context, HomeScreen.routeName);
                              } on FirebaseAuthException catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.message ?? 'Login failed')),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                              minimumSize: Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              "Login",
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                          SizedBox(height: 16),
                            Text(
                              "By signing in with an account, you agree to SO's Terms of Service and Privacy Policy.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(height: 16),
                            SocialLoginButton(
                              icon: Icons.g_mobiledata,
                              text: "Sign Up with Google",
                            ),
                            SizedBox(height: 16),
                            SocialLoginButton(
                              icon: Icons.apple,
                              text: "Sign Up with Apple",
                            ),
                            SizedBox(height: 16),
                            Divider(thickness: 1, color: Colors.grey.shade300),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                "or continue with email",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            TextField(
                              controller: _signupEmailController,
                              decoration: InputDecoration(
                                fillColor: Colors.white,
                                labelText: "Email Address",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                            ),
                            SizedBox(height: 16),
                            TextField(
                              controller: _signupPasswordController,
                              obscureText: !_isPasswordVisible,
                              decoration: InputDecoration(
                                labelText: "Password",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                prefixIcon: Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isPasswordVisible = !_isPasswordVisible;
                                    });
                                  },
                                ),
                              ),
                            ),
                            SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                            ),
                            SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () async {
                                final email = _signupEmailController.text.trim();
                                final password = _signupPasswordController.text.trim();

                                // Validate the email and password before proceeding
                                String? emailValidationResult = _validateEmail(email);
                                String? passwordValidationResult = _validatePassword(password);

                                if (emailValidationResult != null || passwordValidationResult != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Please enter a valid email and password')),
                                  );
                                  return;
                                }

                                try {
                                  final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
                                    email: email,
                                    password: password,
                                  );
                                  Navigator.popAndPushNamed(context, HomeScreen.routeName);
                                } on FirebaseAuthException catch (e) {
                                  if (e.code == 'weak-password') {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('The password provided is too weak.')),
                                    );
                                  } else if (e.code == 'email-already-in-use') {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('The account already exists for that email.')),
                                    );
                                  }
                                } catch (e) {
                                  print(e);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                                minimumSize: Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                "Sign Up",
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              "By signing up with an account, you agree to SO's Terms of Service and Privacy Policy.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),

                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SocialLoginButton extends StatelessWidget {
  final IconData icon;
  final String text;

  SocialLoginButton({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () {
        // Social login logic
      },
      icon: Icon(
        icon,
        color: Colors.black,
        size: 24,
      ),
      label: Text(
        text,
        style: TextStyle(
          fontSize: 16,
          color: Colors.black,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey.shade200,
        minimumSize: Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 0,
      ),
    );
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