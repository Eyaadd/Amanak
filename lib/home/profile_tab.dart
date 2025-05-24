import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/svg.dart';

import '../login_screen.dart';
import '../provider/my_provider.dart';
import '../widgets/logout_dialog.dart';
import '../firebase/firebase_manager.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  String userName = 'User Name';
  String userEmail = 'user@email.com';
  String userRole = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        Map<String, String> userData = await FirebaseManager.getNameAndRole(currentUser.uid);
        setState(() {
          userName = userData['name']!;
          userEmail = userData['email']!;
          userRole = userData['role']!;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                // Profile Header
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey[200],
                        child: const Icon(
                          Icons.person,
                          size: 50,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        userName,
                        style: GoogleFonts.aBeeZee(fontSize: 20),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        userEmail,
                        style: GoogleFonts.aBeeZee(),
                      ),
                      if (userRole.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          userRole,
                          style: GoogleFonts.aBeeZee(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // Profile Options
                _buildProfileOption(
                  icon: Icons.person_outline,
                  title: 'Personal Information',
                  onTap: () {
                    // Handle personal information tap
                  },
                ),
                _buildProfileOption(
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  onTap: () {
                    // Handle notifications tap
                  },
                ),
                _buildProfileOption(
                  icon: Icons.security_outlined,
                  title: 'Security',
                  onTap: () {
                    // Handle security tap
                  },
                ),
                _buildProfileOption(
                  icon: Icons.help_outline,
                  title: 'Help & Support',
                  onTap: () {
                    // Handle help & support tap
                  },
                ),
                _buildProfileOption(
                  icon: Icons.info_outline,
                  title: 'About',
                  onTap: () {
                    // Handle about tap
                  },
                ),
                const SizedBox(height: 32),
                // Logout Button
                Center(
                  child: ElevatedButton(
                    onPressed: () => showLogoutDialog(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      'Logout',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: Colors.grey[700],
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}
