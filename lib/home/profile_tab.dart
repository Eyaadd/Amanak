import 'package:amanak/widgets/shared_users_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../firebase/firebase_manager.dart';
import '../widgets/logout_dialog.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  String userName = 'User Name';
  String userEmail = 'user@email.com';
  String userRole = '';
  String sharedUsers = '';
  String userID = '';
  int userAge = 0;
  double userHeight = 0;
  bool showEmergencyContacts = false;
  bool showEditInformation = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        Map<String, String> userData =
            await FirebaseManager.getNameAndRole(currentUser.uid);
        setState(() {
          userName = userData['name']!;
          userEmail = userData['email']!;
          userRole = userData['role']!;
          userID = userData['id']!;
          sharedUsers = userData['sharedUsers']!;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _loadUserDataForEdit() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        var collection = FirebaseManager.getUsersCollection();
        var docSnapshot = await collection.doc(currentUser.uid).get();
        if (docSnapshot.exists) {
          var user = docSnapshot.data()!;
          _nameController.text = user.name;
          _ageController.text = user.age.toString();
          _heightController.text = user.height.toString();
          setState(() {
            userRole = user.role;
            sharedUsers = user.sharedUsers;
          });
        }
      }
    } catch (e) {
      print('Error loading user data for edit: $e');
    }
  }

  Future<void> _showEditDialog(String field, String currentValue) async {
    final controller = TextEditingController(text: currentValue);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit $field'),
        content: TextFormField(
          controller: controller,
          keyboardType: field == 'Age' || field == 'Height'
              ? TextInputType.number
              : TextInputType.text,
          decoration: InputDecoration(hintText: 'Enter new $field'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      await _updateUserField(field, result.trim());
    }
  }

  Future<void> _updateUserField(String field, String value) async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      var collection = FirebaseManager.getUsersCollection();
      var docSnapshot = await collection.doc(currentUser.uid).get();
      if (docSnapshot.exists) {
        var user = docSnapshot.data()!;
        switch (field) {
          case 'Name':
            user.name = value;
            break;
          case 'Age':
            user.age = int.tryParse(value) ?? user.age;
            break;
          case 'Height':
            user.height = double.tryParse(value) ?? user.height;
            break;
        }
        await FirebaseManager.updateEvent(user);
        setState(() {
          userName = user.name;
          userAge = user.age;
          userHeight = user.height;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            SizedBox.expand(
              child: SvgPicture.asset(
                "assets/svg/profilebg.svg",
                fit: BoxFit.cover,
              ),
            ),
            SvgPicture.asset("assets/svg/profiledesign.svg",
                width: screenWidth, fit: BoxFit.cover),
            showEmergencyContacts
                ? _buildEmergencyContactsInterface(screenWidth, screenHeight)
                : showEditInformation
                    ? _buildEditInformationInterface(screenWidth, screenHeight)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: screenHeight * 0.025),
                          Center(
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: screenWidth * 0.13,
                                  backgroundColor: Colors.grey[200],
                                  child: Icon(
                                    Icons.person,
                                    size: screenWidth * 0.13,
                                    color: Colors.grey,
                                  ),
                                ),
                                SizedBox(height: screenHeight * 0.02),
                                Text(
                                  userName,
                                  style: GoogleFonts.albertSans(
                                    fontSize: screenWidth * 0.05,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (userRole.isNotEmpty) ...[
                                  SizedBox(height: screenHeight * 0.01),
                                  Text(
                                    userRole,
                                    style: GoogleFonts.albertSans(
                                      fontSize: screenWidth * 0.04,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.108),
                          Container(
                            width: double.infinity,
                            height: screenHeight * 0.5378,
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(screenWidth * 0.08),
                                  topRight: Radius.circular(screenWidth * 0.08),
                                ),
                                color: Colors.white),
                            padding: EdgeInsets.all(screenWidth * 0.04),
                            child: Column(
                              children: [
                                _buildProfileOption(
                                    assetName: "emergencyic",
                                    title: 'Emergency Contacts',
                                    onTap: () {
                                      setState(() {
                                        showEmergencyContacts = true;
                                        showEditInformation = false;
                                      });
                                    },
                                    screenWidth: screenWidth),
                                Divider(
                                  color: Color(0xFFE8F3F1),
                                  thickness: 2,
                                  endIndent: screenWidth * 0.025,
                                  indent: screenWidth * 0.025,
                                ),
                                _buildProfileOption(
                                  assetName: "editic",
                                  title: 'Edit Information',
                                  onTap: () async {
                                    await _loadUserDataForEdit();
                                    setState(() {
                                      showEditInformation = true;
                                      showEmergencyContacts = false;
                                    });
                                  },
                                  screenWidth: screenWidth,
                                ),
                                Divider(
                                  color: Color(0xFFE8F3F1),
                                  thickness: 2,
                                  endIndent: screenWidth * 0.025,
                                  indent: screenWidth * 0.025,
                                ),
                                _buildProfileOption(
                                  assetName: "dangercircle",
                                  title: 'Logout',
                                  textColor: Color(0xFFFF5C5C),
                                  onTap: () {
                                    showLogoutDialog(context);
                                  },
                                  screenWidth: screenWidth,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileOption({
    required String title,
    required VoidCallback onTap,
    required String assetName,
    bool idShow = false,
    Color? textColor,
    required double screenWidth,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: screenWidth * 0.03),
        child: Row(
          children: [
            Container(
                width: screenWidth * 0.12,
                height: screenWidth * 0.12,
                decoration: BoxDecoration(
                    color: Color(0xFFE8F3F1),
                    borderRadius: BorderRadius.circular(screenWidth * 0.06)),
                child: Center(
                  child: SvgPicture.asset(
                    "assets/svg/$assetName.svg",
                    width: screenWidth * 0.05,
                  ),
                )),
            SizedBox(width: screenWidth * 0.04),
            idShow
                ? Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: SelectableText(
                            title,
                            style: GoogleFonts.albertSans(
                              fontWeight: FontWeight.w700,
                              fontSize: screenWidth * 0.042,
                              color: textColor ?? Colors.black,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.copy, size: screenWidth * 0.04),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: title));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('ID Copied to clipboard')),
                            );
                          },
                        ),
                      ],
                    ),
                  )
                : Text(
                    title,
                    style: GoogleFonts.albertSans(
                      fontWeight: FontWeight.w700,
                      fontSize: screenWidth * 0.042,
                      color: textColor ?? Colors.black,
                    ),
                  ),
            const Spacer(),
            SvgPicture.asset("assets/svg/arrowright.svg",
                width: screenWidth * 0.06)
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyContactsInterface(
      double screenWidth, double screenHeight) {
    return Column(
      children: [
        SizedBox(height: screenHeight * 0.05),
        Container(
          width: double.infinity,
          height: screenHeight * 0.85,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(screenWidth * 0.08),
                topRight: Radius.circular(screenWidth * 0.08),
              ),
              color: Colors.white),
          child: Padding(
            padding: EdgeInsets.all(screenWidth * 0.04),
            child: Column(
              children: [
                _buildContactTile("Main Ambulance", "123", screenWidth),
                Divider(
                  color: Color(0xFFE8F3F1),
                  thickness: 2,
                  endIndent: screenWidth * 0.025,
                  indent: screenWidth * 0.025,
                ),
                _buildContactTile("Traffic Police", "128", screenWidth),
                Divider(
                  color: Color(0xFFE8F3F1),
                  thickness: 2,
                  endIndent: screenWidth * 0.025,
                  indent: screenWidth * 0.025,
                ),
                _buildContactTile("Emergency Police", "122", screenWidth),
                Divider(
                  color: Color(0xFFE8F3F1),
                  thickness: 2,
                  endIndent: screenWidth * 0.025,
                  indent: screenWidth * 0.025,
                ),
                _buildContactTile("Fire Department", "128", screenWidth),
                Divider(
                  color: Color(0xFFE8F3F1),
                  thickness: 2,
                  endIndent: screenWidth * 0.025,
                  indent: screenWidth * 0.025,
                ),
                _buildContactTile("Civil Defence", "180", screenWidth),
                Divider(
                  color: Color(0xFFE8F3F1),
                  thickness: 2,
                  endIndent: screenWidth * 0.025,
                  indent: screenWidth * 0.025,
                ),
                _buildContactTile("Natural Gas Emergency", "129", screenWidth),
                Divider(
                  color: Color(0xFFE8F3F1),
                  thickness: 2,
                  endIndent: screenWidth * 0.025,
                  indent: screenWidth * 0.025,
                ),
                _buildContactTile("Water Emergency", "125", screenWidth),
                Divider(
                  color: Color(0xFFE8F3F1),
                  thickness: 2,
                  endIndent: screenWidth * 0.025,
                  indent: screenWidth * 0.025,
                ),
                _buildContactTile("Electricity Emergency", "121", screenWidth),
                Divider(
                  color: Color(0xFFE8F3F1),
                  thickness: 2,
                  endIndent: screenWidth * 0.025,
                  indent: screenWidth * 0.025,
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      showEmergencyContacts = false;
                    });
                  },
                  child: Text("Go Back",
                      style: GoogleFonts.albertSans(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: screenWidth * 0.045)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactTile(String name, String num, double screenWidth) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: screenWidth * 0.02),
      child: Row(
        children: [
          Container(
            width: screenWidth * 0.12,
            height: screenWidth * 0.10,
            decoration: BoxDecoration(
                color: Color(0xFFE8F3F1),
                borderRadius: BorderRadius.circular(screenWidth * 0.06)),
            child: Center(
              child: SvgPicture.asset(
                "assets/svg/sos.svg",
                width: screenWidth * 0.07,
              ),
            ),
          ),
          SizedBox(width: screenWidth * 0.04),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(name,
                    style: GoogleFonts.albertSans(
                        fontWeight: FontWeight.w700,
                        fontSize: screenWidth * 0.042)),
                Text(num,
                    style: GoogleFonts.albertSans(
                        fontWeight: FontWeight.w700,
                        fontSize: screenWidth * 0.042)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildEditInformationInterface(
      double screenWidth, double screenHeight) {
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(height: screenHeight * 0.18),
          Container(
            width: double.infinity,
            height: screenHeight * 0.72,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(screenWidth * 0.08),
                  topRight: Radius.circular(screenWidth * 0.08),
                ),
                color: Colors.white),
            child: Padding(
              padding: EdgeInsets.symmetric(
                  vertical: screenHeight * 0.04,
                  horizontal: screenWidth * 0.05),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileOption(
                    assetName: "emergencyic",
                    title: '$userName',
                    onTap: () => _showEditDialog('Name', userName),
                    screenWidth: screenWidth,
                  ),
                  Divider(
                      color: Color(0xFFE8F3F1),
                      thickness: 2,
                      endIndent: screenWidth * 0.025,
                      indent: screenWidth * 0.025),
                  _buildProfileOption(
                    assetName: "editic",
                    title: '$userAge',
                    onTap: () => _showEditDialog('Age', userAge.toString()),
                    screenWidth: screenWidth,
                  ),
                  Divider(
                      color: Color(0xFFE8F3F1),
                      thickness: 2,
                      endIndent: screenWidth * 0.025,
                      indent: screenWidth * 0.025),
                  _buildProfileOption(
                    assetName: "dangercircle",
                    title: 'Height: $userHeight',
                    onTap: () =>
                        _showEditDialog('Height', userHeight.toString()),
                    screenWidth: screenWidth,
                  ),
                  Divider(
                      color: Color(0xFFE8F3F1),
                      thickness: 2,
                      endIndent: screenWidth * 0.025,
                      indent: screenWidth * 0.025),
                  _buildProfileOption(
                    assetName: "dangercircle",
                    title: userRole,
                    onTap: () {},
                    screenWidth: screenWidth,
                  ),
                  Divider(
                      color: Color(0xFFE8F3F1),
                      thickness: 2,
                      endIndent: screenWidth * 0.025,
                      indent: screenWidth * 0.025),
                  _buildProfileOption(
                    assetName: "dangercircle",
                    title: sharedUsers == '' ? "Shared Users" : sharedUsers,
                    onTap: () {
                      sharedUsersDialog(context, "Shared Users", userID,  userEmail);
                    },
                    screenWidth: screenWidth,
                  ),
                  Divider(
                      color: Color(0xFFE8F3F1),
                      thickness: 2,
                      endIndent: screenWidth * 0.025,
                      indent: screenWidth * 0.025),
                  _buildProfileOption(
                    assetName: "dangercircle",
                    idShow: true,
                    title: userID,
                    onTap: () {
                      // Empty onTap as we're using the copy button now
                    },
                    screenWidth: screenWidth,
                  ),
                  SizedBox(height: screenHeight * 0.03),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          showEditInformation = false;
                        });
                      },
                      child: Text("Go Back",
                          style: GoogleFonts.albertSans(
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.w700,
                              fontSize: screenWidth * 0.045)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    super.dispose();
  }
}
