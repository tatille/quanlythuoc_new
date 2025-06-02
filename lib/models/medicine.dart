import 'dart:convert'; // Import for JSON encoding/decoding

class Medicine {
  final String id;
  String name;
  String dosage;
  // We will still keep timesPerDay for simplicity in some views, but the main schedule
  // will be driven by specificIntakeTimes
  int timesPerDay;
  DateTime startDate;
  DateTime endDate;
  String? notes;
  final DateTime createdAt;
  List<String> specificIntakeTimes; // Store times as HH:mm strings

  Medicine({
    required this.id,
    required this.name,
    required this.dosage,
    required this.timesPerDay,
    required this.startDate,
    required this.endDate,
    this.notes,
    required this.createdAt,
    required this.specificIntakeTimes,
  });

  // Convert a Medicine object into a Map object
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'dosage': dosage,
      'timesPerDay': timesPerDay,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'specificIntakeTimes': jsonEncode(
        specificIntakeTimes,
      ), // Encode list to JSON string
    };
  }

  // Extract a Medicine object from a Map object
  factory Medicine.fromMap(Map<String, dynamic> map) {
    return Medicine(
      id: map['id'],
      name: map['name'],
      dosage: map['dosage'],
      timesPerDay: map['timesPerDay'],
      startDate: DateTime.parse(map['startDate']),
      endDate: DateTime.parse(map['endDate']),
      notes: map['notes'],
      createdAt: DateTime.parse(map['createdAt']),
      specificIntakeTimes: List<String>.from(
        jsonDecode(map['specificIntakeTimes'] ?? '[]'),
      ), // Decode JSON string back to list
    );
  }
}
