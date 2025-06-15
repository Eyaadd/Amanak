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

  String _getTimeStatus(PillModel pill) {
    // If pill is already taken, return taken status
    if (pill.taken) {
      return "taken";
    }

    // If pill is explicitly marked as missed, return missed status
    if (pill.missed) {
      return "missed";
    }

    final now = DateTime.now();
    final pillTime = DateTime(
      now.year,
      now.month,
      now.day,
      pill.alarmHour,
      pill.alarmMinute,
    );

    // If pill time is more than 5 minutes ago and not taken, mark as overdue/missed
    if (now.difference(pillTime).inMinutes > 5) {
      return "missed";
    }

    // If pill time is within last 5 minutes or next 30 minutes, mark as due now
    if (now.difference(pillTime).inMinutes <= 5 &&
        now.difference(pillTime).inMinutes >= 0) {
      return "due-now";
    }

    // If pill time is in the future, mark as upcoming
    if (pillTime.isAfter(now)) {
      return "upcoming";
    }

    // Default
    return "upcoming";
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
                                                pill, _getTimeStatus(pill)))
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

  Widget _buildPillCard(PillModel pill, String status) {
    // If pill is already taken, override the status
    if (pill.taken) {
      status = "taken";
    } else if (pill.missed) {
      status = "missed";
    }

    final Color cardColor;
    final Color textColor;
    final IconData statusIcon;

    // Determine colors and icon based on status
    switch (status) {
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
        cardColor = Color(0xFFE6F2F9); // Light blue
        textColor = Color(0xFF015C92); // Dark blue
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
      child: Row(
        children: [
          Expanded(
            child: ListTile(
              contentPadding: EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10), // Larger padding
              leading: Container(
                padding: EdgeInsets.all(10), // Larger padding
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
                  size: 28, // Larger icon
                ),
              ),
              title: Text(
                pill.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  fontSize: 18, // Larger font
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${pill.dosage} - ${pill.timesPerDay} ${pill.timesPerDay > 1 ? "times" : "time"} per day',
                    style: TextStyle(
                      color: textColor.withOpacity(0.8),
                      fontSize: 14, // Larger font
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16, // Larger icon
                        color: textColor.withOpacity(0.7),
                      ),
                      SizedBox(width: 4),
                      Text(
                        pill.getFormattedTime(), // Use the new formatted time method
                        style: TextStyle(
                          color: textColor.withOpacity(0.7),
                          fontSize: 14, // Larger font
                        ),
                      ),
                    ],
                  ),
                  if (pill.taken && pill.takenDate != null)
                    Text(
                      'Taken at: ${DateFormat('h:mm a').format(pill.takenDate!)}',
                      style: TextStyle(
                        fontSize: 14, // Larger font
                        color: Colors.green[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  if (pill.missed && !pill.taken)
                    Text(
                      'Missed!',
                      style: TextStyle(
                        fontSize: 14, // Larger font
                        color: Colors.red[700],
                        fontWeight: FontWeight.bold,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    statusIcon,
                    color: textColor,
                    size: 24, // Larger icon
                  ),
                  SizedBox(height: 4),
                  Text(
                    _getStatusText(status),
                    style: TextStyle(
                      fontSize: 12, // Larger font
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              onTap: () {
                Provider.of<MyProvider>(context, listen: false)
                    .changeCalendarIndex();
              },
            ),
          ),
          // Add checkbox for elder or status icon for guardian
          _isReadOnly
              ? Padding(
                  // For guardians - show status icon instead of checkbox
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Icon(
                    pill.taken ? Icons.check_circle : Icons.pending_actions,
                    color: pill.taken ? Colors.green[700] : Colors.orange,
                    size: 28, // Larger icon
                  ),
                )
              : Padding(
                  // For elders - show checkbox to mark pills as taken
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Transform.scale(
                    scale: 1.3, // Make checkbox larger
                    child: Checkbox(
                      value: pill.taken,
                      activeColor: Colors.green[700],
                      checkColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      onChanged: (bool? value) {
                        if (value != null && value) {
                          _markPillAsTaken(pill);
                        }
                      },
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
