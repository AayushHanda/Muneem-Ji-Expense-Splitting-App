import 'package:uuid/uuid.dart';

class DailyExpenditure {
  final String id;
  final String description;
  final double amount;
  final DateTime date;
  final String category;
  final String createdBy;
  final List<String> sharedWith;
  final String? notes;

  DailyExpenditure({
    String? id,
    required this.description,
    required this.amount,
    DateTime? date,
    required this.category,
    required this.createdBy,
    List<String>? sharedWith,
    this.notes,
  })  : id = id ?? const Uuid().v4(),
        date = date ?? DateTime.now(),
        sharedWith = sharedWith ?? [];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'description': description,
      'amount': amount,
      'date': date.toIso8601String(),
      'category': category,
      'createdBy': createdBy,
      'sharedWith': sharedWith,
      'notes': notes,
    };
  }

  factory DailyExpenditure.fromMap(Map<String, dynamic> map) {
    return DailyExpenditure(
      id: map['id'],
      description: map['description'],
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date']),
      category: map['category'] ?? 'General',
      createdBy: map['createdBy'],
      sharedWith: List<String>.from(map['sharedWith'] ?? []),
      notes: map['notes'],
    );
  }
}
