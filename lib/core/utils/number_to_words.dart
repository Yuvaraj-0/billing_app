class NumberToWords {
  static const List<String> _ones = [
    '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
    'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
    'Seventeen', 'Eighteen', 'Nineteen'
  ];

  static const List<String> _tens = [
    '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'
  ];

  static String convert(double amount) {
    int rupees = amount.toInt();
    int paise = ((amount - rupees) * 100).round();

    String result = '';
    if (rupees > 0) {
      result = _convertIntegers(rupees) + ' Rupees';
    }
    if (paise > 0) {
      result += (result.isNotEmpty ? ' and ' : '') + _convertIntegers(paise) + ' Paise';
    }
    if (result.isEmpty) result = 'Zero Rupees';
    return result + ' Only';
  }

  static String _convertIntegers(int n) {
    if (n == 0) return '';
    if (n < 20) return _ones[n];
    if (n < 100) {
      return _tens[n ~/ 10] + (n % 10 != 0 ? ' ' + _ones[n % 10] : '');
    }
    if (n < 1000) {
      return _ones[n ~/ 100] + ' Hundred' + (n % 100 != 0 ? ' ' + _convertIntegers(n % 100) : '');
    }
    if (n < 100000) {
      return _convertIntegers(n ~/ 1000) + ' Thousand' + (n % 1000 != 0 ? ' ' + _convertIntegers(n % 1000) : '');
    }
    if (n < 10000000) {
      return _convertIntegers(n ~/ 100000) + ' Lakh' + (n % 100000 != 0 ? ' ' + _convertIntegers(n % 100000) : '');
    }
    return _convertIntegers(n ~/ 10000000) + ' Crore' + (n % 10000000 != 0 ? ' ' + _convertIntegers(n % 10000000) : '');
  }
}
