import 'package:amanak/firebase/firebase_manager.dart';
import 'package:amanak/home_screen.dart';
import 'package:amanak/models/user_model.dart';
import 'package:amanak/provider/my_provider.dart';
import 'package:amanak/services/fcm_service.dart';
import 'package:amanak/signup/guardian_user_assignment.dart';
import 'package:amanak/widgets/success_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ChooseRoleScreen extends StatefulWidget {
  static const routeName = "ChooseRole";

  ChooseRoleScreen({super.key});

  @override
  State<ChooseRoleScreen> createState() => _ChooseRoleScreenState();
}

class _ChooseRoleScreenState extends State<ChooseRoleScreen> {
  bool isChecked = false;

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    var provider = Provider.of<MyProvider>(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actionsIconTheme: IconThemeData(color: Color(0xFF101623)),
        centerTitle: true,
        title: Text(
          "Choose Your Role",
          style: Theme.of(context)
              .textTheme
              .titleMedium!
              .copyWith(color: Color(0xFF101623)),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
          child: Column(
            children: [
              // Use Flexible to give proper space before buttons
              Flexible(
                flex: 2,
                child: Container(), // Empty space
              ),

              // User button
              _buildRoleButton(
                context: context,
                isSelected: isChecked,
                roleName: "User",
                imagePath: "assets/images/user.png",
                onPressed: () {
                  setState(() {
                    provider.setRole("user");
                    isChecked = true;
                  });
                },
              ),

              SizedBox(height: screenHeight * 0.025),

              // Guardian button
              _buildRoleButton(
                context: context,
                isSelected: !isChecked,
                roleName: "Guardian",
                imagePath: "assets/images/guardian.png",
                onPressed: () {
                  setState(() {
                    provider.setRole("Guardian");
                    isChecked = false;
                  });
                },
              ),

              // Use Flexible to give proper space before continue button
              Flexible(
                flex: 4,
                child: Container(), // Empty space
              ),

              // Continue button
              Padding(
                padding: EdgeInsets.only(bottom: screenHeight * 0.03),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      UserModel user = UserModel(
                          name: provider.userName,
                          email: provider.userEmail,
                          id: provider.userID,
                          role: provider.chosedRole);

                      if (provider.chosedRole == "Guardian") {
                        // For guardians, navigate to user assignment screen
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                GuardianUserAssignment(user: user),
                          ),
                        );
                      } else {
                        // For regular users, complete registration
                        await FirebaseManager.updateEvent(user).onError(
                          (error, stackTrace) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("$error")),
                            );
                            return null;
                          },
                        ).then(
                          (value) async {
                            // Initialize FCM token
                            final fcmService = FCMService();
                            await fcmService.initialize();

                            showSuccessDialog(context);
                          },
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding:
                          EdgeInsets.symmetric(vertical: screenHeight * 0.018),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32),
                      ),
                    ),
                    child: Text(
                      "Continue",
                      style: TextStyle(fontSize: screenWidth * 0.042),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to build role selection buttons
  Widget _buildRoleButton({
    required BuildContext context,
    required bool isSelected,
    required String roleName,
    required String imagePath,
    required VoidCallback onPressed,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return SizedBox(
      width: double.infinity,
      height: screenHeight * 0.1,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isSelected ? Theme.of(context).primaryColor : Colors.white,
          foregroundColor: isSelected ? Colors.white : Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
        ),
        child: Row(
          children: [
            // Image with responsive size
            SizedBox(
              height: screenHeight * 0.06,
              child: Image.asset(imagePath),
            ),

            // Spacer to push text to the right
            Expanded(
              child: Center(
                child: Text(
                  roleName,
                  style: TextStyle(
                    fontSize: screenWidth * 0.042,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
