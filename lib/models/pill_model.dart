import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:amanak/notifications/noti_service.dart';
import 'package:flutter/material.dart';

class PillModel {
  String id;
  String name;
  String dosage;
  int timesPerDay;
  int duration;
  DateTime dateTime;
  List<TimeOfDay> times; // List of times for multiple doses per day
  bool allowSnooze;
  String note;
  Map<String, DateTime> takenDates; // Map of date strings to taken timestamps
  bool missed;

  PillModel({
    this.id = "",
    required this.name,
    required this.dosage,
    required this.timesPerDay,
    required this.duration,
    required this.dateTime,
    List<TimeOfDay>? times,
    this.allowSnooze = true,
    this.note = "",
    Map<String, DateTime>? takenDates,
    this.missed = false,
  })  : this.takenDates = takenDates ?? {},
        this.times = times ?? [TimeOfDay(hour: 8, minute: 0)];

  // Backward compatibility constructor
  PillModel.withSingleTime({
    this.id = "",
    required this.name,
    required this.dosage,
    required this.timesPerDay,
    required this.duration,
    required this.dateTime,
    required int alarmHour,
    required int alarmMinute,
    this.allowSnooze = true,
    this.note = "",
    Map<String, DateTime>? takenDates,
    this.missed = false,
  })  : this.takenDates = takenDates ?? {},
        this.times = [TimeOfDay(hour: alarmHour, minute: alarmMinute)];

  PillModel.fromJson(Map<String, dynamic> json, String id)
      : this(
          id: id,
          name: json['name'] ?? "",
          dosage: json['dosage'] ?? "",
          timesPerDay: json['timesPerDay'] ?? 1,
          duration: json['duration'] ?? 1,
          dateTime: (json['dateTime'] as Timestamp).toDate(),
          times: _parseTimes(json['times'], json),
          allowSnooze: json['allowSnooze'] ?? true,
          note: json['note'] ?? "",
          takenDates: _parseTakenDates(json['takenDates'], json),
          missed: json['missed'] ?? false,
        );

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'dosage': dosage,
      'timesPerDay': timesPerDay,
      'duration': duration,
      'dateTime': Timestamp.fromDate(dateTime),
      'times': times
          .map((time) => {
                'hour': time.hour,
                'minute': time.minute,
              })
          .toList(),
      'allowSnooze': allowSnooze,
      'note': note,
      'takenDates': takenDates.map(
        (key, value) => MapEntry(key, Timestamp.fromDate(value)),
      ),
      'missed': missed,
    };
  }

  // Create a copy of the pill with updated properties
  PillModel copyWith({
    String? id,
    String? name,
    String? dosage,
    int? timesPerDay,
    int? duration,
    DateTime? dateTime,
    List<TimeOfDay>? times,
    bool? allowSnooze,
    String? note,
    Map<String, DateTime>? takenDates,
    bool? missed,
  }) {
    return PillModel(
      id: id ?? this.id,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      timesPerDay: timesPerDay ?? this.timesPerDay,
      duration: duration ?? this.duration,
      dateTime: dateTime ?? this.dateTime,
      times: times ?? List.from(this.times),
      allowSnooze: allowSnooze ?? this.allowSnooze,
      note: note ?? this.note,
      takenDates: takenDates ?? Map.from(this.takenDates),
      missed: missed ?? this.missed,
    );
  }

  // Helper method to check if pill was taken on a specific date
  bool isTakenOnDate(DateTime date) {
    final dateStr = '${date.year}-${date.month}-${date.day}';
    return takenDates.containsKey(dateStr);
  }

  // Helper method to get taken timestamp for a specific date
  DateTime? getTakenDateForDate(DateTime date) {
    final dateStr = '${date.year}-${date.month}-${date.day}';
    return takenDates[dateStr];
  }

  // Helper method to mark pill as taken on a specific date
  void markTakenOnDate(DateTime date, bool taken) {
    final dateStr = '${date.year}-${date.month}-${date.day}';
    if (taken) {
      takenDates[dateStr] = DateTime.now();
    } else {
      takenDates.remove(dateStr);
    }
  }

  // Schedule notifications for this pill
  Future<void> scheduleNotifications() async {
    final notiService = NotiService();
    await notiService.schedulePillNotifications(this);
  }

  // Cancel notifications for this pill
  Future<void> cancelNotifications() async {
    final notiService = NotiService();
    await notiService.cancelPillNotifications(id);
  }

  // Format time in 12-hour format with AM/PM
  String getFormattedTime() {
    if (times.isEmpty) return "No time set";

    final time = times.first;
    final hour = time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$hour12:$minute $period';
  }

  // Format all times for display
  String getFormattedTimes() {
    if (times.isEmpty) return "No times set";

    return times.map((time) {
      final hour = time.hour;
      final minute = time.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$hour12:$minute $period';
    }).join(', ');
  }

  // Get primary time (first time in the list) for backward compatibility
  int get alarmHour => times.isNotEmpty ? times.first.hour : 8;
  int get alarmMinute => times.isNotEmpty ? times.first.minute : 0;

  // Helper method to parse times safely with backward compatibility
  static List<TimeOfDay> _parseTimes(
      dynamic timesData, Map<String, dynamic> json) {
    if (timesData != null) {
      try {
        if (timesData is List) {
          return timesData.map((timeData) {
            if (timeData is Map) {
              return TimeOfDay(
                hour: timeData['hour'] ?? 8,
                minute: timeData['minute'] ?? 0,
              );
            }
            return TimeOfDay(hour: 8, minute: 0);
          }).toList();
        }
      } catch (e) {
        print('Error parsing times: $e');
      }
    }

    // Backward compatibility: check for old alarmHour and alarmMinute fields
    final oldAlarmHour = json['alarmHour'] ?? 8;
    final oldAlarmMinute = json['alarmMinute'] ?? 0;
    return [TimeOfDay(hour: oldAlarmHour, minute: oldAlarmMinute)];
  }

  // Helper method to parse takenDates safely with backward compatibility
  static Map<String, DateTime> _parseTakenDates(
      dynamic takenDatesData, Map<String, dynamic> json) {
    if (takenDatesData == null) {
      // Backward compatibility: check for old taken and takenDate fields
      final oldTaken = json['taken'] ?? false;
      final oldTakenDate = json['takenDate'];

      if (oldTaken && oldTakenDate != null) {
        // Convert old format to new format
        final dateTime = (oldTakenDate as Timestamp).toDate();
        final dateStr = '${dateTime.year}-${dateTime.month}-${dateTime.day}';
        return {dateStr: dateTime};
      }
      return {};
    }

    try {
      if (takenDatesData is Map) {
        final Map<String, DateTime> result = {};
        takenDatesData.forEach((key, value) {
          if (key is String && value is Timestamp) {
            result[key] = value.toDate();
          }
        });
        return result;
      }
    } catch (e) {
      print('Error parsing takenDates: $e');
    }
    return {};
  }
}
