import 'package:amanak/chatbot.dart';
import 'package:amanak/gaurdian_location.dart';
import 'package:amanak/home/messaging_tab.dart';
import 'package:amanak/nearest_hospitals.dart';
import 'package:amanak/notifications/noti_service.dart';
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

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  static int selectedHomeIndex = 0;
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

        _currentUserRole = userRole;
        _displayUserId = currentUserId;
        _displayName = userData['name'] ?? 'User';

        if (userRole.toLowerCase() == 'guardian' &&
            sharedUserEmail.isNotEmpty) {
          // If guardian, find the elder user's ID by their email
          final elderData =
              await FirebaseManager.getUserByEmail(sharedUserEmail);
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
      print('Error checking user role: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPills([String? userId]) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final targetUserId = userId ?? FirebaseAuth.instance.currentUser?.uid;
      if (targetUserId != null) {
        final pillsList = await FirebaseManager.getPills(userId: targetUserId);

        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);

        // Filter pills for today only
        final todayPills = <PillModel>[];

        for (var pill in pillsList) {
          final pillStartDate = DateTime(
              pill.dateTime.year, pill.dateTime.month, pill.dateTime.day);

          // Calculate days since start date
          final daysSinceStart = todayDate.difference(pillStartDate).inDays;

          // Check if the pill should be taken today
          if (daysSinceStart >= 0 && daysSinceStart < pill.duration) {
            todayPills.add(pill);
          }
        }

        setState(() {
          _todayPills = todayPills;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading pills: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Mark a pill as taken
  Future<void> _markPillAsTaken(PillModel pill) async {
    // Only allow elder to mark pills
    if (_isReadOnly) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Guardian view is read-only. Cannot mark pills as taken.'),
        ),
      );
      return;
    }

    try {
      // Get current user role
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      print('Marking pill as taken: ${pill.name} (ID: ${pill.id})');

      final userData = await FirebaseManager.getNameAndRole(currentUser.uid);
      final userRole = userData['role'] ?? '';
      final userName = userData['name'] ?? 'User';
      final sharedUserEmail = userData['sharedUsers'] ?? '';

      print(
          'Current user: $userName, Role: $userRole, SharedUser: $sharedUserEmail');

      // Only elders should be able to mark pills as taken
      if (userRole == 'guardian') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Guardians cannot mark pills as taken.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final updatedPill = pill.copyWith(
        taken: true,
        takenDate: DateTime.now(),
        missed: false, // Reset missed status when marked as taken
      );

      print(
          'Updating pill in Firebase: ${updatedPill.id}, taken: ${updatedPill.taken}');
      await FirebaseManager.updatePill(updatedPill);

      // Check if notification was sent to guardian
      if (sharedUserEmail.isNotEmpty) {
        print(
            'Guardian email found: $sharedUserEmail. Notification should be sent.');

        // Get guardian details for verification
        final guardianData =
            await FirebaseManager.getUserByEmail(sharedUserEmail);
        if (guardianData != null) {
          final guardianId = guardianData['id'] ?? '';
          print('Guardian ID: $guardianId');
        } else {
          print('Warning: Could not find guardian with email $sharedUserEmail');
        }
      } else {
        print('No guardian email found. No notification will be sent.');
      }

      _loadPills(); // Reload pills to update UI

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${pill.name} marked as taken'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error marking pill as taken: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error marking pill as taken'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<Map<String, String>> _getTimeStatuses(PillModel pill) {
    final now = DateTime.now();
    List<Map<String, String>> statuses = [];
    
    for (final t in pill.times) {
      final timeKey = pill.getTimeKey(t);
    final pillTime = DateTime(
      now.year,
      now.month,
      now.day,
        t['hour'] ?? 8,
        t['minute'] ?? 0,
    );

      String status;
      if (pill.isTimeTaken(timeKey)) {
        status = "taken";
      } else if (now.difference(pillTime).inMinutes > 5) {
        status = "missed";
      } else if (now.difference(pillTime).inMinutes <= 5 && now.difference(pillTime).inMinutes >= 0) {
        status = "due-now";
      } else if (pillTime.isAfter(now)) {
        status = "upcoming";
      } else {
        status = "upcoming";
    }

      statuses.add({
        'timeKey': timeKey,
        'time': '${(t['hour']! > 12 ? t['hour']! - 12 : t['hour']!)}:${(t['minute']! < 10 ? '0' : '')}${t['minute']!} ${t['hour']! >= 12 ? 'PM' : 'AM'}',
        'status': status
      });
    }
    return statuses;
  }

  String _getStatusText(String status) {
    switch (status) {
      case "upcoming":
        return "Upcoming";
      case "overdue":
        return "Overdue";
      case "due-now":
        return "Due Now";
      case "taken":
        return "Taken";
      case "missed":
        return "Missed";
      default:
        return "Upcoming";
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
      // Reload pills after checking to reflect any status changes
      if (mounted) {
        _loadPills();
      }
    } catch (e) {
      print('Error checking for missed pills: $e');
    }
  }

  // Mark a specific time as taken
  Future<void> _markTimeAsTaken(PillModel pill, String timeKey) async {
    // Only allow elder to mark pills
    if (_isReadOnly) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Guardian view is read-only. Cannot mark pills as taken.'),
        ),
      );
      return;
    }

    try {
      // Get current user role
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final userData = await FirebaseManager.getNameAndRole(currentUser.uid);
      final userRole = userData['role'] ?? '';
      final userName = userData['name'] ?? 'User';
      final sharedUserEmail = userData['sharedUsers'] ?? '';

      // Only elders should be able to mark pills as taken
      if (userRole == 'guardian') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Guardians cannot mark pills as taken.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Create a copy of the pill and update its taken times
      final updatedPill = pill.copyWith();
      updatedPill.markTimeTaken(timeKey, DateTime.now());

      await FirebaseManager.updatePill(updatedPill);

      // Check if notification was sent to guardian
      if (sharedUserEmail.isNotEmpty) {
        final guardianData = await FirebaseManager.getUserByEmail(sharedUserEmail);
        if (guardianData != null) {
          final guardianId = guardianData['id'] ?? '';
          print('Guardian ID: $guardianId');
        }
      }

      _loadPills(); // Reload pills to update UI

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${pill.name} marked as taken for ${timeKey.replaceAll('-', ':')}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error marking pill time as taken: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error marking pill as taken'),
          backgroundColor: Colors.red,
        ),
      );
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          SvgPicture.asset("assets/svg/handshake.svg",
                              height: screenHeight * 0.07), // Larger icon
                          SizedBox(width: screenWidth * 0.03),
                          Text(
                            "Amanak",
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium!
                                .copyWith(
                                  color: Colors.black,
                                  fontSize: screenWidth * 0.06, // Larger font
                                ),
                          ),
                        ],
                      ),
                      SvgPicture.asset("assets/svg/notification.svg",
                          height: screenHeight * 0.045), // Larger icon
                    ],
                  ),
                  SizedBox(height: screenHeight * 0.03),
                  // Search Field
                  PillSearchField(
                    controller: _searchController,
                    onChanged: (value) {
                      // Handle search
                    },
                  ),
                  SizedBox(height: screenHeight * 0.03),
                  // Overlay Buttons Row
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
                                        fontSize:
                                            screenWidth * 0.038, // Larger font
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
                                        fontSize:
                                            screenWidth * 0.038, // Larger font
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
                                        fontSize:
                                            screenWidth * 0.038, // Larger font
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
                                        fontSize:
                                            screenWidth * 0.038, // Larger font
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
                                        fontSize:
                                            screenWidth * 0.038, // Larger font
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
                                        fontSize:
                                            screenWidth * 0.038, // Larger font
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
                                  fontSize: screenWidth * 0.055, // Larger font
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
                                    fontSize: screenWidth * 0.04, // Larger font
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
                                      fontSize:
                                          screenWidth * 0.045, // Larger font
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
            fontSize: 16, // Larger font
          ),
        ),
      ),
    );
  }

  Widget _buildPillCard(PillModel pill, List<Map<String, String>> timeStatuses) {
    // Determine overall card color based on most urgent status
    String overallStatus = "upcoming";
    for (final timeStatus in timeStatuses) {
      final status = timeStatus['status']!;
      if (status == "due-now") {
        overallStatus = "due-now";
        break;
      } else if (status == "missed" && overallStatus != "due-now") {
        overallStatus = "missed";
      } else if (status == "taken" && overallStatus == "upcoming") {
        overallStatus = "taken";
      }
    }

    final Color cardColor;
    final Color textColor;
    final IconData statusIcon;

    // Determine colors and icon based on overall status
    switch (overallStatus) {
      case "upcoming":
        cardColor = Colors.grey[100]!;
        textColor = Colors.grey[800]!;
        statusIcon = Icons.schedule;
        break;
      case "overdue":
        cardColor = Colors.red[50]!;
        textColor = Colors.red[800]!;
        statusIcon = Icons.warning_rounded;
        break;
      case "due-now":
        cardColor = Colors.orange[50]!;
        textColor = Colors.orange[800]!;
        statusIcon = Icons.notifications_active;
        break;
      case "taken":
        cardColor = Colors.green[50]!;
        textColor = Colors.green[800]!;
        statusIcon = Icons.check_circle;
        break;
      case "missed":
        cardColor = Colors.red[50]!;
        textColor = Colors.red[800]!;
        statusIcon = Icons.warning_rounded;
        break;
      default:
        cardColor = Color(0xFFE6F2F9);
        textColor = Color(0xFF015C92);
        statusIcon = Icons.medication;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Pill header
          ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              leading: Container(
              padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.medication,
                  color: textColor,
                size: 28,
                ),
              ),
              title: Text(
                pill.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: textColor,
                fontSize: 18,
                ),
              ),
            subtitle: Text(
                    '${pill.dosage} - ${pill.timesPerDay} ${pill.timesPerDay > 1 ? "times" : "time"} per day',
                    style: TextStyle(
                      color: textColor.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
          ),
          // Time slots
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: timeStatuses.map((timeStatus) {
                final status = timeStatus['status']!;
                Color timeColor;
                switch (status) {
                  case "missed":
                    timeColor = Colors.red[700]!;
                    break;
                  case "due-now":
                    timeColor = Colors.orange[700]!;
                    break;
                  case "taken":
                    timeColor = Colors.green[700]!;
                    break;
                  default:
                    timeColor = textColor.withOpacity(0.7);
                }

                return Container(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey[300]!,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 16,
                              color: timeColor,
                            ),
                            SizedBox(width: 8),
                    Text(
                              timeStatus['time']!,
                      style: TextStyle(
                                color: timeColor,
                                fontSize: 14,
                                fontWeight: status == "due-now" ? FontWeight.bold : FontWeight.normal,
                      ),
                  ),
                            SizedBox(width: 12),
                  Text(
                    _getStatusText(status),
                    style: TextStyle(
                                color: timeColor,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
                      ),
                      if (!_isReadOnly)
                        Transform.scale(
                          scale: 1.2,
                    child: Checkbox(
                            value: status == "taken",
                      activeColor: Colors.green[700],
                      checkColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      onChanged: (bool? value) {
                        if (value != null && value) {
                                _markTimeAsTaken(pill, timeStatus['timeKey']!);
                        }
                      },
                    ),
                        ),
                      if (_isReadOnly)
                        Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Icon(
                            status == "taken" ? Icons.check_circle : Icons.pending_actions,
                            color: status == "taken" ? Colors.green[700] : Colors.orange,
                            size: 24,
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
                  ),
                ),
        ],
      ),
    );
  }
}
