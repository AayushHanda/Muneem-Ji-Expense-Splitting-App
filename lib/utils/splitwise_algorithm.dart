import 'dart:math';

class SplitwiseAlgorithm {
  /// Simplifies debts to minimize the number of transactions required
  /// Returns a list of simplified transactions: Map of {fromUserId: Map of {toUserId: amount}}
  static Map<String, Map<String, double>> simplifyDebts(Map<String, double> balances) {
    List<MapEntry<String, double>> debtors = [];
    List<MapEntry<String, double>> creditors = [];

    balances.forEach((userId, balance) {
      if (balance < -0.01) {
        debtors.add(MapEntry(userId, -balance));
      } else if (balance > 0.01) {
        creditors.add(MapEntry(userId, balance));
      }
    });

    // Sort by largest debts and credits first (optimizes number of transactions)
    debtors.sort((a, b) => b.value.compareTo(a.value));
    creditors.sort((a, b) => b.value.compareTo(a.value));

    int i = 0; // index for debtors
    int j = 0; // index for creditors
    
    Map<String, Map<String, double>> transactions = {};

    while (i < debtors.length && j < creditors.length) {
      double minAmount = min(debtors[i].value, creditors[j].value);
      
      String fromUserId = debtors[i].key;
      String toUserId = creditors[j].key;

      if (!transactions.containsKey(fromUserId)) {
        transactions[fromUserId] = {};
      }
      transactions[fromUserId]![toUserId] = minAmount;

      debtors[i] = MapEntry(debtors[i].key, debtors[i].value - minAmount);
      creditors[j] = MapEntry(creditors[j].key, creditors[j].value - minAmount);

      if (debtors[i].value < 0.01) i++;
      if (creditors[j].value < 0.01) j++;
    }

    return transactions;
  }
}
