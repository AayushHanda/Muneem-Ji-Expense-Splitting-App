import 'package:uuid/uuid.dart';

class Settlement {
  final String id;
  final String fromUserId; // The person paying back the debt
  final String toUserId;   // The person receiving the money
  final double amount;
  final DateTime date;
  final String? groupId;   // Nullable, if the settlement belongs to a specific group

  Settlement({
    String? id,
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
    DateTime? date,
    this.groupId,
  })  : id = id ?? const Uuid().v4(),
        date = date ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'amount': amount,
      'date': date.toIso8601String(),
      'groupId': groupId,
    };
  }

  factory Settlement.fromMap(Map<String, dynamic> map, String docId) {
    return Settlement(
      id: docId,
      fromUserId: map['fromUserId'] ?? '',
      toUserId: map['toUserId'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
      groupId: map['groupId'],
    );
  }
}
