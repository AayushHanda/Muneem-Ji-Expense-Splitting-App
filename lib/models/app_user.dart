class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final List<String> friendIds;

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.friendIds = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'friendIds': friendIds,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map, String docId) {
    return AppUser(
      uid: docId,
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? 'Unknown',
      photoUrl: map['photoUrl'],
      friendIds: List<String>.from(map['friendIds'] ?? []),
    );
  }
}
