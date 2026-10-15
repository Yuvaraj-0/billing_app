import 'package:intl/intl.dart';

/// Robust currency formatting utility.
/// Provides safe formatting for both UI (with glyph fallback)
/// and PDF generation (where Helvetica standard PDF fonts lack Unicode \u20B9).
class CurrencyFormatter {
  static const String symbolRupee = '₹';
  static const String symbolRs = 'Rs.';

  /// Format an amount with given currency symbol and optional decimals
  static String format(
    double amount, {
    String symbol = symbolRupee,
    bool showDecimals = false,
  }) {
    final cleanSymbol = symbol.trim();
    final prefix = cleanSymbol.isNotEmpty ? '$cleanSymbol ' : '';
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: prefix,
      decimalDigits: showDecimals ? 2 : 0,
    );
    return formatter.format(amount).trim();
  }

  /// Format with 2 decimal places (standard invoice breakdown format)
  static String formatWithDecimals(
    double amount, {
    String symbol = symbolRupee,
  }) {
    return format(amount, symbol: symbol, showDecimals: true);
  }

  /// Compact format without spaces, e.g. "₹5000" or "Rs.5000"
  static String formatCompact(
    double amount, {
    String symbol = symbolRupee,
  }) {
    final cleanSymbol = symbol.trim();
    final space = cleanSymbol == symbolRs ? ' ' : '';
    return '$cleanSymbol$space${amount.toStringAsFixed(0)}';
  }

  /// Safe PDF currency format.
  /// Standard PDF Type 1 fonts (Helvetica) lack Unicode \u20B9 (₹) and display
  /// tofu/question mark boxes on mobile PDF viewers.
  /// Always uses "Rs. " in PDF to guarantee 100% cross-device compatibility.
  static String formatPdf(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: 'Rs. ',
      decimalDigits: 2,
    );
    return formatter.format(amount).trim();
  }
}

