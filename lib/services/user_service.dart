import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
import '../models/expense_group.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference get _usersRef => _db.collection('users');
  CollectionReference get _groupsRef => _db.collection('groups');

  // Create a new user in Firestore upon registration
  Future<void> createUser(AppUser user) async {
    try {
      await _usersRef.doc(user.uid).set(user.toMap());
    } catch (e) {
      throw Exception('Failed to create user profile: $e');
    }
  }

  // Fetch a specific user profile
  Future<AppUser?> getUser(String uid) async {
    try {
      DocumentSnapshot doc = await _usersRef.doc(uid).get();
      if (doc.exists) {
        return AppUser.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch user profile: $e');
    }
  }

  // Stream of users friends
  Stream<List<AppUser>> getFriendsStream(String uid) async* {
    yield* _usersRef.doc(uid).snapshots().asyncMap((snapshot) async {
       if (!snapshot.exists) return [];
       final userData = snapshot.data() as Map<String, dynamic>;
       final friendIds = List<String>.from(userData['friendIds'] ?? []);
       
       if (friendIds.isEmpty) return [];

       final friendsQuery = await _usersRef.where(FieldPath.documentId, whereIn: friendIds).get();
       return friendsQuery.docs.map((doc) => AppUser.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
    });
  }

  // Search a user by exact email match
  Future<AppUser?> searchUserByEmail(String email) async {
    try {
      final snapshot = await _usersRef.where('email', isEqualTo: email).limit(1).get();
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        return AppUser.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to search user: $e');
    }
  }

  // Add a friend directly
  Future<void> addFriend(String currentUserId, String friendId) async {
    try {
      // Add friend to current user
      await _usersRef.doc(currentUserId).update({
        'friendIds': FieldValue.arrayUnion([friendId])
      });
      
      // Mutual add: Add current user to friend
      await _usersRef.doc(friendId).update({
        'friendIds': FieldValue.arrayUnion([currentUserId])
      });
    } catch (e) {
      throw Exception('Failed to add friend: $e');
    }
  }

  // Update profile photo URL
  Future<void> updateUserPhoto(String uid, String photoUrl) async {
    try {
      await _usersRef.doc(uid).update({'photoUrl': photoUrl});
    } catch (e) {
      throw Exception('Failed to update photo: $e');
    }
  }

  // Store a pending email invite (for non-registered users)
  Future<void> storePendingInvite(String fromUserId, String toEmail) async {
    try {
      await _db.collection('pending_invites').add({
        'fromUserId': fromUserId,
        'toEmail'   : toEmail,
        'sentAt'    : DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to store invite: $e');
    }
  }

  // ==== GROUPS ====

  // Create a new expense group
  Future<void> createGroup(ExpenseGroup group) async {
    try {
      await _groupsRef.doc(group.id).set(group.toMap());
    } catch (e) {
      throw Exception('Failed to create group: $e');
    }
  }

  // Listen to all groups a user is a part of
  Stream<List<ExpenseGroup>> getUserGroupsStream(String uid) {
    return _groupsRef
        .where('memberIds', arrayContains: uid)
        .snapshots()
        .map((snapshot) {
          final groups = snapshot.docs
              .map((doc) => ExpenseGroup.fromMap(doc.data() as Map<String, dynamic>, doc.id))
              .toList();
          // Sort client-side by createdAt descending to avoid composite index requirement
          groups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return groups;
        });
  }
}
