import 'package:cloud_firestore/cloud_firestore.dart';

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
      takenDate: takenDate ?? this.takenDate,
    );
  }
}
