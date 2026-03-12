import 'package:intl/intl.dart';

/// Indian number formatting utilities
class IndianFormatter {
  /// Format as Indian number system: ₹1,77,500.00
  static String currency(double amount, {bool showSymbol = true}) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: showSymbol ? '₹ ' : '',
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  /// Compact form: ₹1.77L, ₹2.5K
  static String compact(double amount) {
    if (amount >= 100000) return '₹${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000)   return '₹${(amount / 1000).toStringAsFixed(1)}K';
    return '₹ ${amount.toStringAsFixed(2)}';
  }

  /// Format date as "12 Mar 2026"
  static String date(DateTime dt) => DateFormat('d MMM yyyy').format(dt);

  /// Format time as "9:45 AM"
  static String time(DateTime dt) => DateFormat('h:mm a').format(dt);
}
