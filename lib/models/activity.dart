import 'package:cloud_firestore/cloud_firestore.dart';

enum ActivityType {
  expenseAdded,
  expenseUpdated,
  expenseDeleted,
  settlementAdded,
  commentAdded
}

class Activity {
  final String id;
  final ActivityType type;
  final String userId;
  final String userName;
  final String? expenseId;
  final String description;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  Activity({
    required this.id,
    required this.type,
    required this.userId,
    required this.userName,
    this.expenseId,
    required this.description,
    required this.timestamp,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type.index,
      'userId': userId,
      'userName': userName,
      'expenseId': expenseId,
      'description': description,
      'timestamp': Timestamp.fromDate(timestamp),
      'metadata': metadata,
    };
  }

  factory Activity.fromMap(Map<String, dynamic> map, String id) {
    return Activity(
      id: id,
      type: ActivityType.values[map['type'] ?? 0],
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      expenseId: map['expenseId'],
      description: map['description'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      metadata: map['metadata'],
    );
  }
}
