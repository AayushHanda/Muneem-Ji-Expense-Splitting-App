import 'package:uuid/uuid.dart';

class Expense {
  final String id;
  final String description;
  final double totalAmount;
  final DateTime date;
  final String paidByUserId;
  final Map<String, double> splits; // UserId -> Amount they owe
  final String category;
  final String? groupId;
  final String? notes;        // ← NEW: optional remarks

  Expense({
    String? id,
    required this.description,
    required this.totalAmount,
    DateTime? date,
    required this.paidByUserId,
    required this.splits,
    this.category = 'General',
    this.groupId,
    this.notes,
  })  : id = id ?? const Uuid().v4(),
        date = date ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id'           : id,
      'description'  : description,
      'totalAmount'  : totalAmount,
      'date'         : date.toIso8601String(),
      'paidByUserId' : paidByUserId,
      'splits'       : splits,
      'category'     : category,
      'groupId'      : groupId,
      'notes'        : notes,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id           : map['id'],
      description  : map['description'],
      totalAmount  : (map['totalAmount'] as num).toDouble(),
      date         : DateTime.parse(map['date']),
      paidByUserId : map['paidByUserId'],
      splits       : Map<String, double>.from(
          (map['splits'] as Map).map((k, v) => MapEntry(k as String, (v as num).toDouble()))),
      category     : map['category'] ?? 'General',
      groupId      : map['groupId'],
      notes        : map['notes'],
    );
  }
}
