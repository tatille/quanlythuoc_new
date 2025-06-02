class MedicineHistory {
  final String id;
  final String medicineId;
  final DateTime takenAt;
  final String status;
  final String? notes;
  final DateTime createdAt;

  MedicineHistory({
    required this.id,
    required this.medicineId,
    required this.takenAt,
    required this.status,
    this.notes,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'medicine_id': medicineId,
      'taken_at': takenAt.toIso8601String(),
      'status': status,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory MedicineHistory.fromMap(Map<String, dynamic> map) {
    return MedicineHistory(
      id: map['id'],
      medicineId: map['medicine_id'],
      takenAt: DateTime.parse(map['taken_at']),
      status: map['status'],
      notes: map['notes'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}
