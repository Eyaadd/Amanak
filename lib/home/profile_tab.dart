import 'package:amanak/widgets/shared_users_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../firebase/firebase_manager.dart';
import '../widgets/logout_dialog.dart';
import '../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../services/localization_service.dart';

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
  bool _isLoading = true;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

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
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
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
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showEditDialog(String field, String currentValue) async {
    final controller = TextEditingController(text: currentValue);
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        insetPadding: EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Container(
          width: 340,
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Edit $field',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.grey[600]),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: controller,
                keyboardType: field == 'Age' || field == 'Height'
                    ? TextInputType.number
                    : TextInputType.text,
                decoration: InputDecoration(
                  hintText: 'Enter new $field',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        BorderSide(color: Theme.of(context).primaryColor),
                  ),
                  prefixIcon: field == 'Name'
                      ? Icon(Icons.person,
                          color: Theme.of(context).primaryColor)
                      : field == 'Age'
                          ? Icon(Icons.cake,
                              color: Theme.of(context).primaryColor)
                          : Icon(Icons.height,
                              color: Theme.of(context).primaryColor),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
              ),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.pop(context, controller.text),
                  child: Text(
                    "Save",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      await _updateUserField(field, result.trim());
    }
  }

  Future<void> _updateUserField(String field, String value) async {
    setState(() {
      _isLoading = true;
    });

    try {
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
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error updating user field: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).primaryColor,
                ),
              )
            : Stack(
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
                      ? _buildEmergencyContactsInterface(
                          screenWidth, screenHeight)
                      : showEditInformation
                          ? _buildEditInformationInterface(
                              screenWidth, screenHeight, localizations)
                          : SingleChildScrollView(
                              child: Column(
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
                                  SizedBox(height: screenHeight * 0.05),
                                  Container(
                                    width: double.infinity,
                                    height: screenHeight * 0.5378,
                                    decoration: BoxDecoration(
                                        borderRadius: BorderRadius.only(
                                          topLeft: Radius.circular(
                                              screenWidth * 0.08),
                                          topRight: Radius.circular(
                                              screenWidth * 0.08),
                                        ),
                                        color: Colors.white),
                                    padding: EdgeInsets.all(screenWidth * 0.04),
                                    child: Column(
                                      children: [
                                        _buildProfileOption(
                                            assetName: "emergencyic",
                                            title:
                                                localizations.emergencyContacts,
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
                                          title: localizations.editInformation,
                                          onTap: () async {
                                            setState(() {
                                              _isLoading = true;
                                            });
                                            await _loadUserDataForEdit();
                                            setState(() {
                                              showEditInformation = true;
                                              showEmergencyContacts = false;
                                              _isLoading = false;
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
                                          assetName: "language",
                                          title: localizations.language,
                                          onTap: () async {
                                            final localizationService = Provider
                                                .of<LocalizationService>(
                                                    context,
                                                    listen: false);
                                            await showDialog(
                                              context: context,
                                              builder: (context) => Dialog(
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 24,
                                                      vertical: 28),
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .center,
                                                    children: [
                                                      Text(
                                                        localizations.language,
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .titleLarge
                                                            ?.copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: Theme.of(
                                                                      context)
                                                                  .primaryColor,
                                                            ),
                                                        textAlign:
                                                            TextAlign.center,
                                                      ),
                                                      SizedBox(height: 24),
                                                      ListTile(
                                                        leading: Text('🇺🇸',
                                                            style: TextStyle(
                                                                fontSize: 32)),
                                                        title: Text(
                                                          localizations.english,
                                                          style: TextStyle(
                                                              fontSize: 20,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600),
                                                        ),
                                                        onTap: () {
                                                          localizationService
                                                              .changeLanguage(
                                                                  'en');
                                                          Navigator.pop(
                                                              context);
                                                        },
                                                        contentPadding:
                                                            EdgeInsets
                                                                .symmetric(
                                                                    horizontal:
                                                                        8),
                                                        shape: RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12)),
                                                        hoverColor: Theme.of(
                                                                context)
                                                            .primaryColor
                                                            .withOpacity(0.08),
                                                      ),
                                                      SizedBox(height: 12),
                                                      ListTile(
                                                        leading: Text('🇪🇬',
                                                            style: TextStyle(
                                                                fontSize: 32)),
                                                        title: Text(
                                                          localizations.arabic,
                                                          style: TextStyle(
                                                              fontSize: 20,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600),
                                                        ),
                                                        onTap: () {
                                                          localizationService
                                                              .changeLanguage(
                                                                  'ar');
                                                          Navigator.pop(
                                                              context);
                                                        },
                                                        contentPadding:
                                                            EdgeInsets
                                                                .symmetric(
                                                                    horizontal:
                                                                        8),
                                                        shape: RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12)),
                                                        hoverColor: Theme.of(
                                                                context)
                                                            .primaryColor
                                                            .withOpacity(0.08),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
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
                                          title: localizations.logout,
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
    return SingleChildScrollView(
      child: Column(
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
                  _buildContactTile(
                      "Natural Gas Emergency", "129", screenWidth),
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
                  _buildContactTile(
                      "Electricity Emergency", "121", screenWidth),
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
      ),
    );
  }

  Widget _buildContactTile(String name, String num, double screenWidth) {
    return InkWell(
      onTap: () => _launchDialer(num),
      borderRadius: BorderRadius.circular(screenWidth * 0.03),
      child: Padding(
        padding: EdgeInsets.symmetric(
            vertical: screenWidth * 0.02, horizontal: screenWidth * 0.01),
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
                  Row(
                    children: [
                      Text(
                        num,
                        style: GoogleFonts.albertSans(
                          fontWeight: FontWeight.w700,
                          fontSize: screenWidth * 0.042,
                          color: Theme.of(context).primaryColor,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.phone,
                        size: screenWidth * 0.04,
                        color: Theme.of(context).primaryColor,
                      ),
                    ],
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _launchDialer(String phoneNumber) async {
    final Uri uri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch phone dialer')),
        );
      }
    } catch (e) {
      print('Error launching phone dialer: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening phone dialer')),
      );
    }
  }

  Widget _buildEditInformationInterface(
      double screenWidth, double screenHeight, AppLocalizations localizations) {
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
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProfileOption(
                      assetName: "name",
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
                      assetName: "age",
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
                      assetName: "height",
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
                      assetName: "userrole",
                      title: userRole,
                      onTap: () {},
                      screenWidth: screenWidth,
                    ),
                    Divider(
                        color: Color(0xFFE8F3F1),
                        thickness: 2,
                        endIndent: screenWidth * 0.025,
                        indent: screenWidth * 0.025),
                    Padding(
                      padding:
                          EdgeInsets.only(left: screenWidth * 0.02, bottom: 4),
                      child: Text(
                        userRole.toLowerCase() == 'guardian'
                            ? localizations.yourCareReceiver
                            : localizations.yourGuardian,
                        style: GoogleFonts.albertSans(
                          fontWeight: FontWeight.bold,
                          fontSize: screenWidth * 0.042,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                    _buildProfileOption(
                      assetName: "shareduser",
                      title: sharedUsers == '' ? "Shared Users" : sharedUsers,
                      onTap: () {
                        sharedUsersDialog(
                            context, "Shared Users", userID, userEmail);
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
