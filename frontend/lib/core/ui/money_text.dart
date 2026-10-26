import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/text_styles.dart';

/// Formats paise / rupee decimals using Indian digit grouping (PART 4.7, D8).
class MoneyText extends StatelessWidget {
  final num? amountInRupees;
  final int? amountInPaise;
  final TextStyle? style;
  final bool showCurrency;

  const MoneyText({
    super.key,
    this.amountInRupees,
    this.amountInPaise,
    this.style,
    this.showCurrency = true,
  });

  @override
  Widget build(BuildContext context) {
    double value = 0.0;
    if (amountInRupees != null) {
      value = amountInRupees!.toDouble();
    } else if (amountInPaise != null) {
      value = amountInPaise! / 100.0;
    }

    final formatted = _formatIndianRupees(value);
    final textStyle = style ?? AppTypography.tabularNumbers;

    return Text(
      showCurrency ? '₹$formatted' : formatted,
      style: textStyle,
      textAlign: TextAlign.right,
    );
  }

  static String _formatIndianRupees(double value) {
    bool isNegative = value < 0;
    double absVal = value.abs();
    String fixed = absVal.toStringAsFixed(2);
    List<String> parts = fixed.split('.');
    String integerPart = parts[0];
    String decimalPart = parts[1];

    if (integerPart.length <= 3) {
      return '${isNegative ? '-' : ''}$integerPart.$decimalPart';
    }

    // Indian grouping: last 3 digits, then groups of 2 digits
    String lastThree = integerPart.substring(integerPart.length - 3);
    String remaining = integerPart.substring(0, integerPart.length - 3);

    StringBuffer result = StringBuffer();
    while (remaining.length > 2) {
      result = StringBuffer(
        ',${remaining.substring(remaining.length - 2)}$result',
      );
      remaining = remaining.substring(0, remaining.length - 2);
    }
    result = StringBuffer('$remaining$result,$lastThree');

    return '${isNegative ? '-' : ''}$result.$decimalPart';
  }
}
