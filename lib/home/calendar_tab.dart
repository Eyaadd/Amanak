import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:amanak/models/pill_model.dart';
import 'package:amanak/firebase/firebase_manager.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CalendarTab extends StatefulWidget {
  const CalendarTab({super.key});

  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<PillModel>> _pills = {};
  bool _isLoading = true;
  bool _isReadOnly = false;
  String _currentUserRole = "";
  String _displayUserId = "";
  String _displayName = "";
  late List<TimeOfDay> _timesList;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _checkUserRoleAndLoadData();
    _timesList = [];
  }

  // Helper method to refresh data safely
  void refreshData() {
    _checkUserRoleAndLoadData();
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
        _loadPills(
            _displayUserId); // Don't await here as _loadPills handles its own state
      }
    } catch (e) {
      print('Error checking user role: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Separated into its own function to handle state internally
  Future<void> _loadPills([String? userId]) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final targetUserId = userId ?? FirebaseAuth.instance.currentUser?.uid;
      if (targetUserId != null) {
        final pillsList = await FirebaseManager.getPills(userId: targetUserId);

        // Group pills by date and mark all days in duration
        final Map<DateTime, List<PillModel>> groupedPills = {};
        for (var pill in pillsList) {
          // Add pill to its start date
          final startDate = DateTime(
              pill.dateTime.year, pill.dateTime.month, pill.dateTime.day);

          if (groupedPills[startDate] == null) {
            groupedPills[startDate] = [];
          }
          groupedPills[startDate]!.add(pill);

          // Mark all days in the duration with the pill
          for (int i = 1; i < pill.duration; i++) {
            final nextDate = startDate.add(Duration(days: i));
            final nextDateKey =
                DateTime(nextDate.year, nextDate.month, nextDate.day);

            if (groupedPills[nextDateKey] == null) {
              groupedPills[nextDateKey] = [];
            }
            groupedPills[nextDateKey]!.add(pill);
          }
        }

        setState(() {
          _pills = groupedPills;
          _isLoading = false;
        });
      } else {
        setState(() {
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

  void _showAddPillDialog() {
    // Only show if not in read-only mode
    if (_isReadOnly) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Guardian view is read-only. You cannot add medications.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 85.w,
            maxHeight: 85.h,
          ),
          child: ModernAddPillForm(
            onSubmit: (pillModel) async {
              try {
                // Add to Firebase
                final pillId = await FirebaseManager.addPill(pillModel);

                if (pillId.isEmpty) {
                  throw Exception("Invalid pill ID returned from Firebase");
                }

                // Update local state with the returned ID
                final updatedPillModel = pillModel.copyWith(id: pillId);

                // Update UI - mark all days in the duration
                setState(() {
                  final startDate = DateTime(
                      updatedPillModel.dateTime.year,
                      updatedPillModel.dateTime.month,
                      updatedPillModel.dateTime.day);

                  // Add pill to its start date
                  if (_pills[startDate] != null) {
                    _pills[startDate]!.add(updatedPillModel);
                  } else {
                    _pills[startDate] = [updatedPillModel];
                  }

                  // Mark all days in the duration
                  for (int i = 1; i < updatedPillModel.duration; i++) {
                    final nextDate = startDate.add(Duration(days: i));
                    final nextDateKey =
                        DateTime(nextDate.year, nextDate.month, nextDate.day);

                    if (_pills[nextDateKey] != null) {
                      _pills[nextDateKey]!.add(updatedPillModel);
                    } else {
                      _pills[nextDateKey] = [updatedPillModel];
                    }
                  }
                });

                Navigator.of(context).pop();
              } catch (e) {
                print('Error saving pill: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error saving pill: $e')),
                );
              }
            },
          ),
        ),
      ),
    );
  }

  bool _checkForPillsTomorrow() {
    final tomorrow = DateTime.now().add(Duration(days: 1));
    final tomorrowKey = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
    return _pills[tomorrowKey]?.isNotEmpty ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final hasPillsForTomorrow = _checkForPillsTomorrow();

    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          _isReadOnly ? "${_displayName}'s Medications" : "Medication Reminder",
          style: TextStyle(fontSize: 18.sp),
        ),
        backgroundColor: Color(0xFF015C92),
        foregroundColor: Colors.white,
        leading: null,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, size: 6.w),
            onPressed: refreshData,
          )
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
              color: Theme.of(context).primaryColor,
            ))
          : Padding(
              padding: EdgeInsets.all(4.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Calendar Card - Made larger and centered
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 2.w),
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(3.w),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  DateFormat('MMMM yyyy').format(_focusedDay),
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF015C92),
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.chevron_left,
                                          color: Color(0xFF015C92), size: 6.w),
                                      onPressed: () {
                                        setState(() {
                                          _focusedDay = DateTime(
                                              _focusedDay.year,
                                              _focusedDay.month - 1);
                                        });
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.chevron_right,
                                          color: Color(0xFF015C92), size: 6.w),
                                      onPressed: () {
                                        setState(() {
                                          _focusedDay = DateTime(
                                              _focusedDay.year,
                                              _focusedDay.month + 1);
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(height: 1.h),
                            TableCalendar(
                              firstDay: DateTime.utc(2010, 10, 16),
                              lastDay: DateTime.utc(2030, 3, 14),
                              focusedDay: _focusedDay,
                              calendarFormat: _calendarFormat,
                              headerVisible: false,
                              daysOfWeekHeight: 4.h,
                              rowHeight: 5.h,
                              eventLoader: (day) {
                                final date =
                                    DateTime(day.year, day.month, day.day);
                                return _pills[date] ?? [];
                              },
                              selectedDayPredicate: (day) =>
                                  isSameDay(_selectedDay, day),
                              onDaySelected: (selectedDay, focusedDay) {
                                setState(() {
                                  _selectedDay = selectedDay;
                                  _focusedDay = focusedDay;
                                });
                              },
                              onFormatChanged: (format) {
                                if (_calendarFormat != format) {
                                  setState(() {
                                    _calendarFormat = format;
                                  });
                                }
                              },
                              onPageChanged: (focusedDay) {
                                setState(() {
                                  _focusedDay = focusedDay;
                                });
                              },
                              calendarStyle: CalendarStyle(
                                selectedDecoration: BoxDecoration(
                                  color: Color(0xFF015C92),
                                  shape: BoxShape.circle,
                                ),
                                todayDecoration: BoxDecoration(
                                  color: Colors.blue.withAlpha(128),
                                  shape: BoxShape.circle,
                                ),
                                weekendTextStyle: TextStyle(color: Colors.red),
                                outsideTextStyle:
                                    TextStyle(color: Colors.grey[400]),
                                markersMaxCount: 3,
                                markerDecoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              daysOfWeekStyle: DaysOfWeekStyle(
                                weekdayStyle:
                                    TextStyle(fontWeight: FontWeight.bold),
                                weekendStyle: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 2.h),

                  // Pill Reminder Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isReadOnly
                                ? '${_displayName}\'s Medications'
                                : 'Pill Reminder',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            hasPillsForTomorrow
                                ? 'Don\'t forget schedule for tomorrow'
                                : 'No reminders for tomorrow',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      // Add pill button at the top - only show for elders
                      if (!_isReadOnly)
                        Container(
                          height: 10.w,
                          width: 10.w,
                          decoration: BoxDecoration(
                            color: Color(0xFF015C92),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon:
                                Icon(Icons.add, color: Colors.white, size: 5.w),
                            onPressed: _showAddPillDialog,
                          ),
                        ),
                    ],
                  ),

                  SizedBox(height: 2.h),

                  // Pills List for selected day
                  Expanded(
                    child: _selectedDay != null
                        ? _buildPillsList()
                        : Center(
                            child: Text(
                              'Select a day to see pills',
                              style: TextStyle(fontSize: 15.sp),
                            ),
                          ),
                  ),

                  // Bottom Buttons - Only show for elders
                  if (!_isReadOnly)
                    Padding(
                      padding: EdgeInsets.only(top: 3.h, bottom: 2.h),
                      child: Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 6.h,
                              child: OutlinedButton(
                                onPressed: _showAddPillDialog,
                                child: Text('Add Pills',
                                    style: TextStyle(fontSize: 15.sp)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Color(0xFF015C92),
                                  side: BorderSide(color: Color(0xFF015C92)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 3.w),
                          Expanded(
                            child: SizedBox(
                              height: 6.h,
                              child: ElevatedButton(
                                onPressed: () {
                                  // Handle prescription
                                },
                                child: Text('Scan Prescription',
                                    style: TextStyle(fontSize: 15.sp)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF015C92),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
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

  Widget _buildPillsList() {
    final selectedDate = DateTime(
      _selectedDay!.year,
      _selectedDay!.month,
      _selectedDay!.day,
    );

    final pillsForSelectedDay = _pills[selectedDate] ?? [];

    if (pillsForSelectedDay.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 2.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.medication_outlined,
                  size: 20.w,
                  color: Colors.grey[400],
                ),
                SizedBox(height: 2.h),
                Text(
                  'No medications for this day',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16.sp,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: pillsForSelectedDay.length,
      itemBuilder: (context, index) {
        final pill = pillsForSelectedDay[index];
        return _buildPillCard(pill);
      },
    );
  }

  Widget _buildPillCard(PillModel pill) {
    final timeStatuses = _getTimeStatuses(pill);
    
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

        return Dismissible(
      key: Key(pill.id),
      direction: _isReadOnly ? DismissDirection.none : DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 4.w),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(10),
        ),
            child: Icon(Icons.delete, color: Colors.white, size: 6.w),
          ),
          confirmDismiss: (direction) async {
            if (_isReadOnly) return false;
            return await showDialog(
              context: context,
          builder: (context) => AlertDialog(
            title: Text("Delete Pill?"),
            content: Text("Are you sure you want to delete this pill?"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text("CANCEL", style: TextStyle(fontSize: 14.sp)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text("DELETE",
                          style: TextStyle(color: Colors.red, fontSize: 14.sp)),
                    ),
                  ],
          ),
            );
          },
          onDismissed: (direction) async {
            if (_isReadOnly) return;

            try {
              // Only remove from Firebase if this is the start date
              final startDate = DateTime(
                  pill.dateTime.year, pill.dateTime.month, pill.dateTime.day);

          if (startDate.isAtSameMomentAs(_selectedDay!)) {
                await FirebaseManager.deletePill(pill.id);
              }

              // Update local state and reload to reflect changes across all days
              refreshData();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Pill deleted')),
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error deleting pill: $e')),
              );
            }
          },
          child: Container(
            margin: EdgeInsets.only(bottom: 2.w),
            decoration: BoxDecoration(
              color: _getPillCardColor(pill),
              borderRadius: BorderRadius.circular(10),
            ),
        child: Column(
              children: [
            // Pill header
            ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                    leading: Container(
                      padding: EdgeInsets.all(2.w),
                      child: Icon(
                        _getPillStatusIcon(pill),
                        color: _getPillTextColor(pill),
                        size: 6.w,
                      ),
                    ),
                    title: Text(
                      pill.name,
                      style: TextStyle(
                        color: _getPillTextColor(pill),
                        fontWeight: FontWeight.bold,
                        fontSize: 15.sp,
                      ),
                    ),
              subtitle: Text(
                '${pill.dosage} - ${pill.timesPerDay} ${pill.timesPerDay > 1 ? "times" : "time"} per day',
                          style: TextStyle(
                            color: _getPillSubtitleColor(pill),
                            fontSize: 13.sp,
                          ),
                        ),
              trailing: !_isReadOnly
                ? IconButton(
                    icon: Icon(
                      Icons.edit,
                      color: _getPillTextColor(pill),
                      size: 5.w,
                    ),
                    onPressed: () {
                      // Only allow editing from the start date
                      final startDate = DateTime(pill.dateTime.year,
                          pill.dateTime.month, pill.dateTime.day);

                      if (startDate.isAtSameMomentAs(_selectedDay!)) {
                        _showEditPillDialog(pill);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'Edit from the start date (${DateFormat('MMM d').format(startDate)})')),
                        );
                      }
                    },
                  )
                : null,
            ),
            // Time slots
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
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
                      timeColor = _getPillTextColor(pill).withOpacity(0.7);
                  }

                  return Container(
                    padding: EdgeInsets.symmetric(vertical: 1.h),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.withOpacity(0.2),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(1.w),
                              decoration: BoxDecoration(
                                  color: status == "taken"
                                    ? Colors.green[100]
                                      : (status == "missed"
                                        ? Colors.red[100]
                                        : Colors.white30),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.access_time,
                                  color: timeColor,
                                size: 4.w,
                              ),
                            ),
                              SizedBox(width: 2.w),
                            Text(
                                timeStatus['time']!,
                              style: TextStyle(
                                  color: timeColor,
                                fontSize: 13.sp,
                                  fontWeight: status == "due-now" ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              SizedBox(width: 2.w),
                              Text(
                                _getStatusText(status),
                                style: TextStyle(
                                  color: timeColor,
                                  fontSize: 11.sp,
                                  fontStyle: FontStyle.italic,
                              ),
                            ),
                            if (pill.allowSnooze)
                              Padding(
                                padding: EdgeInsets.only(left: 2.w),
                                child: Icon(
                                  Icons.snooze,
                                    color: timeColor,
                                  size: 4.w,
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
                          if (value != null) {
                                  _markTimeAsTaken(pill, timeStatus['timeKey']!, value);
                          }
                        },
                      ),
                    ),
                if (_isReadOnly)
                  Padding(
                            padding: EdgeInsets.only(right: 2.w),
                    child: Icon(
                              status == "taken" ? Icons.check_circle : Icons.pending_actions,
                              color: status == "taken" ? Colors.green[700] : Colors.orange,
                              size: 5.w,
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
          ),
    );
  }

  // Mark a pill as taken or not taken
  Future<void> _markPillAsTaken(PillModel pill, bool isTaken) async {
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

      // Update the pill with the new taken status
      final updatedPill = pill.copyWith(
        taken: isTaken,
        takenDate: isTaken ? DateTime.now() : null,
        missed: isTaken ? false : pill.missed, // Reset missed status if taken
      );

      // Update in Firebase
      await FirebaseManager.updatePill(updatedPill);

      // Update local state
      refreshData();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isTaken
                ? '${pill.name} marked as taken'
                : '${pill.name} marked as not taken',
            style: TextStyle(fontSize: 14.sp),
          ),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error updating pill status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error updating pill status',
            style: TextStyle(fontSize: 14.sp),
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showEditPillDialog(PillModel pill) {
    // Only allow elder to edit pills
    if (_isReadOnly) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Guardian view is read-only. Cannot edit medications.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 85.w,
            maxHeight: 85.h,
          ),
          child: ModernAddPillForm(
            existingPill: pill,
            onSubmit: (updatedPill) async {
              try {
                // Preserve the ID
                final pillWithId = updatedPill.copyWith(id: pill.id);

                // Update in Firebase
                await FirebaseManager.updatePill(pillWithId);

                // Reload all pills to update across all days
                refreshData();

                Navigator.of(context).pop();
              } catch (e) {
                print('Error updating pill: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error updating pill: $e')),
                );
              }
            },
          ),
        ),
      ),
    );
  }

  // Helper methods for pill card UI
  Color _getPillCardColor(PillModel pill) {
    final timeStatuses = _getTimeStatuses(pill);
    
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

    switch (overallStatus) {
      case "taken":
      return Colors.green[50]!;
      case "missed":
      return Colors.red[50]!;
      case "due-now":
        return Colors.orange[50]!;
      default:
      return Color(0xFF015C92);
    }
  }

  Color _getPillTextColor(PillModel pill) {
    final timeStatuses = _getTimeStatuses(pill);
    
    // Determine overall text color based on most urgent status
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

    switch (overallStatus) {
      case "taken":
      return Colors.green[700]!;
      case "missed":
      return Colors.red[700]!;
      case "due-now":
        return Colors.orange[700]!;
      default:
      return Colors.white;
    }
  }

  Color _getPillSubtitleColor(PillModel pill) {
    final timeStatuses = _getTimeStatuses(pill);
    
    // Determine overall subtitle color based on most urgent status
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

    switch (overallStatus) {
      case "taken":
      return Colors.green[700]!.withAlpha(204); // 0.8 opacity
      case "missed":
      return Colors.red[700]!.withAlpha(204); // 0.8 opacity
      case "due-now":
        return Colors.orange[700]!.withAlpha(204); // 0.8 opacity
      default:
      return Colors.white70;
    }
  }

  IconData _getPillStatusIcon(PillModel pill) {
    final timeStatuses = _getTimeStatuses(pill);
    
    // Determine overall icon based on most urgent status
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

    switch (overallStatus) {
      case "taken":
      return Icons.check_circle;
      case "missed":
      return Icons.warning_rounded;
      case "due-now":
        return Icons.notifications_active;
      default:
      return Icons.medication;
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

  // Mark a specific time as taken
  Future<void> _markTimeAsTaken(PillModel pill, String timeKey, bool isTaken) async {
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
      if (isTaken) {
        updatedPill.markTimeTaken(timeKey, DateTime.now());
      } else {
        updatedPill.markTimeNotTaken(timeKey);
      }

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

      if (isTaken) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${pill.name} marked as taken for ${timeKey.replaceAll('-', ':')}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error marking pill time as taken: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating pill status'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
}

class ModernAddPillForm extends StatefulWidget {
  final Function(PillModel) onSubmit;
  final PillModel? existingPill;

  const ModernAddPillForm({
    Key? key,
    required this.onSubmit,
    this.existingPill,
  }) : super(key: key);

  @override
  _ModernAddPillFormState createState() => _ModernAddPillFormState();
}

class _ModernAddPillFormState extends State<ModernAddPillForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _dosageController;
  late TextEditingController _noteController;
  late int _timesPerDay;
  late int _duration;
  late DateTime _selectedDate;
  late List<TimeOfDay> _timesList;
  late bool _allowSnooze;
  late int _treatmentPeriod; // Total treatment period in days

  @override
  void initState() {
    super.initState();
    final existingPill = widget.existingPill;
    _nameController = TextEditingController(text: existingPill?.name ?? '');
    _dosageController = TextEditingController(text: existingPill?.dosage ?? '');
    _noteController = TextEditingController(text: existingPill?.note ?? '');
    _timesPerDay = existingPill?.timesPerDay ?? 1;
    _duration = existingPill?.duration ?? 7;
    _treatmentPeriod = existingPill?.duration ?? 7;
    _selectedDate = existingPill?.dateTime ?? DateTime.now();
    _allowSnooze = existingPill?.allowSnooze ?? true;
    _timesList = [];
    if (existingPill != null && existingPill.times.isNotEmpty) {
      _timesList = existingPill.times.map((t) => TimeOfDay(hour: t['hour'] ?? 8, minute: t['minute'] ?? 0)).toList();
    }
    // Ensure _timesList matches _timesPerDay
    _syncTimesListWithTimesPerDay();
  }

  void _syncTimesListWithTimesPerDay() {
    if (_timesList.length < _timesPerDay) {
      _timesList.addAll(List.generate(_timesPerDay - _timesList.length, (_) => TimeOfDay(hour: 8, minute: 0)));
    } else if (_timesList.length > _timesPerDay) {
      _timesList = _timesList.sublist(0, _timesPerDay);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Color(0xFF015C92); // App's primary color

    return Padding(
      padding: EdgeInsets.all(4.w),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.existingPill != null
                    ? 'Edit Medication'
                    : 'Add New Medication',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              SizedBox(height: 2.h),

              // Pill Name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Medication Name',
                  prefixIcon:
                      Icon(Icons.medication, size: 5.w, color: primaryColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(3.w),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(3.w),
                    borderSide: BorderSide(color: primaryColor, width: 2),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 2.h,
                    horizontal: 3.w,
                  ),
                ),
                style: TextStyle(fontSize: 15.sp),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter medication name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 2.h),

              // Dosage
              TextFormField(
                controller: _dosageController,
                decoration: InputDecoration(
                  labelText: 'Dosage (e.g., 500mg)',
                  prefixIcon:
                      Icon(Icons.biotech, size: 5.w, color: primaryColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(3.w),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(3.w),
                    borderSide: BorderSide(color: primaryColor, width: 2),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 2.h,
                    horizontal: 3.w,
                  ),
                ),
                style: TextStyle(fontSize: 15.sp),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter dosage';
                  }
                  return null;
                },
              ),
              SizedBox(height: 2.h),

              // Times per day
              Container(
                padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.h),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(3.w),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Times Per Day',
                      style: TextStyle(
                        fontSize: 15.sp,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 1.h),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 5.w, color: primaryColor),
                        SizedBox(width: 3.w),
                        DropdownButton<int>(
                          value: _timesPerDay,
                          items: [1, 2, 3, 4, 5].map((int value) {
                            return DropdownMenuItem<int>(
                              value: value,
                              child: Text(
                                '$value time(s)',
                                style: TextStyle(fontSize: 15.sp),
                              ),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            setState(() {
                              _timesPerDay = newValue!;
                              _syncTimesListWithTimesPerDay();
                            });
                          },
                          underline: Container(),
                          icon: Icon(Icons.arrow_drop_down, color: primaryColor),
                        ),
                      ],
                    ),
                    SizedBox(height: 1.h),
                    // Multiple time pickers
                    ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: _timesList.length,
                      itemBuilder: (context, index) {
                        if (index >= _timesList.length) return SizedBox.shrink();
                        return Padding(
                          padding: EdgeInsets.only(bottom: 1.h),
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.access_time, size: 5.w, color: primaryColor),
                            title: Text('Reminder Time #${index + 1}', style: TextStyle(fontSize: 15.sp)),
                            subtitle: Text(_timesList[index].format(context), style: TextStyle(fontSize: 14.sp)),
                            trailing: Icon(Icons.edit, color: primaryColor),
                            onTap: () async {
                              final TimeOfDay? picked = await showTimePicker(
                                context: context,
                                initialTime: _timesList[index],
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: ColorScheme.light(
                                        primary: primaryColor,
                                        onPrimary: Colors.white,
                                        onSurface: Colors.black,
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (picked != null && picked != _timesList[index]) {
                                setState(() {
                                  _timesList[index] = picked;
                                });
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(height: 2.h),

              // Total Treatment Period
              Container(
                padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.h),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(3.w),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Treatment Period',
                      style: TextStyle(
                        fontSize: 15.sp,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 1.h),
                    Row(
                      children: [
                        Icon(Icons.calendar_month,
                            size: 5.w, color: primaryColor),
                        SizedBox(width: 3.w),
                        DropdownButton<int>(
                          value: _treatmentPeriod,
                          items: [1, 3, 5, 7, 14, 21, 28, 30, 60, 90]
                              .map((int value) {
                            return DropdownMenuItem<int>(
                              value: value,
                              child: Text(
                                '$value day(s)',
                                style: TextStyle(fontSize: 15.sp),
                              ),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            setState(() {
                              _treatmentPeriod = newValue!;
                              _duration =
                                  newValue; // Set duration to match treatment period
                            });
                          },
                          underline: Container(),
                          icon:
                              Icon(Icons.arrow_drop_down, color: primaryColor),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 2.h),

              // Date picker
              Container(
                padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.h),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(3.w),
                ),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.calendar_today,
                      size: 5.w, color: primaryColor),
                  title: Text(
                    'Start Date',
                    style: TextStyle(fontSize: 15.sp),
                  ),
                  subtitle: Text(
                    DateFormat('MMM d, yyyy').format(_selectedDate),
                    style: TextStyle(fontSize: 14.sp),
                  ),
                  trailing: Icon(Icons.edit, color: primaryColor),
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime.now()
                          .subtract(Duration(days: 1)), // Allow today
                      lastDate: DateTime.now().add(Duration(days: 365)),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.light(
                              primary: primaryColor,
                              onPrimary: Colors.white,
                              onSurface: Colors.black,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null && picked != _selectedDate) {
                      setState(() {
                        _selectedDate = picked;
                      });
                    }
                  },
                ),
              ),
              SizedBox(height: 2.h),

              // Allow snooze
              Container(
                padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.h),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(3.w),
                ),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Row(
                    children: [
                      Icon(Icons.notifications_active,
                          size: 5.w, color: primaryColor),
                      SizedBox(width: 3.w),
                      Text(
                        'Snooze Reminder (5 min before)',
                        style: TextStyle(fontSize: 15.sp),
                      ),
                    ],
                  ),
                  value: _allowSnooze,
                  activeColor: primaryColor,
                  onChanged: (value) {
                    setState(() {
                      _allowSnooze = value;
                    });
                  },
                ),
              ),
              SizedBox(height: 2.h),

              // Notes
              TextFormField(
                controller: _noteController,
                decoration: InputDecoration(
                  labelText: 'Notes (optional)',
                  prefixIcon: Icon(Icons.note, size: 5.w, color: primaryColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(3.w),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(3.w),
                    borderSide: BorderSide(color: primaryColor, width: 2),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 2.h,
                    horizontal: 3.w,
                  ),
                ),
                style: TextStyle(fontSize: 15.sp),
                maxLines: 2,
              ),
              SizedBox(height: 3.h),

              // Submit button
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      'Cancel',
                      style: TextStyle(fontSize: 15.sp, color: primaryColor),
                      ),
                    ),
                  ),
                  SizedBox(width: 3.w),
                  Expanded(
                    child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(3.w),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: 6.w,
                        vertical: 1.5.h,
                      ),
                    ),
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                          final times = _timesList.map((t) => {'hour': t.hour, 'minute': t.minute}).toList();
                        final pill = PillModel(
                          name: _nameController.text,
                          dosage: _dosageController.text,
                          timesPerDay: _timesPerDay,
                            duration: _treatmentPeriod,
                          dateTime: DateTime(
                            _selectedDate.year,
                            _selectedDate.month,
                            _selectedDate.day,
                          ),
                            times: times,
                          allowSnooze: _allowSnooze,
                          note: _noteController.text,
                        );
                        widget.onSubmit(pill);
                      }
                    },
                    child: Text(
                      widget.existingPill != null ? 'Update' : 'Add Medication',
                      style: TextStyle(fontSize: 15.sp),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
