import 'package:uuid/uuid.dart';

class ExpenseGroup {
  final String id;
  final String name;
  final String type; // 'Trip', 'Home', 'Couple', 'Other'
  final String? coverPhotoUrl;
  final List<String> memberIds;
  final DateTime createdAt;
  final String createdBy;

  ExpenseGroup({
    String? id,
    required this.name,
    this.type = 'Other',
    this.coverPhotoUrl,
    required this.memberIds,
    DateTime? createdAt,
    required this.createdBy,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'coverPhotoUrl': coverPhotoUrl,
      'memberIds': memberIds,
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
    };
  }

  factory ExpenseGroup.fromMap(Map<String, dynamic> map, String docId) {
    return ExpenseGroup(
      id: docId,
      name: map['name'] ?? 'Unnamed Group',
      type: map['type'] ?? 'Other',
      coverPhotoUrl: map['coverPhotoUrl'],
      memberIds: List<String>.from(map['memberIds'] ?? []),
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : DateTime.now(),
      createdBy: map['createdBy'] ?? '',
    );
  }
  
  // Helper for UI grouping icons
  String get iconEmoji {
    switch (type.toLowerCase()) {
      case 'trip': return '🏖️';
      case 'home': return '🏠';
      case 'couple': return '❤️';
      default: return '👥';
    }
  }
}
