import 'package:flutter/material.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  static const String routeName = "LoginScreen";

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _signUpEmailController = TextEditingController();
  final _signUpPasswordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // Two tabs: Login and Sign Up
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false, // Remove back button
          title: Text("Welcome To Amanak"),
          bottom: TabBar(
            tabs: [
              Tab(text: "Login"),
              Tab(text: "Sign Up"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Login Form
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: "Email Address",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: "Password",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Navigate to HomeScreen
                      Navigator.pushReplacementNamed(context, HomeScreen.routeName);
                    },
                    child: Text("Login"),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 50), // Full-width button
                    ),
                  ),
                  SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      // Forgot password logic
                    },
                    child: Text("Forgot Password?"),
                  ),
                ],
              ),
            ),

            // Sign Up Form
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextField(
                    controller: _signUpEmailController,
                    decoration: InputDecoration(
                      labelText: "Email Address",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _signUpPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: "Password",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Handle sign-up logic
                      Navigator.pushReplacementNamed(context, HomeScreen.routeName);
                    },
                    child: Text("Sign Up"),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 50), // Full-width button
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
