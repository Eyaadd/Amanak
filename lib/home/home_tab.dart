import 'package:amanak/chatbot.dart';
import 'package:amanak/gaurdian_location.dart';
import 'package:amanak/home/messaging_tab.dart';
import 'package:amanak/nearest_hospitals.dart';
import 'package:amanak/notifications/noti_service.dart';
import 'package:amanak/provider/fall_detection_provider.dart';
import 'package:amanak/widgets/overlay_button.dart';
import 'package:amanak/widgets/pillsearchfield.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../live_tracking.dart';
import '../medicine_search_screen.dart';
import '../provider/my_provider.dart';
import 'package:amanak/models/pill_model.dart';
import 'package:amanak/firebase/firebase_manager.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final _searchController = TextEditingController();
  List<PillModel> _todayPills = [];
  bool _isLoading = true;
  bool _isReadOnly = false;
  String _currentUserRole = "";
  String _displayUserId = "";
  String _displayName = "";

  @override
  void initState() {
    super.initState();
    _checkUserRoleAndLoadData();
    _setupPeriodicChecks();
  }

  // Check user role and load appropriate data
  Future<void> _checkUserRoleAndLoadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;

      if (currentUserId != null) {
        // Get user data for the current user
        final userData = await FirebaseManager.getNameAndRole(currentUserId);
        final userRole = userData['role'] ?? '';
        final sharedUserEmail = userData['sharedUsers'] ?? '';

        print('👤 User Role: $userRole');
        _currentUserRole = userRole;
        _displayUserId = currentUserId;
        _displayName = userData['name'] ?? 'User';

        if (userRole.toLowerCase() == 'guardian' && sharedUserEmail.isNotEmpty) {
          // If guardian, find the elder user's ID by their email
          final elderData = await FirebaseManager.getUserByEmail(sharedUserEmail);
          if (elderData != null) {
            _displayUserId = elderData['id'] ?? '';
            if (_displayUserId.isNotEmpty) {
              setState(() {
                _isReadOnly = true;
              });
              _displayName = elderData['name'] ?? 'Elder';
            }
          }
        }

        // Load pills for either current user (elder) or shared user (for guardian)
        await _loadPills(_displayUserId);
      }
    } catch (e) {
      print('❌ Error checking user role: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Load pills for the specified user
  Future<void> _loadPills(String userId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final pills = await FirebaseManager.getPillsForDateRange(
        userId,
        startOfDay,
        endOfDay,
      );

      setState(() {
        _todayPills = pills;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading pills: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Set up periodic checks for missed pills
  void _setupPeriodicChecks() {
    // Check for missed pills every 15 minutes
    Timer.periodic(Duration(minutes: 15), (timer) {
      if (mounted) {
        _checkForMissedPills();
      }
    });

    // Also check immediately on startup
    _checkForMissedPills();
  }

  // Check for missed pills
  Future<void> _checkForMissedPills() async {
    try {
      await FirebaseManager.checkForMissedPills();
    } catch (e) {
      print('Error checking for missed pills: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    var provider = Provider.of<MyProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return SafeArea(
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: _checkUserRoleAndLoadData,
          child: SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.all(screenWidth * 0.05),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row
                  Row(
                    children: [
                      SvgPicture.asset("assets/svg/handshake.svg",
                          height: screenHeight * 0.07),
                      SizedBox(width: screenWidth * 0.03),
                      Text(
                        "Amanak",
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium!
                            .copyWith(
                              color: Colors.black,
                              fontSize: screenWidth * 0.06,
                            ),
                      ),
                      Spacer(),
                      SvgPicture.asset("assets/svg/notification.svg",
                          height: screenHeight * 0.045),
                    ],
                  ),
                  SizedBox(height: screenHeight * 0.03),

                  // Search Field
                  PillSearchField(
                    controller: _searchController,
                    onChanged: (value) {},
                  ),
                  SizedBox(height: screenHeight * 0.03),

                  // Quick Actions Grid
                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                OverlayButton(
                                  assetName: "location",
                                  onTap: () => Navigator.pushNamed(
                                      context, LiveTracking.routeName),
                                ),
                                SizedBox(height: screenHeight * 0.025),
                                Text(
                                  "Live \nLocation",
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall!
                                      .copyWith(
                                        color: Color(0xFFA1A8B0),
                                        fontSize: screenWidth * 0.038,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: screenWidth * 0.04),
                          Expanded(
                            child: Column(
                              children: [
                                OverlayButton(
                                  assetName: "calendar",
                                  onTap: () => provider.changeCalendarIndex(),
                                ),
                                SizedBox(height: screenHeight * 0.025),
                                Text(
                                  "Calendar\n",
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall!
                                      .copyWith(
                                        color: Color(0xFFA1A8B0),
                                        fontSize: screenWidth * 0.038,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: screenWidth * 0.04),
                          Expanded(
                            child: Column(
                              children: [
                                OverlayButton(
                                  assetName: "hospital",
                                  onTap: () => Navigator.pushNamed(
                                      context, NearestHospitals.routeName),
                                ),
                                SizedBox(height: screenHeight * 0.025),
                                Text(
                                  "Nearest \nHospitals",
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall!
                                      .copyWith(
                                        color: Color(0xFFA1A8B0),
                                        fontSize: screenWidth * 0.038,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: screenHeight * 0.03),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                OverlayButton(
                                  assetName: "messages",
                                  onTap: () {
                                    provider.changeMessageIndex();
                                  },
                                ),
                                SizedBox(height: screenHeight * 0.025),
                                Text(
                                  "Messages",
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall!
                                      .copyWith(
                                        color: Color(0xFFA1A8B0),
                                        fontSize: screenWidth * 0.038,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: screenWidth * 0.04),
                          Expanded(
                            child: Column(
                              children: [
                                OverlayButton(
                                  assetName: "pills",
                                  onTap: () {
                                    provider.changeCalendarIndex();
                                  },
                                ),
                                SizedBox(height: screenHeight * 0.025),
                                Text(
                                  "Pills",
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall!
                                      .copyWith(
                                        color: Color(0xFFA1A8B0),
                                        fontSize: screenWidth * 0.038,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: screenWidth * 0.04),
                          Expanded(
                            child: Column(
                              children: [
                                OverlayButton(
                                  assetName: "chatbot",
                                  onTap: () => Navigator.pushNamed(
                                      context, ChatBot.routeName),
                                ),
                                SizedBox(height: screenHeight * 0.025),
                                Text(
                                  "Chatbot",
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall!
                                      .copyWith(
                                        color: Color(0xFFA1A8B0),
                                        fontSize: screenWidth * 0.038,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: screenHeight * 0.05),

                  // Pill Reminder Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isReadOnly
                            ? "${_displayName}'s Pill Reminder"
                            : "Pill Reminder",
                        style:
                            Theme.of(context).textTheme.titleMedium!.copyWith(
                                  color: Colors.black,
                                  fontSize: screenWidth * 0.055,
                                ),
                      ),
                      GestureDetector(
                        onTap: () => provider.changeCalendarIndex(),
                        child: Text(
                          "See all",
                          style:
                              Theme.of(context).textTheme.bodyMedium!.copyWith(
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.w500,
                                    fontSize: screenWidth * 0.04,
                                  ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: screenHeight * 0.02),

                  // Today's Pills
                  _isLoading
                      ? Center(
                          child: CircularProgressIndicator(
                          color: Theme.of(context).primaryColor,
                        ))
                      : _todayPills.isEmpty
                          ? _buildEmptyPillCard("No medications for today")
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding:
                                      EdgeInsets.only(left: 8.0, bottom: 8.0),
                                  child: Text(
                                    "Today",
                                    style: TextStyle(
                                      fontSize: screenWidth * 0.045,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ),
                                _todayPills.isEmpty
                                    ? _buildEmptyPillCard(
                                        "No medications for today")
                                    : Column(
                                        children: _todayPills
                                            .map((pill) => _buildPillCard(
                                                pill, _getTimeStatuses(pill)))
                                            .toList(),
                                      ),
                              ],
                            ),
                ],
              ),
            ),
          ),
        ),

        // Add a test button for notifications in debug mode
        persistentFooterButtons: kDebugMode
            ? [
                ElevatedButton(
                  onPressed: () async {
                    final notiService = NotiService();
                    await notiService.testNotification();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Test notification sent'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Text('Test Notifications'),
                ),
              ]
            : null,
      ),
    );
  }

  Widget _buildEmptyPillCard(String message) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          message,
          style: TextStyle(
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildPillCard(PillModel pill, List<bool> timeStatuses) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  pill.name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (!_isReadOnly)
                  Checkbox(
                    value: pill.taken,
                    onChanged: (bool? value) async {
                      if (value != null) {
                        final updatedPill = pill.copyWith(taken: value);
                        await FirebaseManager.updatePill(updatedPill);
                        await _checkUserRoleAndLoadData();
                      }
                    },
                  ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Times: ${pill.times.join(", ")}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            if (pill.note.isNotEmpty) ...[
              SizedBox(height: 2.h),
              Text(
                'Notes: ${pill.note}',
                style: TextStyle(
                  color: _getPillSubtitleColor(pill),
                  fontSize: 13.sp,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<bool> _getTimeStatuses(PillModel pill) {
    final now = DateTime.now();
    return pill.times.map((time) {
      final hour = time['hour'] ?? 0;
      final minute = (time['minute'] ?? 0).toString().padLeft(2, '0');
      final timeString = '$hour:$minute';
      final pillTime = DateFormat('HH:mm').parse(timeString);
      final pillDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        pillTime.hour,
        pillTime.minute,
      );
      return now.isAfter(pillDateTime);
    }).toList();
  }

  Color _getPillSubtitleColor(PillModel pill) {
    // Implement the logic to determine the color based on the pill's status
    // This is a placeholder and should be replaced with the actual implementation
    return Colors.grey;
  }
}
