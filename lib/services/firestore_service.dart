import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/expense.dart';
import '../models/settlement.dart';
import '../models/activity.dart';
import '../models/comment.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Collection References
  CollectionReference get _expensesRef => _db.collection('expenses');
  CollectionReference get _usersRef => _db.collection('users');

  // Add a new expense directly to Cloud Firestore
  Future<void> addExpense(Expense expense) async {
    try {
      await _expensesRef.doc(expense.id).set(expense.toMap());
    } catch (e) {
      throw Exception('Failed to add expense: $e');
    }
  }

  // Delete an existing expense
  Future<void> deleteExpense(String expenseId) async {
    try {
      await _expensesRef.doc(expenseId).delete();
    } catch (e) {
      throw Exception('Failed to delete expense: $e');
    }
  }

  // Update an existing expense
  Future<void> updateExpense(Expense expense) async {
    try {
      await _expensesRef.doc(expense.id).update(expense.toMap());
    } catch (e) {
      throw Exception('Failed to update expense: $e');
    }
  }

  // Stream of all expenses involving a specific user (either paid by them, or owing them)
  Stream<List<Expense>> getExpensesStream(String userId) {
    // Note: Due to Firestore limits, complex "OR" queries are tricky. 
    // Usually, we fetch expenses for a user's group, or fetch where 'paidByUserId' == userId 
    // AND fetch where 'splits.userId' exists, then map them in client.
    // Simplifying: Let's fetch the entire "friends/group" expenses temporarily.
    return _expensesRef.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Expense.fromMap(data);
      }).where((expense) => 
          expense.paidByUserId == userId || expense.splits.containsKey(userId)
        ).toList();
      });
    }

  // --- SETTLEMENTS ---
  
  // Create a new settlement 
  Future<void> addSettlement(Settlement settlement) async {
    try {
      final docRef = _db.collection('settlements').doc();
      final newSettlement = Settlement(
        id: docRef.id,
        fromUserId: settlement.fromUserId,
        toUserId: settlement.toUserId,
        amount: settlement.amount,
        groupId: settlement.groupId,
      );
      await docRef.set(newSettlement.toMap());
    } catch (e) {
      throw Exception('Failed to add settlement: $e');
    }
  }

  // Listen for settlements involving the user
  Stream<List<Settlement>> getSettlementsStream(String userId) {
    return _db.collection('settlements').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Settlement.fromMap(data, doc.id);
      }).where((settlement) => 
        settlement.fromUserId == userId || settlement.toUserId == userId
      ).toList();
    });
  }

  // --- ACTIVITIES ---

  Future<void> addActivity(Activity activity) async {
    try {
      await _db.collection('activities').add(activity.toMap());
    } catch (e) {
      print('Failed to add activity: $e');
    }
  }

  Stream<List<Activity>> getActivitiesStream() {
    return _db.collection('activities')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Activity.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  // --- COMMENTS ---

  Future<void> addComment(String expenseId, Comment comment) async {
    await _db
        .collection('expenses')
        .doc(expenseId)
        .collection('comments')
        .add(comment.toMap());
  }

  Stream<List<Comment>> getCommentsStream(String expenseId) {
    return _db
        .collection('expenses')
        .doc(expenseId)
        .collection('comments')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Comment.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }
}
