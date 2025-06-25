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

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _checkUserRoleAndLoadData();
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
        final isTaken = pill.isTakenOnDate(_selectedDay!);
        final takenDate = pill.getTakenDateForDate(_selectedDay!);

        return Dismissible(
          key: Key("${pill.id}_$selectedDate"),
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: EdgeInsets.only(right: 5.w),
            child: Icon(Icons.delete, color: Colors.white, size: 6.w),
          ),
          direction:
              _isReadOnly ? DismissDirection.none : DismissDirection.endToStart,
          confirmDismiss: (direction) async {
            if (_isReadOnly) return false;

            return await showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text("Confirm", style: TextStyle(fontSize: 17.sp)),
                  content: Text(
                    "Are you sure you want to delete this pill?",
                    style: TextStyle(fontSize: 15.sp),
                  ),
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
                );
              },
            );
          },
          onDismissed: (direction) async {
            if (_isReadOnly) return;

            try {
              // Only remove from Firebase if this is the start date
              final startDate = DateTime(
                  pill.dateTime.year, pill.dateTime.month, pill.dateTime.day);

              if (startDate.isAtSameMomentAs(selectedDate)) {
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
            child: Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
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
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${pill.dosage} - ${pill.timesPerDay} Times per day',
                          style: TextStyle(
                            color: _getPillSubtitleColor(pill),
                            fontSize: 13.sp,
                          ),
                        ),
                        SizedBox(height: 0.5.h),
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(1.w),
                              decoration: BoxDecoration(
                                color: isTaken
                                    ? Colors.green[100]
                                    : (pill.missed
                                        ? Colors.red[100]
                                        : Colors.white30),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.access_time,
                                color: isTaken
                                    ? Colors.green[700]
                                    : (pill.missed
                                        ? Colors.red[700]
                                        : Colors.white),
                                size: 4.w,
                              ),
                            ),
                            SizedBox(width: 1.w),
                            Flexible(
                              child: Text(
                                pill.getFormattedTimes(),
                                style: TextStyle(
                                  color: _getPillSubtitleColor(pill),
                                  fontSize: 13.sp,
                                ),
                                softWrap: true,
                                overflow: TextOverflow.visible,
                              ),
                            ),
                            if (pill.allowSnooze)
                              Padding(
                                padding: EdgeInsets.only(left: 2.w),
                                child: Icon(
                                  Icons.snooze,
                                  color: isTaken
                                      ? Colors.green[700]
                                      : (pill.missed
                                          ? Colors.red[700]
                                          : Colors.white),
                                  size: 4.w,
                                ),
                              ),
                          ],
                        ),
                        if (isTaken && takenDate != null)
                          Text(
                            'Taken at: ${DateFormat('h:mm a').format(takenDate)}',
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: Colors.green[700],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        if (pill.missed && !isTaken)
                          Text(
                            'Missed!',
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: Colors.red[700],
                              fontWeight: FontWeight.bold,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
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

                              if (startDate.isAtSameMomentAs(selectedDate)) {
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
                ),
                // Add checkbox to mark as taken - only for elders
                if (!_isReadOnly)
                  Padding(
                    padding: EdgeInsets.only(right: 4.w),
                    child: Transform.scale(
                      scale: 1.2,
                      child: Checkbox(
                        value: isTaken,
                        activeColor: Colors.green[700],
                        checkColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onChanged: (bool? value) {
                          if (value != null) {
                            _markPillAsTaken(pill, value);
                          }
                        },
                      ),
                    ),
                  ),
                // For guardians, just show if pill was taken or not
                if (_isReadOnly)
                  Padding(
                    padding: EdgeInsets.only(right: 4.w),
                    child: Icon(
                      _getPillStatusIcon(pill),
                      color: isTaken
                          ? Colors.green[700]
                          : (pill.missed ? Colors.red[700] : Colors.orange),
                      size: 6.w,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
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

      // Update local state immediately for better performance
      setState(() {
        // Update the pill in the local _pills map
        pill.markTakenOnDate(_selectedDay!, isTaken);
        if (isTaken) {
          pill.missed = false;
        }
      });

      // Show immediate feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isTaken
                ? '${pill.name} marked as taken'
                : '${pill.name} marked as not taken',
            style: TextStyle(fontSize: 14.sp),
          ),
          duration: Duration(seconds: 1),
        ),
      );

      // Sync with Firebase in the background
      _syncPillToFirebase(pill);
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

  // Sync pill to Firebase in background
  Future<void> _syncPillToFirebase(PillModel pill) async {
    try {
      await FirebaseManager.updatePill(pill);
      print('Pill synced to Firebase successfully: ${pill.name}');
    } catch (e) {
      print('Error syncing pill to Firebase: $e');
      // Optionally show error message to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Warning: Changes may not be saved',
            style: TextStyle(fontSize: 12.sp),
          ),
          backgroundColor: Colors.orange,
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
    if (pill.isTakenOnDate(_selectedDay!)) {
      return Colors.green[50]!;
    } else if (pill.missed) {
      return Colors.red[50]!;
    } else {
      return Color(0xFF015C92);
    }
  }

  Color _getPillTextColor(PillModel pill) {
    if (pill.isTakenOnDate(_selectedDay!)) {
      return Colors.green[700]!;
    } else if (pill.missed) {
      return Colors.red[700]!;
    } else {
      return Colors.white;
    }
  }

  Color _getPillSubtitleColor(PillModel pill) {
    if (pill.isTakenOnDate(_selectedDay!)) {
      return Colors.green[700]!.withAlpha(204); // 0.8 opacity
    } else if (pill.missed) {
      return Colors.red[700]!.withAlpha(204); // 0.8 opacity
    } else {
      return Colors.white70;
    }
  }

  IconData _getPillStatusIcon(PillModel pill) {
    if (pill.isTakenOnDate(_selectedDay!)) {
      return Icons.check_circle;
    } else if (pill.missed) {
      return Icons.warning_rounded;
    } else {
      return Icons.medication;
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
  late List<TimeOfDay> _selectedTimes;
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
    _treatmentPeriod =
        existingPill?.duration ?? 7; // Initialize with duration if existing
    _selectedDate = existingPill?.dateTime ?? DateTime.now();

    // Initialize times - use existing pill times or default times
    if (existingPill != null && existingPill.times.isNotEmpty) {
      _selectedTimes = List.from(existingPill.times);
    } else {
      _selectedTimes = [TimeOfDay(hour: 8, minute: 0)];
    }

    _allowSnooze = existingPill?.allowSnooze ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // Helper method to format time for display
  String _formatTime(TimeOfDay time) {
    final hour = time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$hour12:$minute $period';
  }

  // Update times when times per day changes
  void _updateTimesForCount(int count) {
    setState(() {
      if (count > _selectedTimes.length) {
        // Add more times
        while (_selectedTimes.length < count) {
          // Add times with reasonable spacing (e.g., every 4 hours)
          final lastTime = _selectedTimes.last;
          final nextHour = (lastTime.hour + 4) % 24;
          _selectedTimes
              .add(TimeOfDay(hour: nextHour, minute: lastTime.minute));
        }
      } else if (count < _selectedTimes.length) {
        // Remove excess times
        _selectedTimes = _selectedTimes.take(count).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Color(0xFF015C92); // App's primary color

    return Padding(
      padding: EdgeInsets.all(4.w),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min, // This is key!
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
                              _updateTimesForCount(_timesPerDay);
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

              // Multiple Time Pickers
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
                      'Reminder Times',
                      style: TextStyle(
                        fontSize: 15.sp,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 1.h),
                    ...List.generate(_timesPerDay, (index) {
                      return Padding(
                        padding: EdgeInsets.only(bottom: 1.h),
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.access_time,
                              size: 5.w, color: primaryColor),
                          title: Text(
                            'Time ${index + 1}',
                            style: TextStyle(fontSize: 15.sp),
                          ),
                          subtitle: Text(
                            _formatTime(_selectedTimes[index]),
                            style: TextStyle(fontSize: 14.sp),
                          ),
                          trailing: Icon(Icons.edit, color: primaryColor),
                          onTap: () async {
                            final TimeOfDay? picked = await showTimePicker(
                              context: context,
                              initialTime: _selectedTimes[index],
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
                            if (picked != null &&
                                picked != _selectedTimes[index]) {
                              setState(() {
                                _selectedTimes[index] = picked;
                              });
                            }
                          },
                        ),
                      );
                    }),
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
                  isThreeLine: true,
                  title: Text(
                    'Snooze Reminder (5 min before)',
                    style: TextStyle(fontSize: 15.sp),
                    overflow: TextOverflow.visible,
                    softWrap: true,
                  ),
                  subtitle: SizedBox.shrink(),
                  secondary: Icon(Icons.notifications_active,
                      size: 5.w, color: primaryColor),
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
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      'Cancel',
                      style: TextStyle(fontSize: 15.sp, color: primaryColor),
                    ),
                  ),
                  SizedBox(width: 3.w),
                  ElevatedButton(
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
                        // Create pill object
                        final pill = PillModel(
                          name: _nameController.text,
                          dosage: _dosageController.text,
                          timesPerDay: _timesPerDay,
                          duration: _treatmentPeriod,
                          dateTime: DateTime(
                            _selectedDate.year,
                            _selectedDate.month,
                            _selectedDate.day,
                            _selectedTimes.first.hour,
                            _selectedTimes.first.minute,
                          ),
                          times: _selectedTimes,
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
