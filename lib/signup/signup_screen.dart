import 'package:amanak/firebase/firebase_manager.dart';
import 'package:amanak/models/user_model.dart';
import 'package:amanak/provider/my_provider.dart';
import 'package:amanak/signup/choose_role.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../home_screen.dart';

class SignupScreen extends StatefulWidget {
  static const String routeName = "SignUpScreen";

  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _signupEmailController = TextEditingController();
  final _signupPasswordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isChecked = false;

  @override
  Widget build(BuildContext context) {
    var provider = Provider.of<MyProvider>(context,listen: false);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actionsIconTheme: IconThemeData(color: Color(0xFF101623)),
        centerTitle: true,
        title: Text(
          "Sign Up",
          style: Theme.of(context)
              .textTheme
              .titleMedium!
              .copyWith(color: Color(0xFF101623)),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: 20,),
                // Sign Up Name
                TextField(
                  controller: _nameController,
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
                    hintText: "Enter your name",
                    hintStyle: Theme.of(context)
                        .textTheme
                        .titleSmall!
                        .copyWith(color: Color(0xFFA1A8B0)),
                    prefixIcon: Icon(Icons.person_2_outlined),
                    prefixIconColor: Theme.of(context).primaryColor,
                  ),
                ),
                SizedBox(
                  height: 16,
                ),
                //Sign up name
                TextField(
                  controller: _signupEmailController,
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
                    prefixIconColor: Theme.of(context).primaryColor,
                  ),
                ),
                SizedBox(
                  height: 16,
                ),
                // Sign up password
                TextField(
                  controller: _signupPasswordController,
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
                    prefixIconColor: Theme.of(context).primaryColor,
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
                    suffixIconColor: Theme.of(context).primaryColor,
                  ),
                ),
                SizedBox(
                  height: 16,
                ),
                // Terms of Service
                Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Checkbox(
                        value: _isChecked,
                        side: BorderSide(color: Color(0xFFD3D6DA)),
                        checkColor:Theme.of(context).primaryColor ,
                        activeColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                        onChanged:
                          (value) {
                          setState(() {
                            _isChecked = value!;
                          });
                      },

                      ),
                    ),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          style: TextStyle(color: Color(0xFF3B4453)),
                          children: [
                            TextSpan(text: "I agree to the Amanak "),
                            TextSpan(
                              text: "Terms of Service ",
                              style: TextStyle(color: Theme.of(context).primaryColor),
                            ),
                            TextSpan(text: "and "),
                            TextSpan(
                              text: "Privacy Policy",
                              style: TextStyle(color: Theme.of(context).primaryColor),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                        softWrap: true,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16,),
                ElevatedButton(
                  onPressed: () async {
                    final email = _signupEmailController.text.trim();
                    final password = _signupPasswordController.text.trim();
                    final name = _nameController.text.trim();

                    String? emailValidationResult = _validateEmail(email);
                    String? passwordValidationResult =
                        _validatePassword(password);

                    if (emailValidationResult != null ||
                        passwordValidationResult != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                'Please enter a valid email and password')),
                      );
                      return;
                    }

                    try {
                      final credential = await FirebaseAuth.instance
                          .createUserWithEmailAndPassword(
                        email: email,
                        password: password,
                      );
                      var userID = FirebaseAuth.instance.currentUser!.uid;
                      UserModel user = UserModel(name: name,
                          email: email , id: userID);
                      await FirebaseManager.setUser(user).onError((error, stackTrace) {
                        SnackBar(content: Text("$error"),);
                      },);
                      var provider = Provider.of<MyProvider>(context,listen: false);
                      provider.setUserModel(user.id, user.name, user.email);
                      Navigator.pushNamed(context, ChooseRoleScreen.routeName);
                    } on FirebaseAuthException catch (e) {
                      if (e.code == 'weak-password') {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                                  Text('The password provided is too weak.')),
                        );
                      } else if (e.code == 'email-already-in-use') {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'The account already exists for that email.')),
                        );
                      }
                    } catch (e) {
                      print(e);
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
                    "Next",
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
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
