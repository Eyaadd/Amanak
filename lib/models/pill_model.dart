import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:amanak/notifications/noti_service.dart';

class PillModel {
  String id;
  String name;
  String dosage;
  int timesPerDay;
  int duration;
  DateTime dateTime;
  List<Map<String, int>> _times = <Map<String, int>>[{'hour': 8, 'minute': 0}];
  List<Map<String, int>> get times => _times ?? <Map<String, int>>[{'hour': 8, 'minute': 0}];
  set times(List<Map<String, int>>? value) {
    _times = value ?? <Map<String, int>>[{'hour': 8, 'minute': 0}];
  }
  bool allowSnooze;
  String note;
  bool taken;
  bool missed;
  DateTime? takenDate;
  Map<String, DateTime> _takenTimes = {};
  Map<String, DateTime> get takenTimes => _takenTimes;
  set takenTimes(Map<String, DateTime> value) {
    _takenTimes = value;
  }

  PillModel({
    this.id = "",
    required this.name,
    required this.dosage,
    required this.timesPerDay,
    required this.duration,
    required this.dateTime,
    List<Map<String, int>>? times,
    this.allowSnooze = true,
    this.note = "",
    this.taken = false,
    this.missed = false,
    this.takenDate,
    Map<String, DateTime>? takenTimes,
  }) {
    this.times = times;
    this._takenTimes = takenTimes ?? {};
  }

  PillModel.fromJson(Map<String, dynamic> json, String id)
      : this(
          id: id,
          name: json['name'] ?? "",
          dosage: json['dosage'] ?? "",
          timesPerDay: json['timesPerDay'] ?? 1,
          duration: json['duration'] ?? 1,
          dateTime: (json['dateTime'] as Timestamp).toDate(),
          times: (json['times'] is List && (json['times'] as List).isNotEmpty)
              ? (json['times'] as List).map((e) => {
                  'hour': (e['hour'] ?? 8) as int,
                  'minute': (e['minute'] ?? 0) as int,
                }).toList().cast<Map<String, int>>()
              : <Map<String, int>>[{'hour': (json['alarmHour'] ?? 8) as int, 'minute': (json['alarmMinute'] ?? 0) as int}],
          allowSnooze: json['allowSnooze'] ?? true,
          note: json['note'] ?? "",
          taken: json['taken'] ?? false,
          missed: json['missed'] ?? false,
          takenDate: json['takenDate'] != null
              ? (json['takenDate'] as Timestamp).toDate()
              : null,
          takenTimes: (json['takenTimes'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, (value as Timestamp).toDate()),
          ) ?? {},
        );

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'dosage': dosage,
      'timesPerDay': timesPerDay,
      'duration': duration,
      'dateTime': Timestamp.fromDate(dateTime),
      'times': times,
      'allowSnooze': allowSnooze,
      'note': note,
      'taken': taken,
      'missed': missed,
      'takenDate': takenDate != null ? Timestamp.fromDate(takenDate!) : null,
      'takenTimes': takenTimes.map((key, value) => MapEntry(key, Timestamp.fromDate(value))),
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
    List<Map<String, int>>? times,
    bool? allowSnooze,
    String? note,
    bool? taken,
    bool? missed,
    DateTime? takenDate,
    Map<String, DateTime>? takenTimes,
  }) {
    return PillModel(
      id: id ?? this.id,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      timesPerDay: timesPerDay ?? this.timesPerDay,
      duration: duration ?? this.duration,
      dateTime: dateTime ?? this.dateTime,
      times: times ?? this.times,
      allowSnooze: allowSnooze ?? this.allowSnooze,
      note: note ?? this.note,
      taken: taken ?? this.taken,
      missed: missed ?? this.missed,
      takenDate: takenDate ?? this.takenDate,
      takenTimes: takenTimes ?? Map.from(this.takenTimes),
    );
  }

  // Helper method to check if a specific time is taken
  bool isTimeTaken(String timeKey) {
    return takenTimes.containsKey(timeKey);
  }

  // Helper method to mark a specific time as taken
  void markTimeTaken(String timeKey, DateTime takenAt) {
    takenTimes[timeKey] = takenAt;
    // Update overall pill status
    taken = takenTimes.length == times.length;
    if (taken) {
      takenDate = takenTimes.values.reduce((a, b) => a.isAfter(b) ? a : b);
    }
  }

  // Helper method to mark a specific time as not taken
  void markTimeNotTaken(String timeKey) {
    takenTimes.remove(timeKey);
    // Update overall pill status
    taken = false;
    if (takenTimes.isEmpty) {
      takenDate = null;
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

  // Format all times in 12-hour format with AM/PM
  List<String> getFormattedTimes() {
    if (times == null) return [];
    return times.map((t) {
      final hour = t['hour'] ?? 0;
      final minute = (t['minute'] ?? 0).toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$hour12:$minute $period';
    }).toList();
  }

  // Get a unique key for a specific time
  String getTimeKey(Map<String, int> time) {
    return '${time['hour']}-${time['minute']}';
  }
}
