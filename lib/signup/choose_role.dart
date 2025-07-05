import 'package:amanak/firebase/firebase_manager.dart';
import 'package:amanak/models/user_model.dart';
import 'package:amanak/provider/my_provider.dart';
import 'package:amanak/signup/guardian_user_assignment.dart';
import 'package:amanak/widgets/success_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:amanak/l10n/app_localizations.dart';

class ChooseRoleScreen extends StatefulWidget {
  static const routeName = "ChooseRole";

  const ChooseRoleScreen({super.key});

  @override
  State<ChooseRoleScreen> createState() => _ChooseRoleScreenState();
}

class _ChooseRoleScreenState extends State<ChooseRoleScreen> {
  String? selectedRole;

  @override
  Widget build(BuildContext context) {
    var provider = Provider.of<MyProvider>(context);
    final localizations = AppLocalizations.of(context)!;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actionsIconTheme: IconThemeData(color: Color(0xFF101623)),
        centerTitle: true,
        title: Text(
          localizations.chooseYourRole,
          style: Theme.of(context)
              .textTheme
              .titleMedium!
              .copyWith(color: Color(0xFF101623)),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: screenHeight -
                    MediaQuery.of(context).padding.top -
                    kToolbarHeight,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: screenHeight * 0.15),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        selectedRole = "user";
                      });
                      provider.setRole("user");
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectedRole == "user"
                          ? Theme.of(context).primaryColor
                          : Colors.white,
                      foregroundColor:
                          selectedRole == "user" ? Colors.white : Colors.black,
                      minimumSize: Size(screenWidth * 0.85, 81),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset("assets/images/user.png"),
                        SizedBox(width: screenWidth * 0.1),
                        Text(
                          localizations.user,
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 22),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        selectedRole = "Guardian";
                      });
                      provider.setRole("Guardian");
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectedRole == "Guardian"
                          ? Theme.of(context).primaryColor
                          : Colors.white,
                      foregroundColor: selectedRole == "Guardian"
                          ? Colors.white
                          : Colors.black,
                      minimumSize: Size(screenWidth * 0.85, 81),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset("assets/images/guardian.png"),
                        SizedBox(width: screenWidth * 0.1),
                        Text(
                          localizations.guardian,
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.25),
                  ElevatedButton(
                    onPressed: selectedRole == null
                        ? null
                        : () async {
                            UserModel user = UserModel(
                                name: provider.userName,
                                email: provider.userEmail,
                                id: provider.userID,
                                role: provider.chosedRole);

                            if (provider.chosedRole == "Guardian") {
                              // For guardians, navigate to user assignment screen
                              if (mounted) {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        GuardianUserAssignment(user: user),
                                  ),
                                );
                              }
                            } else {
                              // For regular users, complete registration
                              await FirebaseManager.updateEvent(user).onError(
                                (error, stackTrace) {
                                  SnackBar(content: Text("$error"));
                                },
                              ).then(
                                (value) {
                                  if (mounted) {
                                    showSuccessDialog(context);
                                  }
                                },
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectedRole == null
                          ? Colors.grey
                          : Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      minimumSize: Size(screenWidth * 0.85, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32),
                      ),
                    ),
                    child: Text(
                      localizations.continueButton,
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  SizedBox(height: 20), // Bottom padding
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
