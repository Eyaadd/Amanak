import 'package:amanak/chatbot.dart';
import 'package:amanak/gaurdian_location.dart';
import 'package:amanak/home/messaging_tab.dart';
import 'package:amanak/nearest_hospitals.dart';
import 'package:amanak/notifications/noti_service.dart';
import 'package:amanak/provider/fall_detection_provider.dart';
import 'package:amanak/provider/pill_provider.dart';
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
import '../l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:amanak/widgets/notification_badge.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:amanak/services/fcm_service.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with AutomaticKeepAliveClientMixin {
  static int selectedHomeIndex = 0;
  final _searchController = TextEditingController();
  List<PillModel> _todayPills = [];
  Timer? _periodicTimer;

  // Keep page alive when switching tabs to prevent rebuilds
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Initialize pill provider
    Future.microtask(() {
      final pillProvider = Provider.of<PillProvider>(context, listen: false);
      pillProvider.initialize().then((_) => _updateTodayPills());

      // Add listener to pill provider to update when data changes
      pillProvider.addListener(_onPillProviderChanged);
    });
    _setupPeriodicChecks();
  }

  @override
  void dispose() {
    // Remove listener when disposing
    final pillProvider = Provider.of<PillProvider>(context, listen: false);
    pillProvider.removeListener(_onPillProviderChanged);

    _periodicTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // Callback when pill provider data changes
  void _onPillProviderChanged() {
    if (mounted) {
      _updateTodayPills();
    }
  }

  // Update today's pills from the provider's data
  Future<void> _updateTodayPills() async {
    if (!mounted) return;

    final pillProvider = Provider.of<PillProvider>(context, listen: false);
    final allPills = pillProvider.pills;

    // Use compute to filter pills off the main thread for better performance
    final todayPills = await compute(_filterPillsForToday, allPills);

    if (mounted) {
      setState(() {
        _todayPills = todayPills;
      });
    }
  }

  // Static method for compute to run on separate isolate
  static List<PillModel> _filterPillsForToday(List<PillModel> pillsList) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final todayPills = <PillModel>[];

    for (var pill in pillsList) {
      final pillStartDate =
          DateTime(pill.dateTime.year, pill.dateTime.month, pill.dateTime.day);

      // Calculate days since start date
      final daysSinceStart = todayDate.difference(pillStartDate).inDays;

      // Check if the pill should be taken today
      if (daysSinceStart >= 0 && daysSinceStart < pill.duration) {
        // Instead of adding the pill once, add it once for each dosage time
        for (int i = 0; i < pill.times.length; i++) {
          // Create a copy of the pill with a single time
          final timeOfDay = pill.times[i];
          final singleTimePill = pill.copyWith(
            times: [timeOfDay],
            timesPerDay: 1, // Set to 1 since we're showing one time per card
          );
          todayPills.add(singleTimePill);
        }
      }
    }

    // Sort pills by time
    todayPills.sort((a, b) {
      final aTime = a.times.first;
      final bTime = b.times.first;

      // Compare hours first
      if (aTime.hour != bTime.hour) {
        return aTime.hour.compareTo(bTime.hour);
      }

      // If hours are the same, compare minutes
      return aTime.minute.compareTo(bTime.minute);
    });

    return todayPills;
  }

  // Mark a pill as taken
  Future<void> _markPillAsTaken(PillModel pill) async {
    final pillProvider = Provider.of<PillProvider>(context, listen: false);

    // Only allow elder to mark pills
    if (pillProvider.isReadOnly) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Guardian view is read-only. Cannot mark pills as taken.'),
        ),
      );
      return;
    }

    try {
      // Get the time key for this specific dose
      final timeKey = _getTimeKeyForPill(pill);

      // Show immediate feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${pill.name} marked as taken for ${_formatTime(pill.times.first)}'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );

      // Find the original pill in the provider's list
      final originalPill = pillProvider.pills.firstWhere(
        (p) => p.id == pill.id,
        orElse: () => pill,
      );

      // Create a copy with the updated taken status
      final updatedPill = originalPill.copyWith();
      updatedPill.markTimeTaken(timeKey, DateTime.now());

      // Update the pill through the provider
      await pillProvider.updatePill(updatedPill);

      // Send an instant notification to the guardian
      await _sendInstantPillNotification(updatedPill);

      // Update today's pills list after the provider has updated
      await _updateTodayPills();
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

  // Send an instant notification when a pill is marked as taken
  Future<void> _sendInstantPillNotification(PillModel pill) async {
    try {
      print('⚡ Starting to send instant pill notification for: ${pill.name}');

      // Get current user data
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('User not authenticated, cannot send notification');
        return;
      }

      final userData = await FirebaseManager.getNameAndRole(currentUser.uid);
      final elderName = userData['name'] ?? 'User';
      final sharedUserEmail = userData['sharedUsers'] ?? '';

      if (sharedUserEmail.isEmpty) {
        print('No guardian email found, cannot send notification');
        return;
      }

      // Find guardian by email
      print('🔍 Looking up guardian by email: $sharedUserEmail');
      final guardianData =
          await FirebaseManager.getUserByEmail(sharedUserEmail);
      if (guardianData == null) {
        print('Guardian not found for email: $sharedUserEmail');
        return;
      }

      final guardianId = guardianData['id'] ?? '';
      if (guardianId.isEmpty) {
        print('Invalid guardian ID');
        return;
      }

      // Create notification message
      final title = "Medicine Taken";
      final body = "$elderName marked ${pill.name} as taken.";

      print('⚡ SENDING INSTANT NOTIFICATION: $title - $body');

      // Use the direct Firebase Manager method for sending notifications
      await _sendDirectPillNotification(
          guardianId: guardianId,
          pillName: pill.name,
          elderName: elderName,
          isTaken: true);

      print('✅ INSTANT NOTIFICATION SENT');
    } catch (e) {
      print('❌ Error sending instant notification: $e');
    }
  }

  // Send a direct FCM notification to the guardian about pill status
  Future<void> _sendDirectPillNotification(
      {required String guardianId,
      required String pillName,
      required String elderName,
      required bool isTaken}) async {
    try {
      // Ensure user is authenticated before proceeding
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('Cannot send notification: User not authenticated');
        return;
      }

      // Force token refresh to ensure we have a valid token
      print('Refreshing Firebase Auth token...');
      try {
        await currentUser.getIdToken(true);
        print('Token refreshed successfully');
      } catch (authError) {
        print('Error refreshing auth token: $authError');
        // Continue anyway, the FCM service will handle authentication errors
      }

      // Import FCMService
      final fcmService = FCMService();

      // Ensure FCM service is initialized
      await fcmService.ensureInitialized();

      // Prepare notification data
      final title = isTaken ? "Medicine Taken" : "Pill Missed Alert";
      final body = isTaken
          ? "$elderName marked $pillName as taken."
          : "$elderName missed their medicine: $pillName.";

      // Send notification using FCM service
      bool fcmSuccess = await fcmService.sendNotification(
        userId: guardianId,
        title: title,
        body: body,
        data: {
          'type': isTaken ? 'pill_taken' : 'pill_missed',
          'pillName': pillName,
          'elderName': elderName,
          'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
        },
        highPriority: true,
      );

      if (!fcmSuccess) {
        print(
            'FCM notification failed, storing in Firestore for later delivery');

        // Store for later delivery
        await FirebaseFirestore.instance
            .collection('pending_notifications')
            .add({
          'userId': guardianId,
          'title': title,
          'body': body,
          'data': {
            'type': isTaken ? 'pill_taken' : 'pill_missed',
            'pillName': pillName,
            'elderName': elderName,
            'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
          },
          'timestamp': FieldValue.serverTimestamp(),
          'delivered': false,
          'attempts': 1,
          'lastAttempt': FieldValue.serverTimestamp(),
        });
      } else {
        print('Pill notification sent successfully to guardian');

        // Also store in Firestore for history
        await FirebaseFirestore.instance
            .collection('users')
            .doc(guardianId)
            .collection('notifications')
            .add({
          'title': title,
          'message': body,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'type': isTaken ? 'pill_taken' : 'pill_missed',
          'data': {
            'pillName': pillName,
            'elderName': elderName,
          },
        });
      }
    } catch (e) {
      print('Error in _sendDirectPillNotification: $e');
    }
  }

  // Helper method to get the time key for a specific pill dose
  String _getTimeKeyForPill(PillModel pill) {
    if (pill.times.isEmpty) return "";

    // Get the index of this time in the original pill's times list
    final time = pill.times.first;

    // Find the original pill from the provider to get the time index
    final pillProvider = Provider.of<PillProvider>(context, listen: false);
    final originalPill = pillProvider.pills
        .firstWhere((p) => p.id == pill.id, orElse: () => pill);

    int timeIndex = 0;
    for (int i = 0; i < originalPill.times.length; i++) {
      final t = originalPill.times[i];
      if (t.hour == time.hour && t.minute == time.minute) {
        timeIndex = i;
        break;
      }
    }

    final today = DateTime.now();
    final dateStr = '${today.year}-${today.month}-${today.day}';
    return '$dateStr-$timeIndex';
  }

  // Helper method to format time
  String _formatTime(TimeOfDay time) {
    final hour =
        time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _getTimeStatus(PillModel pill) {
    if (pill.times.isEmpty) return "upcoming";

    final today = DateTime.now();
    final timeKey = _getTimeKeyForPill(pill);

    // If this specific dose is already taken today, return taken status
    if (pill.takenDates.containsKey(timeKey)) {
      return "taken";
    }

    // If pill is explicitly marked as missed, return missed status
    if (pill.missed) {
      return "missed";
    }

    final now = DateTime.now();
    final time = pill.times.first;

    // Check if the pill is scheduled for a future date
    final pillStartDate =
        DateTime(pill.dateTime.year, pill.dateTime.month, pill.dateTime.day);
    final todayDate = DateTime(now.year, now.month, now.day);

    // If pill is scheduled for a future date, it's always upcoming
    if (pillStartDate.isAfter(todayDate)) {
      return "upcoming";
    }

    // For pills scheduled for today, check the specific time
    final pillTime = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    // If pill time is more than 15 minutes ago and not taken, mark as overdue/missed
    // Increased from 5 to 15 minutes to provide more flexibility
    if (now.difference(pillTime).inMinutes > 15) {
      return "missed";
    }

    // If pill time is within last 15 minutes or next 30 minutes, mark as due now
    if (now.difference(pillTime).inMinutes <= 15 &&
        now.difference(pillTime).inMinutes >= -30) {
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
        return "Scheduled";
    }
  }

  // Set up periodic checks for pill status updates
  void _setupPeriodicChecks() {
    // Check for missed pills and refresh data every minute
    _periodicTimer = Timer.periodic(Duration(minutes: 1), (timer) {
      if (!mounted) return;

      final pillProvider = Provider.of<PillProvider>(context, listen: false);

      // Check for missed pills
      pillProvider.checkForMissedPills().then((_) {
        // Update today's pills after checking for missed pills
        _updateTodayPills();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Must call super for AutomaticKeepAliveClientMixin
    super.build(context);

    final localizations = AppLocalizations.of(context)!;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final provider = Provider.of<MyProvider>(context);
    final pillProvider = Provider.of<PillProvider>(context);

    return SafeArea(
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: () async {
            await pillProvider.checkUserRoleAndLoadData();
            await _updateTodayPills();
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
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
                              // Use precacheImage for logo to ensure it's loaded
                              Image.asset(
                                "assets/images/Amanaklogo2.png",
                                height: screenHeight * 0.07,
                              ),
                              Text(
                                localizations.home,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium!
                                    .copyWith(
                                      color: Colors.black,
                                      fontSize: screenWidth * 0.06,
                                    ),
                              ),
                            ],
                          ),
                          // Logo
                          NotificationBadge(
                            size: screenHeight * 0.045,
                          ),
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
                      // Overlay Buttons - Moved to a dedicated widget
                      OverlayButtonGrid(
                        screenWidth: screenWidth,
                        screenHeight: screenHeight,
                        provider: provider,
                      ),
                      SizedBox(height: screenHeight * 0.05),
                      // Pill Reminder Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              pillProvider.isReadOnly
                                  ? "${pillProvider.displayName}'s ${localizations.pillReminder}"
                                  : localizations.pillReminder,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium!
                                  .copyWith(
                                    color: Colors.black,
                                    fontSize: screenWidth * 0.055,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              maxLines: 1,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => provider.changeCalendarIndex(),
                            child: Padding(
                              padding: EdgeInsets.only(left: 8.0),
                              child: Text(
                                localizations.seeAll,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium!
                                    .copyWith(
                                      color: Theme.of(context).primaryColor,
                                      fontWeight: FontWeight.w500,
                                      fontSize: screenWidth * 0.04,
                                    ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: screenHeight * 0.02),
                    ],
                  ),
                ),
              ),

              // Today's Pills with optimized builder
              pillProvider.isLoading
                  ? SliverToBoxAdapter(
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    )
                  : _todayPills.isEmpty
                      ? SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: screenWidth * 0.05),
                            child: _buildEmptyPillCard(
                                localizations.noMedicinesForToday),
                          ),
                        )
                      : SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: screenWidth * 0.05),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding:
                                      EdgeInsets.only(left: 8.0, bottom: 8.0),
                                  child: Text(
                                    localizations.today,
                                    style: TextStyle(
                                      fontSize: screenWidth * 0.045,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ),
                                // Use ListView.builder for efficient list rendering
                                ListView.builder(
                                  physics: NeverScrollableScrollPhysics(),
                                  shrinkWrap: true,
                                  itemCount: _todayPills.length,
                                  itemBuilder: (context, index) {
                                    final pill = _todayPills[index];
                                    return _buildPillCard(
                                        pill, _getTimeStatus(pill));
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
            ],
          ),
        ),
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

  // Optimized pill card with const where possible
  Widget _buildPillCard(PillModel pill, String status) {
    final today = DateTime.now();
    final timeKey = _getTimeKeyForPill(pill);

    // If this specific dose is already taken today, override the status
    if (pill.takenDates.containsKey(timeKey)) {
      status = "taken";
    } else if (pill.missed) {
      status = "missed";
    }

    // Cache colors and icons to avoid recalculation
    final cardColor = _getCardColor(status);
    final textColor = _getTextColor(status);
    final statusIcon = _getStatusIcon(status);
    final takenDate = pill.takenDates[timeKey];

    // Get the specific time for this dose
    final doseTime = pill.times.isNotEmpty
        ? pill.times.first
        : TimeOfDay(hour: 8, minute: 0);
    final formattedTime = _formatTime(doseTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(
                0x0D000000), // Optimized from Colors.black.withOpacity(0.05)
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(
                          0x1A000000), // Optimized from Colors.black.withOpacity(0.1)
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
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${pill.dosage}',
                    style: TextStyle(
                      color: textColor.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: textColor.withOpacity(0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        formattedTime,
                        style: TextStyle(
                          color: textColor.withOpacity(0.7),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (takenDate != null)
                    Text(
                      'Taken at: ${DateFormat('h:mm a').format(takenDate)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.green[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  if (pill.missed && !pill.takenDates.containsKey(timeKey))
                    Text(
                      'Missed!',
                      style: TextStyle(
                        fontSize: 14,
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
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getStatusText(status),
                    style: TextStyle(
                      fontSize: 12,
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
          Provider.of<PillProvider>(context, listen: false).isReadOnly
              ? Padding(
                  // For guardians - show status icon instead of checkbox
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Icon(
                    pill.takenDates.containsKey(timeKey)
                        ? Icons.check_circle
                        : Icons.pending_actions,
                    color: pill.takenDates.containsKey(timeKey)
                        ? Colors.green[700]
                        : Colors.orange,
                    size: 28,
                  ),
                )
              : Padding(
                  // For elders - show checkbox to mark pills as taken
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Transform.scale(
                    scale: 1.3,
                    child: Checkbox(
                      value: pill.takenDates.containsKey(timeKey),
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

  // Memoized functions to avoid recreating colors and icons
  Color _getCardColor(String status) {
    switch (status) {
      case "upcoming":
        return Colors.grey[100]!;
      case "overdue":
        return Colors.red[50]!;
      case "due-now":
        return Colors.orange[50]!;
      case "taken":
        return Colors.green[50]!;
      case "missed":
        return Colors.red[50]!;
      default:
        return Color(0xFFE6F2F9); // Light blue
    }
  }

  Color _getTextColor(String status) {
    switch (status) {
      case "upcoming":
        return Colors.grey[800]!;
      case "overdue":
        return Colors.red[800]!;
      case "due-now":
        return Colors.orange[800]!;
      case "taken":
        return Colors.green[800]!;
      case "missed":
        return Colors.red[800]!;
      default:
        return Color(0xFF015C92); // Dark blue
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case "upcoming":
        return Icons.schedule;
      case "overdue":
        return Icons.warning_rounded;
      case "due-now":
        return Icons.notifications_active;
      case "taken":
        return Icons.check_circle;
      case "missed":
        return Icons.warning_rounded;
      default:
        return Icons.medication;
    }
  }
}

// Extract buttons into separate widget to optimize rebuilds
class OverlayButtonGrid extends StatelessWidget {
  final double screenWidth;
  final double screenHeight;
  final MyProvider provider;

  const OverlayButtonGrid({
    Key? key,
    required this.screenWidth,
    required this.screenHeight,
    required this.provider,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  OverlayButton(
                    assetName: "location",
                    onTap: () =>
                        Navigator.pushNamed(context, LiveTracking.routeName),
                  ),
                  SizedBox(height: screenHeight * 0.025),
                  Text(
                    localizations.liveTracking,
                    style: Localizations.localeOf(context).languageCode == 'en'
                        ? GoogleFonts.albertSans(
                            color: Colors.black,
                            fontSize: screenWidth * 0.05,
                            fontWeight: FontWeight.w500,
                            height: 1.1, // Tighter line height
                          )
                        : Theme.of(context).textTheme.titleSmall!.copyWith(
                              color: Colors.black,
                              fontSize: screenWidth * 0.05,
                              fontWeight: FontWeight.w500,
                              height: 1.1, // Tighter line height
                            ),
                    textAlign: TextAlign.center,
                    maxLines: 2, // Allow up to 2 lines
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
                    localizations.calendar,
                    style: Localizations.localeOf(context).languageCode == 'en'
                        ? GoogleFonts.albertSans(
                            color: Colors.black,
                            fontSize: screenWidth * 0.05,
                            fontWeight: FontWeight.w500,
                            height: 1.1, // Tighter line height
                          )
                        : Theme.of(context).textTheme.titleSmall!.copyWith(
                              color: Colors.black,
                              fontSize: screenWidth * 0.05,
                              fontWeight: FontWeight.w500,
                              height: 1.1, // Tighter line height
                            ),
                    textAlign: TextAlign.center,
                    maxLines: 2, // Allow up to 2 lines
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
                    localizations.nearestHospitals,
                    style: Localizations.localeOf(context).languageCode == 'en'
                        ? GoogleFonts.albertSans(
                            color: Colors.black,
                            fontSize: screenWidth * 0.05,
                            fontWeight: FontWeight.w500,
                            height: 1.1, // Tighter line height
                          )
                        : Theme.of(context).textTheme.titleSmall!.copyWith(
                              color: Colors.black,
                              fontSize: screenWidth * 0.05,
                              fontWeight: FontWeight.w500,
                              height: 1.1, // Tighter line height
                            ),
                    textAlign: TextAlign.center,
                    maxLines: 2, // Allow up to 2 lines
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: screenHeight * 0.03),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                    localizations.messages,
                    style: Localizations.localeOf(context).languageCode == 'en'
                        ? GoogleFonts.albertSans(
                            color: Colors.black,
                            fontSize: screenWidth * 0.05,
                            fontWeight: FontWeight.w500,
                          )
                        : Theme.of(context).textTheme.titleSmall!.copyWith(
                              color: Colors.black,
                              fontSize: screenWidth * 0.05,
                              fontWeight: FontWeight.w500,
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
                      Navigator.pushNamed(
                          context, MedicineSearchScreen.routeName);
                    },
                  ),
                  SizedBox(height: screenHeight * 0.025),
                  Text(
                    localizations.medicines,
                    style: Localizations.localeOf(context).languageCode == 'en'
                        ? GoogleFonts.albertSans(
                            color: Colors.black,
                            fontSize: screenWidth * 0.05,
                            fontWeight: FontWeight.w500,
                          )
                        : Theme.of(context).textTheme.titleSmall!.copyWith(
                              color: Colors.black,
                              fontSize: screenWidth * 0.05,
                              fontWeight: FontWeight.w500,
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
                    onTap: () =>
                        Navigator.pushNamed(context, ChatBot.routeName),
                  ),
                  SizedBox(height: screenHeight * 0.025),
                  Text(
                    localizations.chatbot,
                    style: Localizations.localeOf(context).languageCode == 'en'
                        ? GoogleFonts.albertSans(
                            color: Colors.black,
                            fontSize: screenWidth * 0.05,
                            fontWeight: FontWeight.w500,
                          )
                        : Theme.of(context).textTheme.titleSmall!.copyWith(
                              color: Colors.black,
                              fontSize: screenWidth * 0.05,
                              fontWeight: FontWeight.w500,
                            ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
