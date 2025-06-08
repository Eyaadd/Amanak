import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:amanak/models/pill_model.dart';
import 'package:amanak/firebase/firebase_manager.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadPills();
  }

  void _loadPills() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        final pillsList = await FirebaseManager.getPills(userId: userId);

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
      }
    } catch (e) {
      print('Error loading pills: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showAddPillDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.85,
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: ModernAddPillForm(
            onSubmit: (pillModel) async {
              try {
                // Add to Firebase
                final pillId = await FirebaseManager.addPill(pillModel);

                // Update local state with the returned ID
                pillModel.id = pillId;

                // Update UI - mark all days in the duration
                setState(() {
                  final startDate = DateTime(pillModel.dateTime.year,
                      pillModel.dateTime.month, pillModel.dateTime.day);

                  // Add pill to its start date
                  if (_pills[startDate] != null) {
                    _pills[startDate]!.add(pillModel);
                  } else {
                    _pills[startDate] = [pillModel];
                  }

                  // Mark all days in the duration
                  for (int i = 1; i < pillModel.duration; i++) {
                    final nextDate = startDate.add(Duration(days: i));
                    final nextDateKey =
                        DateTime(nextDate.year, nextDate.month, nextDate.day);

                    if (_pills[nextDateKey] != null) {
                      _pills[nextDateKey]!.add(pillModel);
                    } else {
                      _pills[nextDateKey] = [pillModel];
                    }
                  }
                });

                Navigator.of(context).pop();
              } catch (e) {
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
        title: Text("Medication Reminder"),
        backgroundColor: Color(0xFF015C92),
        foregroundColor: Colors.white,
        leading: null,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadPills,
          )
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Calendar Card - Made larger and centered
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  DateFormat('MMMM yyyy').format(_focusedDay),
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF015C92),
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.chevron_left,
                                          color: Color(0xFF015C92)),
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
                                          color: Color(0xFF015C92)),
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
                            SizedBox(height: 8),
                            TableCalendar(
                              firstDay: DateTime.utc(2010, 10, 16),
                              lastDay: DateTime.utc(2030, 3, 14),
                              focusedDay: _focusedDay,
                              calendarFormat: _calendarFormat,
                              headerVisible: false,
                              daysOfWeekHeight: 32,
                              rowHeight: 42,
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
                                  color: Color(0xFF015C92).withOpacity(0.5),
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
                  SizedBox(height: 8),

                  // Pill Reminder Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pill Reminder',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            hasPillsForTomorrow
                                ? 'Don\'t forget schedule for tomorrow'
                                : 'No reminders for tomorrow',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      // Add pill button at the top
                      Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          color: Color(0xFF015C92),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(Icons.add, color: Colors.white),
                          onPressed: _showAddPillDialog,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 8),

                  // Pills List for selected day
                  Expanded(
                    child: _selectedDay != null
                        ? _buildPillsList()
                        : Center(child: Text('Select a day to see pills')),
                  ),

                  // Bottom Buttons - Restored from original design
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0, bottom: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              onPressed: _showAddPillDialog,
                              child: Text('Add Pills',
                                  style: TextStyle(fontSize: 16)),
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
                        SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: () {
                                // Handle prescription
                              },
                              child: Text('Scan Prescription',
                                  style: TextStyle(fontSize: 16)),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.medication_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'No medications for this day',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: _showAddPillDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF015C92),
                foregroundColor: Colors.white,
              ),
              child: Text('Add Medication'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: pillsForSelectedDay.length,
      itemBuilder: (context, index) {
        final pill = pillsForSelectedDay[index];
        return Dismissible(
          key: Key("${pill.id}_$selectedDate"),
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: EdgeInsets.only(right: 20),
            child: Icon(Icons.delete, color: Colors.white),
          ),
          direction: DismissDirection.endToStart,
          confirmDismiss: (direction) async {
            return await showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text("Confirm"),
                  content: Text("Are you sure you want to delete this pill?"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text("CANCEL"),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child:
                          Text("DELETE", style: TextStyle(color: Colors.red)),
                    ),
                  ],
                );
              },
            );
          },
          onDismissed: (direction) async {
            try {
              // Only remove from Firebase if this is the start date
              final startDate = DateTime(
                  pill.dateTime.year, pill.dateTime.month, pill.dateTime.day);

              if (startDate.isAtSameMomentAs(selectedDate)) {
                await FirebaseManager.deletePill(pill.id);
              }

              // Update local state and reload to reflect changes across all days
              _loadPills();

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
            margin: EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: pill.taken ? Colors.green[50] : Color(0xFF015C92),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ListTile(
                    leading: Container(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        pill.taken ? Icons.check_circle : Icons.medication,
                        color: pill.taken ? Colors.green[700] : Colors.white,
                      ),
                    ),
                    title: Text(
                      pill.name,
                      style: TextStyle(
                        color: pill.taken ? Colors.green[700] : Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${pill.dosage} - ${pill.timesPerDay} Times per day',
                          style: TextStyle(
                              color: pill.taken
                                  ? Colors.green[700]?.withOpacity(0.8)
                                  : Colors.white),
                        ),
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: pill.taken
                                    ? Colors.green[100]
                                    : Colors.white30,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.access_time,
                                color: pill.taken
                                    ? Colors.green[700]
                                    : Colors.white,
                                size: 16,
                              ),
                            ),
                            SizedBox(width: 4),
                            Text(
                              '${pill.alarmHour}:${pill.alarmMinute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                  color: pill.taken
                                      ? Colors.green[700]?.withOpacity(0.8)
                                      : Colors.white70),
                            ),
                            if (pill.allowSnooze)
                              Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: Icon(
                                  Icons.snooze,
                                  color: pill.taken
                                      ? Colors.green[700]
                                      : Colors.white,
                                  size: 16,
                                ),
                              ),
                          ],
                        ),
                        if (pill.taken && pill.takenDate != null)
                          Text(
                            'Taken at: ${DateFormat('hh:mm a').format(pill.takenDate!)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green[700],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.edit,
                          color: pill.taken ? Colors.green[700] : Colors.white),
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
                ),
                // Add checkbox to mark as taken
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Checkbox(
                    value: pill.taken,
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
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _markPillAsTaken(PillModel pill, bool taken) async {
    try {
      // Update the pill model
      final updatedPill = pill.copyWith(
        taken: taken,
        takenDate: taken ? DateTime.now() : null,
      );

      // Update in Firebase
      await FirebaseManager.updatePill(updatedPill);

      // Refresh the list
      _loadPills();

      // Show confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(taken
              ? '${pill.name} marked as taken'
              : '${pill.name} marked as not taken'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error updating pill status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating pill status'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showEditPillDialog(PillModel pill) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.85,
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: ModernAddPillForm(
            existingPill: pill,
            onSubmit: (updatedPill) async {
              try {
                // Preserve the ID
                updatedPill.id = pill.id;

                // Update in Firebase
                await FirebaseManager.updatePill(updatedPill);

                // Reload all pills to update across all days
                _loadPills();

                Navigator.of(context).pop();
              } catch (e) {
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
  late TimeOfDay _selectedTime;
  late bool _allowSnooze;

  @override
  void initState() {
    super.initState();
    final existingPill = widget.existingPill;

    _nameController = TextEditingController(text: existingPill?.name ?? '');
    _dosageController = TextEditingController(text: existingPill?.dosage ?? '');
    _noteController = TextEditingController(text: existingPill?.note ?? '');
    _timesPerDay = existingPill?.timesPerDay ?? 1;
    _duration = existingPill?.duration ?? 7;
    _selectedDate = existingPill?.dateTime ?? DateTime.now();
    _selectedTime = existingPill != null
        ? TimeOfDay(
            hour: existingPill.alarmHour, minute: existingPill.alarmMinute)
        : TimeOfDay.now();
    _allowSnooze = existingPill?.allowSnooze ?? true;
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
    return Padding(
      padding: const EdgeInsets.all(16.0),
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
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF015C92),
                ),
              ),
              SizedBox(height: 16),

              // Pill Name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Medication Name',
                  prefixIcon: Icon(Icons.medication),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter medication name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),

              // Dosage
              TextFormField(
                controller: _dosageController,
                decoration: InputDecoration(
                  labelText: 'Dosage (e.g., 500mg)',
                  prefixIcon: Icon(Icons.biotech),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter dosage';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),

              // Times per day
              Row(
                children: [
                  Text('Times Per Day:', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 12),
                  DropdownButton<int>(
                    value: _timesPerDay,
                    items: [1, 2, 3, 4, 5].map((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text('$value time(s)'),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setState(() {
                        _timesPerDay = newValue!;
                      });
                    },
                  ),
                ],
              ),
              SizedBox(height: 16),

              // Duration
              Row(
                children: [
                  Text('Duration:', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 12),
                  DropdownButton<int>(
                    value: _duration,
                    items: [1, 3, 5, 7, 14, 21, 28, 30].map((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text('$value day(s)'),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setState(() {
                        _duration = newValue!;
                      });
                    },
                  ),
                ],
              ),
              SizedBox(height: 16),

              // Date picker
              ListTile(
                leading: Icon(Icons.calendar_today),
                title: Text('Start Date'),
                subtitle: Text(DateFormat('MMM d, yyyy').format(_selectedDate)),
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(Duration(days: 365)),
                  );
                  if (picked != null && picked != _selectedDate) {
                    setState(() {
                      _selectedDate = picked;
                    });
                  }
                },
              ),

              // Time picker
              ListTile(
                leading: Icon(Icons.access_time),
                title: Text('Reminder Time'),
                subtitle: Text(_selectedTime.format(context)),
                onTap: () async {
                  final TimeOfDay? picked = await showTimePicker(
                    context: context,
                    initialTime: _selectedTime,
                  );
                  if (picked != null && picked != _selectedTime) {
                    setState(() {
                      _selectedTime = picked;
                    });
                  }
                },
              ),

              // Allow snooze
              SwitchListTile(
                title: Text('Allow Snooze'),
                value: _allowSnooze,
                onChanged: (value) {
                  setState(() {
                    _allowSnooze = value;
                  });
                },
              ),

              // Notes
              TextFormField(
                controller: _noteController,
                decoration: InputDecoration(
                  labelText: 'Notes (optional)',
                  prefixIcon: Icon(Icons.note),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 2,
              ),
              SizedBox(height: 24),

              // Submit button
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text('Cancel'),
                  ),
                  SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF015C92),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding:
                          EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        // Create pill object
                        final pill = PillModel(
                          name: _nameController.text,
                          dosage: _dosageController.text,
                          timesPerDay: _timesPerDay,
                          duration: _duration,
                          dateTime: DateTime(
                            _selectedDate.year,
                            _selectedDate.month,
                            _selectedDate.day,
                            _selectedTime.hour,
                            _selectedTime.minute,
                          ),
                          alarmHour: _selectedTime.hour,
                          alarmMinute: _selectedTime.minute,
                          allowSnooze: _allowSnooze,
                          note: _noteController.text,
                        );

                        widget.onSubmit(pill);
                      }
                    },
                    child: Text(
                      widget.existingPill != null ? 'Update' : 'Add Medication',
                      style: TextStyle(fontSize: 16),
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
