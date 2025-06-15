import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:amanak/notifications/noti_service.dart';

class PillModel {
  String id;
  String name;
  String dosage;
  int timesPerDay;
  int duration;
  DateTime dateTime;
  int alarmHour;
  int alarmMinute;
  bool allowSnooze;
  String note;
  bool taken;
  bool missed;
  DateTime? takenDate;

  PillModel({
    this.id = "",
    required this.name,
    required this.dosage,
    required this.timesPerDay,
    required this.duration,
    required this.dateTime,
    required this.alarmHour,
    required this.alarmMinute,
    this.allowSnooze = true,
    this.note = "",
    this.taken = false,
    this.missed = false,
    this.takenDate,
  });

  PillModel.fromJson(Map<String, dynamic> json, String id)
      : this(
          id: id,
          name: json['name'] ?? "",
          dosage: json['dosage'] ?? "",
          timesPerDay: json['timesPerDay'] ?? 1,
          duration: json['duration'] ?? 1,
          dateTime: (json['dateTime'] as Timestamp).toDate(),
          alarmHour: json['alarmHour'] ?? 8,
          alarmMinute: json['alarmMinute'] ?? 0,
          allowSnooze: json['allowSnooze'] ?? true,
          note: json['note'] ?? "",
          taken: json['taken'] ?? false,
          missed: json['missed'] ?? false,
          takenDate: json['takenDate'] != null
              ? (json['takenDate'] as Timestamp).toDate()
              : null,
        );

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'dosage': dosage,
      'timesPerDay': timesPerDay,
      'duration': duration,
      'dateTime': Timestamp.fromDate(dateTime),
      'alarmHour': alarmHour,
      'alarmMinute': alarmMinute,
      'allowSnooze': allowSnooze,
      'note': note,
      'taken': taken,
      'missed': missed,
      'takenDate': takenDate != null ? Timestamp.fromDate(takenDate!) : null,
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
    int? alarmHour,
    int? alarmMinute,
    bool? allowSnooze,
    String? note,
    bool? taken,
    bool? missed,
    DateTime? takenDate,
  }) {
    return PillModel(
      id: id ?? this.id,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      timesPerDay: timesPerDay ?? this.timesPerDay,
      duration: duration ?? this.duration,
      dateTime: dateTime ?? this.dateTime,
      alarmHour: alarmHour ?? this.alarmHour,
      alarmMinute: alarmMinute ?? this.alarmMinute,
      allowSnooze: allowSnooze ?? this.allowSnooze,
      note: note ?? this.note,
      taken: taken ?? this.taken,
      missed: missed ?? this.missed,
      takenDate: takenDate ?? this.takenDate,
    );
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
    final hour = alarmHour;
    final minute = alarmMinute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$hour12:$minute $period';
  }
}
