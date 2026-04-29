import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/daily_expenditure.dart';

class DailyExpenditureService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference get _expenditureRef => _db.collection('daily_expenditures');

  Future<void> addExpenditure(DailyExpenditure expenditure) async {
    try {
      await _expenditureRef.doc(expenditure.id).set(expenditure.toMap());
    } catch (e) {
      throw Exception('Failed to add expenditure: $e');
    }
  }

  Future<void> deleteExpenditure(String id) async {
    try {
      await _expenditureRef.doc(id).delete();
    } catch (e) {
      throw Exception('Failed to delete expenditure: $e');
    }
  }

  Future<void> updateExpenditure(DailyExpenditure expenditure) async {
    try {
      await _expenditureRef.doc(expenditure.id).update(expenditure.toMap());
    } catch (e) {
      throw Exception('Failed to update expenditure: $e');
    }
  }

  // --- Sharing Logic ---

  Future<void> shareLog(String ownerId, String targetUserId) async {
    try {
      await _db.collection('log_shares').doc(ownerId).set({
        'sharedWith': FieldValue.arrayUnion([targetUserId])
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to share log: $e');
    }
  }

  Stream<List<String>> getSharedWithMeList(String userId) {
    return _db.collection('log_shares')
        .where('sharedWith', arrayContains: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
  }

  Stream<List<DailyExpenditure>> getExpendituresStream(String userId) {
    // We combine the user's own logs and logs of people who shared with them.
    return _db.collection('log_shares').doc(userId).snapshots().asyncExpand((shareSnap) {
      return _db.collection('log_shares')
          .where('sharedWith', arrayContains: userId)
          .snapshots()
          .asyncExpand((withMeSnap) {
            final sharedByUsers = withMeSnap.docs.map((doc) => doc.id).toList();
            final allAllowedUsers = [userId, ...sharedByUsers];

            return _expenditureRef
                .where('createdBy', whereIn: allAllowedUsers)
                .snapshots()
                .map((snapshot) {
                  return snapshot.docs.map((doc) {
                    return DailyExpenditure.fromMap(doc.data() as Map<String, dynamic>);
                  }).toList();
                });
          });
    });
  }
}
