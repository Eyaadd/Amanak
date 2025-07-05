import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:amanak/firebase/firebase_manager.dart';
import 'package:amanak/l10n/app_localizations.dart';
import 'package:amanak/models/pill_model.dart';
import 'package:amanak/notifications/noti_service.dart';
import 'package:amanak/provider/my_provider.dart';
import 'package:amanak/provider/pill_provider.dart';
import 'package:amanak/services/database_service.dart';
import 'package:amanak/services/encryption_service.dart';
import 'package:amanak/services/fcm_service.dart';
import 'package:amanak/services/ocr_service.dart';
import 'package:amanak/theme/base_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:table_calendar/table_calendar.dart';

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
  final ImagePicker _picker = ImagePicker();
  bool _isProcessingImage = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;

    // Initialize the pill provider if not already initialized
    Future.microtask(() async {
      final pillProvider = Provider.of<PillProvider>(context, listen: false);
      if (!pillProvider.pills.isNotEmpty) {
        await pillProvider.initialize();
      }
      _updatePillsFromProvider();

      // Add listener to pill provider to update when data changes
      pillProvider.addListener(_onPillProviderChanged);
    });
  }

  @override
  void dispose() {
    // Remove listener when disposing
    final pillProvider = Provider.of<PillProvider>(context, listen: false);
    pillProvider.removeListener(_onPillProviderChanged);
    super.dispose();
  }

  // Callback when pill provider data changes
  void _onPillProviderChanged() {
    if (mounted) {
      _updatePillsFromProvider();
    }
  }

  // Helper method to refresh data safely
  void refreshData() {
    final pillProvider = Provider.of<PillProvider>(context, listen: false);
    pillProvider
        .checkUserRoleAndLoadData()
        .then((_) => _updatePillsFromProvider());
  }

  // Update pills from provider data
  void _updatePillsFromProvider() {
    setState(() {
      _isLoading = true;
    });

    try {
      final pillProvider = Provider.of<PillProvider>(context, listen: false);
      final pillsList = pillProvider.pills;

      // Update read-only status and display name from provider
      _isReadOnly = pillProvider.isReadOnly;
      _displayName = pillProvider.displayName;
      _currentUserRole = pillProvider.currentUserRole;
      _displayUserId = pillProvider.displayUserId;

      // Group pills by date and mark all days in duration
      final Map<DateTime, List<PillModel>> groupedPills = {};
      for (var pill in pillsList) {
        // Add pill to its start date
        final startDate = DateTime(
            pill.dateTime.year, pill.dateTime.month, pill.dateTime.day);

        // For each time in the pill, create a separate entry
        for (int i = 0; i < pill.times.length; i++) {
          // Create a copy of the pill with a single time
          final timeOfDay = pill.times[i];
          final singleTimePill = pill.copyWith(
            times: [timeOfDay],
            timesPerDay: 1, // Set to 1 since we're showing one time per card
          );

          if (groupedPills[startDate] == null) {
            groupedPills[startDate] = [];
          }
          groupedPills[startDate]!.add(singleTimePill);

          // Mark all days in the duration with the pill
          for (int j = 1; j < pill.duration; j++) {
            final nextDate = startDate.add(Duration(days: j));
            final nextDateKey =
                DateTime(nextDate.year, nextDate.month, nextDate.day);

            if (groupedPills[nextDateKey] == null) {
              groupedPills[nextDateKey] = [];
            }
            groupedPills[nextDateKey]!.add(singleTimePill);
          }
        }
      }

      // Sort pills for each day by time
      groupedPills.forEach((date, pills) {
        pills.sort((a, b) {
          if (a.times.isEmpty || b.times.isEmpty) return 0;

          final aTime = a.times.first;
          final bTime = b.times.first;

          // Compare hours first
          if (aTime.hour != bTime.hour) {
            return aTime.hour.compareTo(bTime.hour);
          }

          // If hours are the same, compare minutes
          return aTime.minute.compareTo(bTime.minute);
        });
      });

      setState(() {
        _pills = groupedPills;
        _isLoading = false;
      });
    } catch (e) {
      print('Error updating pills from provider: $e');
      setState(() {
        _isLoading = false;
      });
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

    final dateStr =
        '${_selectedDay!.year}-${_selectedDay!.month}-${_selectedDay!.day}';
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
                // Use the provider to add the pill
                final pillProvider =
                    Provider.of<PillProvider>(context, listen: false);
                final pillId = await pillProvider.addPill(pillModel);

                if (pillId.isEmpty) {
                  throw Exception("Invalid pill ID returned from Firebase");
                }

                // Update local calendar display
                _updatePillsFromProvider();

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

  // Pick image from camera or gallery
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        // Show loading indicator
        setState(() {
          _isProcessingImage = true;
        });

        // Process image with OCR
        await _processPrescriptionImage(File(pickedFile.path));

        // Hide loading indicator
        setState(() {
          _isProcessingImage = false;
        });
      }
    } catch (e) {
      setState(() {
        _isProcessingImage = false;
      });
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  // Process the image with OCR and show results
  Future<void> _processPrescriptionImage(File imageFile) async {
    try {
      // Process image with OCR API
      final medicines = await OCRService.scanPrescription(imageFile);

      if (medicines.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No medicines found in the prescription')),
        );
        return;
      }

      // Show dialog with OCR results
      _showOCRResultsDialog(medicines);
    } catch (e) {
      print('Error processing prescription image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing prescription: $e')),
      );
    }
  }

  // Show image source selection dialog
  void _showImageSourceDialog() {
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
      builder: (context) => AlertDialog(
        title: Text('Scan Prescription'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt),
              title: Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library),
              title: Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Show OCR results dialog
  void _showOCRResultsDialog(List<Map<String, dynamic>> medicines) {
    // Sort medicines by rank
    medicines.sort((a, b) => (a['rank'] as num).compareTo(b['rank'] as num));

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 85.w,
            maxHeight: 85.h,
          ),
          child: Padding(
            padding: EdgeInsets.all(4.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Prescription Results',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF015C92),
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'Found ${medicines.length} medications in your prescription. Tap on a medicine to add it to your calendar.',
                  style: TextStyle(fontSize: 14.sp),
                ),
                SizedBox(height: 2.h),
                Expanded(
                  child: SingleChildScrollView(
                    child: ListView.builder(
                      itemCount: medicines.length,
                      itemBuilder: (context, index) {
                        final medicine = medicines[index];
                        final medicineName = medicine['medicine'] as String;
                        final dosage = medicine['dosage'] as String;
                        final confidence = medicine['confidence'] as double;
                        final confidencePercent =
                            (confidence * 100).toStringAsFixed(0);

                        return Card(
                          margin: EdgeInsets.only(bottom: 2.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: EdgeInsets.all(2.w),
                            title: Text(
                              medicineName,
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Dosage: $dosage',
                                  style: TextStyle(fontSize: 14.sp),
                                ),
                                Text(
                                  'Confidence: $confidencePercent%',
                                  style: TextStyle(fontSize: 12.sp),
                                ),
                              ],
                            ),
                            trailing: Icon(Icons.add_circle,
                                color: Color(0xFF015C92)),
                            onTap: () {
                              // Close the dialog
                              Navigator.pop(context);

                              // Show add pill form pre-filled with the medicine info
                              _showAddPillDialogWithOCRData(
                                  medicineName, dosage);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),
                SizedBox(height: 2.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Close',
                        style: TextStyle(fontSize: 15.sp),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Show add pill dialog pre-filled with OCR data
  void _showAddPillDialogWithOCRData(String medicineName, String dosage) {
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
            initialMedicineName: medicineName,
            initialDosage: dosage,
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

                // Show success message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Medicine added successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
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

  @override
  Widget build(BuildContext context) {
    // Check if tomorrow has any pills scheduled
    final tomorrow = DateTime.now().add(Duration(days: 1));
    final tomorrowDate = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
    final hasPillsForTomorrow = _pills[tomorrowDate]?.isNotEmpty ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Calendar',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: Color(0xFF015C92),
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                  color: Theme.of(context).primaryColor,
                ))
              : SafeArea(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.all(5.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Calendar Card - Modern design
                          Container(
                            margin: EdgeInsets.symmetric(vertical: 3.w),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white,
                                  Color(0xFFF8FBFF),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 20,
                                  offset: Offset(0, 8),
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(4.w),
                              child: Column(
                                children: [
                                  // Calendar Header
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                        vertical: 2.h, horizontal: 3.w),
                                    decoration: BoxDecoration(
                                      color:
                                          Color(0xFF015C92).withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          DateFormat('MMMM yyyy')
                                              .format(_focusedDay),
                                          style: TextStyle(
                                            fontSize: 18.sp,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF015C92),
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.05),
                                                blurRadius: 10,
                                                offset: Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            children: [
                                              IconButton(
                                                icon: Icon(Icons.chevron_left,
                                                    color: Color(0xFF015C92),
                                                    size: 7.w),
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
                                                    color: Color(0xFF015C92),
                                                    size: 7.w),
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
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 2.h),
                                  // Calendar Widget
                                  TableCalendar(
                                    firstDay: DateTime.utc(2010, 10, 16),
                                    lastDay: DateTime.utc(2030, 3, 14),
                                    focusedDay: _focusedDay,
                                    calendarFormat: _calendarFormat,
                                    headerVisible: false,
                                    daysOfWeekHeight: 5.h,
                                    rowHeight: 6.h,
                                    eventLoader: (day) {
                                      final date = DateTime(
                                          day.year, day.month, day.day);
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
                                        gradient: LinearGradient(
                                          colors: [
                                            Color(0xFF015C92),
                                            Color(0xFF0077CC)
                                          ],
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      todayDecoration: BoxDecoration(
                                        color:
                                            Color(0xFF015C92).withOpacity(0.2),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Color(0xFF015C92),
                                          width: 2,
                                        ),
                                      ),
                                      weekendTextStyle: TextStyle(
                                        color: Colors.red[600],
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16.sp,
                                      ),
                                      outsideTextStyle: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 16.sp,
                                      ),
                                      defaultTextStyle: TextStyle(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey[800],
                                      ),
                                      markersMaxCount: 3,
                                      markerDecoration: BoxDecoration(
                                        color: Colors.redAccent,
                                        shape: BoxShape.circle,
                                      ),
                                      markerSize: 6,
                                      markerMargin:
                                          EdgeInsets.symmetric(horizontal: 1),
                                    ),
                                    daysOfWeekStyle: DaysOfWeekStyle(
                                      weekdayStyle: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14.sp,
                                        color: Color(0xFF015C92),
                                      ),
                                      weekendStyle: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14.sp,
                                        color: Colors.red[600],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 3.h),

                          // Pill Reminder Section - Modern design
                          Container(
                            padding: EdgeInsets.all(4.w),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 15,
                                  offset: Offset(0, 5),
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _isReadOnly
                                            ? '${_displayName}\'s Medications'
                                            : 'Pill Reminder',
                                        style: TextStyle(
                                          fontSize: 18.sp,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF015C92),
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                      SizedBox(height: 0.5.h),
                                      Text(
                                        hasPillsForTomorrow
                                            ? 'Don\'t forget schedule for tomorrow'
                                            : 'No reminders for tomorrow',
                                        style: TextStyle(
                                          fontSize: 15.sp,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Add pill button - only show for elders
                                if (!_isReadOnly)
                                  Container(
                                    height: 12.w,
                                    width: 12.w,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0xFF015C92),
                                          Color(0xFF0077CC)
                                        ],
                                      ),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Color(0xFF015C92)
                                              .withOpacity(0.3),
                                          blurRadius: 10,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: IconButton(
                                      icon: Icon(Icons.add,
                                          color: Colors.white, size: 6.w),
                                      onPressed: _showAddPillDialog,
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          SizedBox(height: 3.h),

                          // Pills List for selected day
                          Container(
                            height: 42.h, // Slightly increased height
                            child: _selectedDay != null
                                ? _buildPillsList()
                                : Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.calendar_today_outlined,
                                          size: 15.w,
                                          color: Colors.grey[400],
                                        ),
                                        SizedBox(height: 2.h),
                                        Text(
                                          'Select a day to see pills',
                                          style: TextStyle(
                                            fontSize: 16.sp,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),

                          // Bottom Buttons - Modern design
                          if (!_isReadOnly)
                            Padding(
                              padding: EdgeInsets.only(top: 4.h, bottom: 3.h),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      height: 7.h,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Color(0xFF015C92),
                                          width: 2,
                                        ),
                                      ),
                                      child: OutlinedButton(
                                        onPressed: _showAddPillDialog,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.add_circle_outline,
                                              color: Color(0xFF015C92),
                                              size: 5.w,
                                            ),
                                            SizedBox(width: 2.w),
                                            Flexible(
                                              child: Text(
                                                'Add Pills Manually',
                                                style: TextStyle(
                                                  fontSize: 14.sp,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF015C92),
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ),
                                          ],
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Color(0xFF015C92),
                                          side: BorderSide.none,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 4.w),
                                  Expanded(
                                    child: Container(
                                      height: 7.h,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Color(0xFF015C92),
                                            Color(0xFF0077CC)
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Color(0xFF015C92)
                                                .withOpacity(0.3),
                                            blurRadius: 10,
                                            offset: Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: ElevatedButton(
                                        onPressed: _showImageSourceDialog,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.document_scanner,
                                              color: Colors.white,
                                              size: 5.w,
                                            ),
                                            SizedBox(width: 2.w),
                                            Flexible(
                                              child: Text(
                                                'Scan Prescription',
                                                style: TextStyle(
                                                  fontSize: 14.sp,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ),
                                          ],
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          foregroundColor: Colors.white,
                                          shadowColor: Colors.transparent,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
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
                  ),
                ),

          // Overlay loading indicator when processing image
          if (_isProcessingImage)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(5.w),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: Color(0xFF015C92),
                        ),
                        SizedBox(height: 3.h),
                        Text(
                          'Processing Prescription...',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 1.h),
                        Text(
                          'Please wait while we scan your prescription',
                          style: TextStyle(fontSize: 14.sp),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
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

    // Use a ListView.builder with shrinkWrap to prevent overflow issues
    return ListView.builder(
      shrinkWrap: true,
      physics: AlwaysScrollableScrollPhysics(),
      itemCount: pillsForSelectedDay.length,
      itemBuilder: (context, index) {
        final pill = pillsForSelectedDay[index];
        final isTaken = pill.takenDates.containsKey(_getTimeKeyForPill(pill));
        final takenDate = pill.takenDates[_getTimeKeyForPill(pill)];
        final formattedTime = _formatTime(pill.times.first);

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
              // Store pill info before deletion
              final pillId = pill.id;

              // Immediately remove from local state to prevent the error
              setState(() {
                pillsForSelectedDay.removeWhere((p) => p.id == pillId);
              });

              // Only remove from Firebase if this is the start date
              final startDate = DateTime(
                  pill.dateTime.year, pill.dateTime.month, pill.dateTime.day);

              if (startDate.isAtSameMomentAs(selectedDate)) {
                await FirebaseManager.deletePill(pillId);
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
            margin: EdgeInsets.only(bottom: 3.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isTaken
                    ? [Colors.green[50]!, Colors.green[100]!]
                    : pill.missed
                        ? [Colors.red[50]!, Colors.red[100]!]
                        : [Colors.white, Color(0xFFF8FBFF)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isTaken
                    ? Colors.green[300]!
                    : pill.missed
                        ? Colors.red[300]!
                        : Color(0xFF015C92).withOpacity(0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.all(4.w),
                  child: Row(
                    children: [
                      // Status Icon
                      Container(
                        padding: EdgeInsets.all(3.w),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isTaken
                                ? [Colors.green[400]!, Colors.green[600]!]
                                : pill.missed
                                    ? [Colors.red[400]!, Colors.red[600]!]
                                    : [Color(0xFF015C92), Color(0xFF0077CC)],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (isTaken
                                      ? Colors.green[400]
                                      : pill.missed
                                          ? Colors.red[400]
                                          : Color(0xFF015C92))!
                                  .withOpacity(0.3),
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          _getPillStatusIcon(pill, isTaken),
                          color: Colors.white,
                          size: 7.w,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      // Pill Information
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Pill Name
                            Text(
                              pill.name,
                              style: TextStyle(
                                color: isTaken
                                    ? Colors.green[800]
                                    : pill.missed
                                        ? Colors.red[800]
                                        : Color(0xFF015C92),
                                fontWeight: FontWeight.w700,
                                fontSize: 17.sp,
                                letterSpacing: 0.2,
                              ),
                            ),
                            SizedBox(height: 0.5.h),
                            // Dosage
                            Text(
                              pill.dosage,
                              style: TextStyle(
                                color: isTaken
                                    ? Colors.green[600]
                                    : pill.missed
                                        ? Colors.red[600]
                                        : Colors.grey[700],
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 0.5.h),
                            // Time and Status
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 5.w,
                                  color: isTaken
                                      ? Colors.green[600]
                                      : pill.missed
                                          ? Colors.red[600]
                                          : Color(0xFF015C92),
                                ),
                                SizedBox(width: 2.w),
                                Flexible(
                                  child: Text(
                                    formattedTime,
                                    style: TextStyle(
                                      color: isTaken
                                          ? Colors.green[600]
                                          : pill.missed
                                              ? Colors.red[600]
                                              : Color(0xFF015C92),
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (pill.allowSnooze) ...[
                                  SizedBox(width: 3.w),
                                  Icon(
                                    Icons.snooze,
                                    color: isTaken
                                        ? Colors.green[600]
                                        : pill.missed
                                            ? Colors.red[600]
                                            : Color(0xFF015C92),
                                    size: 5.w,
                                  ),
                                ],
                              ],
                            ),
                            // Taken time or missed status
                            if (isTaken && takenDate != null) ...[
                              SizedBox(height: 0.5.h),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 3.w, vertical: 1.h),
                                decoration: BoxDecoration(
                                  color: Colors.green[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: Colors.green[600],
                                      size: 4.w,
                                    ),
                                    SizedBox(width: 2.w),
                                    Flexible(
                                      child: Text(
                                        'Taken at ${DateFormat('h:mm a').format(takenDate.toLocal())}',
                                        style: TextStyle(
                                          fontSize: 12.sp,
                                          color: Colors.green[700],
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (pill.missed && !isTaken) ...[
                              SizedBox(height: 0.5.h),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 3.w, vertical: 1.h),
                                decoration: BoxDecoration(
                                  color: Colors.red[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.warning,
                                      color: Colors.red[600],
                                      size: 4.w,
                                    ),
                                    SizedBox(width: 2.w),
                                    Flexible(
                                      child: Text(
                                        'Missed!',
                                        style: TextStyle(
                                          fontSize: 12.sp,
                                          color: Colors.red[700],
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Edit Button
                      if (!_isReadOnly)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.edit,
                              color: Color(0xFF015C92),
                              size: 6.w,
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
                          ),
                        ),
                    ],
                  ),
                ),
                // Checkbox to mark as taken - only for elders
                if (!_isReadOnly)
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Transform.scale(
                          scale: 1.3,
                          child: Checkbox(
                            value: isTaken,
                            activeColor: Colors.green[600],
                            checkColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            onChanged: (bool? value) {
                              if (value != null) {
                                _markPillAsTaken(pill, value);
                              }
                            },
                          ),
                        ),
                        SizedBox(width: 3.w),
                        Flexible(
                          child: Text(
                            isTaken ? 'Marked as taken' : 'Mark as taken',
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w600,
                              color: isTaken
                                  ? Colors.green[700]
                                  : Color(0xFF015C92),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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

      // Check time window validation only when marking as taken
      if (isTaken) {
        final now = DateTime.now();
        final pillTime = DateTime(
          now.year,
          now.month,
          now.day,
          pill.times.first.hour,
          pill.times.first.minute,
        );

        // Calculate time difference in minutes
        final timeDifference = now.difference(pillTime).inMinutes;

        // Check if we're outside the allowed window (15 minutes before to 15 minutes after)
        if (timeDifference < -15 || timeDifference > 15) {
          // Format the allowed time window for display
          final earlyTime = pillTime.subtract(Duration(minutes: 15));
          final lateTime = pillTime.add(Duration(minutes: 15));

          final earlyTimeStr =
              '${earlyTime.hour.toString().padLeft(2, '0')}:${earlyTime.minute.toString().padLeft(2, '0')}';
          final lateTimeStr =
              '${lateTime.hour.toString().padLeft(2, '0')}:${lateTime.minute.toString().padLeft(2, '0')}';
          final pillTimeStr =
              '${pillTime.hour.toString().padLeft(2, '0')}:${pillTime.minute.toString().padLeft(2, '0')}';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Cannot mark ${pill.name} as taken outside the allowed time window.\n'
                'Scheduled time: $pillTimeStr\n'
                'Allowed window: $earlyTimeStr - $lateTimeStr',
                style: TextStyle(fontSize: 14.sp),
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
              action: SnackBarAction(
                label: 'OK',
                textColor: Colors.white,
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              ),
            ),
          );
          return; // Don't proceed with marking as taken
        }
      }

      // Update local state immediately for better performance
      setState(() {
        // Update all instances of this pill in the pills map
        _pills.forEach((date, pills) {
          for (int i = 0; i < pills.length; i++) {
            if (pills[i].id == pill.id) {
              // Check if this is the specific time we're marking as taken
              if (_getTimeKeyForPill(pills[i]) == timeKey) {
                // Update the taken status for this specific time
                pills[i] = pills[i].copyWith(
                  takenDates: isTaken
                      ? {
                          ...pills[i].takenDates,
                          timeKey: DateTime.now().toUtc()
                        }
                      : {...pills[i].takenDates}
                    ..remove(timeKey),
                  missed: isTaken ? false : pills[i].missed,
                );
              }
            }
          }
        });
      });

      // Show immediate feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isTaken
                ? '${pill.name} marked as taken for ${_formatTime(pill.times.first)}'
                : '${pill.name} marked as not taken for ${_formatTime(pill.times.first)}',
            style: TextStyle(fontSize: 14.sp),
          ),
          duration: Duration(seconds: 1),
        ),
      );

      // Find the original pill in the provider's list
      final originalPill =
          pillProvider.pills.firstWhere((p) => p.id == pill.id);

      // Create a copy with the updated taken status
      final updatedPill = originalPill.copyWith();

      if (isTaken) {
        updatedPill.markTimeTaken(timeKey, DateTime.now().toUtc());
        updatedPill.missed = false;

        // Send notification to guardian (time window already validated above)
        await _sendInstantPillNotification(updatedPill);
      } else {
        updatedPill.markTimeNotTaken(timeKey);
      }

      // Update the pill through the provider
      await pillProvider.updatePill(updatedPill);

      // Refresh data after a short delay to ensure consistency
      await Future.delayed(Duration(milliseconds: 300));
      _updatePillsFromProvider();
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

  // Send a direct FCM notification to the guardian about pill status
  Future<void> _sendDirectPillNotification(
      {required String guardianId,
      required String pillName,
      required String elderName,
      required bool isTaken}) async {
    try {
      // Get guardian's FCM token directly
      final guardianDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(guardianId)
          .get();

      if (!guardianDoc.exists) {
        print('Guardian document not found');
        return;
      }

      final guardianData = guardianDoc.data();
      if (guardianData == null) return;

      final fcmToken = guardianData['fcmToken'];
      if (fcmToken == null || fcmToken.isEmpty) {
        print('FCM token not found for guardian');
        return;
      }

      // Import FCMService
      final fcmService = FCMService();

      // For pill taken notifications, use the dedicated endpoint
      bool sent = false;
      if (isTaken) {
        print('🔔 Using dedicated pill taken notification endpoint');
        sent = await fcmService.sendPillTakenNotification(
          token: fcmToken,
          elderName: elderName,
          pillName: pillName,
          guardianId: guardianId,
        );
        if (sent) {
          print(
              '✅ Pill taken notification sent successfully via dedicated endpoint');

          // Store in notification history since it was sent successfully
          await FirebaseFirestore.instance
              .collection('users')
              .doc(guardianId)
              .collection('notifications')
              .add({
            'title': "Medicine Taken",
            'message': "$elderName marked $pillName as taken.",
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
            'type': 'pill_taken',
            'data': {
              'pillName': pillName,
              'elderName': elderName,
            },
          });

          return; // Exit early since notification was sent successfully
        } else {
          print('⚠️ Dedicated endpoint failed, trying direct FCM API');
        }
      }

      // Prepare notification data
      final title = isTaken ? "Medicine Taken" : "Pill Missed Alert";
      final body = isTaken
          ? "$elderName marked $pillName as taken."
          : "$elderName missed their medicine: $pillName.";

      // Try to send notification directly using FCM API if not sent yet
      sent = await fcmService.sendDirectNotification(
        token: fcmToken,
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

      if (sent) {
        print('Direct pill notification sent successfully via FCM API');

        // Store in notification history since it was sent successfully
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

        return; // Exit early since notification was sent successfully
      }

      // If we get here, both notification attempts failed
      print(
          'All direct notification methods failed, storing for backup delivery');

      // Store in pending_notifications for retry
      await FirebaseFirestore.instance.collection('pending_notifications').add({
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

      // Only store in pill_notifications as last resort if both direct methods failed
      if (isTaken) {
        await FirebaseFirestore.instance.collection('pill_notifications').add({
          'token': fcmToken,
          'title': title,
          'body': body,
          'pillName': pillName,
          'elderName': elderName,
          'guardianId': guardianId,
          'type': 'pill_taken',
          'createdAt': FieldValue.serverTimestamp(),
          'processed': false,
        });
        print(
            '📝 Pill notification stored in pill_notifications for Firestore trigger as final fallback');
      }
    } catch (e) {
      print('Error sending direct pill notification: $e');
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
  Color _getPillCardColor(PillModel pill, bool isTaken) {
    if (isTaken) {
      return Colors.green[50]!;
    } else if (pill.missed) {
      return Colors.red[50]!;
    } else {
      return Color(0xFF015C92);
    }
  }

  Color _getPillTextColor(PillModel pill, bool isTaken) {
    if (isTaken) {
      return Colors.green[700]!;
    } else if (pill.missed) {
      return Colors.red[700]!;
    } else {
      return Colors.white;
    }
  }

  Color _getPillSubtitleColor(PillModel pill, bool isTaken) {
    if (isTaken) {
      return Colors.green[700]!.withAlpha(204); // 0.8 opacity
    } else if (pill.missed) {
      return Colors.red[700]!.withAlpha(204); // 0.8 opacity
    } else {
      return Colors.white70;
    }
  }

  IconData _getPillStatusIcon(PillModel pill, bool isTaken) {
    if (isTaken) {
      return Icons.check_circle;
    } else if (pill.missed) {
      return Icons.warning_rounded;
    } else {
      return Icons.medication;
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

      // Use the direct method for sending notifications
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
}

class ModernAddPillForm extends StatefulWidget {
  final Function(PillModel) onSubmit;
  final PillModel? existingPill;
  final String? initialMedicineName;
  final String? initialDosage;

  const ModernAddPillForm({
    Key? key,
    required this.onSubmit,
    this.existingPill,
    this.initialMedicineName,
    this.initialDosage,
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

    // Initialize with OCR data if provided, otherwise use existing pill data or empty
    _nameController = TextEditingController(
      text: widget.initialMedicineName ?? existingPill?.name ?? '',
    );
    _dosageController = TextEditingController(
      text: widget.initialDosage ?? existingPill?.dosage ?? '',
    );
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
