import 'package:amanak/home_screen.dart';
import 'package:amanak/signup/signup_screen.dart';
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
  bool _isPasswordVisible = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(
                  height: 12,
                ),
                Text(
                  "Login",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(
                  height: 44,
                ),
                TextField(
                  controller: _loginEmailController,
                  decoration: InputDecoration(
                    focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFA1A8B0)),
                        borderRadius: BorderRadius.circular(24)),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFE5E7EB)),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    filled: true,
                    fillColor: Color(0xFFF9FAFB),
                    hintText: "Enter your email",
                    hintStyle: Theme.of(context)
                        .textTheme
                        .titleSmall!
                        .copyWith(color: Color(0xFFA1A8B0)),
                    prefixIcon: Icon(Icons.email_outlined),
                    prefixIconColor: Color(0xFFA1A8B0),
                  ),
                ),
                SizedBox(
                  height: 16,
                ),
                TextField(
                  controller: _loginPasswordController,
                  obscureText: _isPasswordVisible,
                  decoration: InputDecoration(
                    hintText: "Enter Your Password",
                    hintStyle: Theme.of(context)
                        .textTheme
                        .titleSmall!
                        .copyWith(color: Color(0xFFA1A8B0)),
                    filled: true,
                    fillColor: Color(0xFFF9FAFB),
                    focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFA1A8B0)),
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
                      onPressed: () {
                        // Forgot password logic
                      },
                      child: Text(
                        "Forgot password?",
                        style: TextStyle(color: Theme.of(context).primaryColor),
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: 32,
                ),
                ElevatedButton(
                  onPressed: () async {
                    final email = _loginEmailController.text.trim();
                    final password = _loginPasswordController.text.trim();

                    if (_validateEmail(email) != null ||
                        _validatePassword(password) != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content:
                                Text('Please enter valid email and password')),
                      );
                      return;
                    }

                    try {
                      UserCredential userCredential = await FirebaseAuth
                          .instance
                          .signInWithEmailAndPassword(
                              email: email, password: password);
                      Navigator.popAndPushNamed(context, HomeScreen.routeName);
                    } on FirebaseAuthException catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.message ?? 'Login failed')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: Size(327, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32),
                    ),
                  ),
                  child: Text(
                    "Login",
                    style: Theme.of(context).textTheme.titleSmall!.copyWith(
                        fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
                SizedBox(
                  height: 24,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall!
                          .copyWith(color: Color(0xFF717784)),
                    ),
                    InkWell(
                      onTap: () => Navigator.pushNamed(context , SignupScreen.routeName),
                    child: Text("Sign Up",
                      style: Theme.of(context).textTheme.titleSmall,),),
                  ],
                ),
                SizedBox(height: 45,),
                Row(
                  children: [
                    Expanded(child: Divider(thickness: 1,endIndent: 10  ,)),
                    Text("OR",
                    style: Theme.of(context).textTheme.titleSmall!.copyWith(color: Color(0xFFA1A8B0)),),
                    Expanded(child: Divider(thickness: 1,
                      indent: 10,))
                  ],
                ),
                SizedBox(height: 24,),
                SizedBox(height: 16),
                // Google Log in
                SocialLoginButton(
                  icon: Icons.g_mobiledata,
                  text: "Sign in with Google",
                ),
                SizedBox(height: 16),
                //Apple Log in
                SocialLoginButton(
                  icon: Icons.apple,
                  text: "Sign in with Apple",
                ),
                SizedBox(height: 16),
                SocialLoginButton(
                  icon: Icons.facebook,
                  text: "Sign in with Facebook",
                ),
              ],
            ),
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
        backgroundColor: Colors.white,
        minimumSize: Size(327,56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32),
          side: BorderSide(color: Color(0xFFE5E7EB))
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
