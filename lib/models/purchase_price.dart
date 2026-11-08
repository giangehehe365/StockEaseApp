import 'exchange_rate.dart';

class PurchasePrice {
  const PurchasePrice({
    required this.original,
    required this.currency,
    required this.rate,
    required this.vnd,
    this.rateDate,
  });

  static const maxAmount = 999999999999;
  final num original;
  final String currency;
  final double rate;
  final int vnd;
  final String? rateDate;

  bool get isValid {
    if (!original.isFinite ||
        original < 0 ||
        original > maxAmount ||
        !rate.isFinite ||
        rate <= 0 ||
        vnd < 0 ||
        vnd > maxAmount) {
      return false;
    }
    final converted = original * rate;
    if (!converted.isFinite || converted.round() != vnd) return false;
    if (currency == 'VND') {
      return rate == 1 && original == vnd && rateDate == null;
    }
    return currency == 'USD' && rateDate != null && isRateDate(rateDate!);
  }

  static PurchasePrice? fromData(Map<String, dynamic> data) {
    final original = data['purchasePriceOriginal'];
    final currency = data['purchaseCurrency'];
    final rate = data['exchangeRate'];
    final vnd = data['purchasePriceVnd'];
    final date = data['exchangeRateDate'];
    if (original is! num ||
        currency is! String ||
        rate is! num ||
        vnd is! int ||
        (date != null && date is! String)) {
      return null;
    }
    final price = PurchasePrice(
      original: original,
      currency: currency,
      rate: rate.toDouble(),
      vnd: vnd,
      rateDate: date as String?,
    );
    return price.isValid ? price : null;
  }

  Map<String, dynamic> toData() => {
    'purchasePriceVnd': vnd,
    'purchasePriceOriginal': original,
    'purchaseCurrency': currency,
    'exchangeRate': rate,
    'exchangeRateDate': rateDate,
  };
}

num? parsePurchaseAmount(String text, String currency) {
  final value = text.trim().replaceAll(',', '.');
  final pattern = currency == 'USD' ? r'^\d+(\.\d{1,2})?$' : r'^\d+$';
  if (!RegExp(pattern).hasMatch(value)) return null;
  final amount = num.tryParse(value);
  return amount != null &&
          amount.isFinite &&
          amount >= 0 &&
          amount <= PurchasePrice.maxAmount
      ? amount
      : null;
}

String formatVnd(int value) {
  final digits = value.toString();
  final groups = <String>[];
  for (var end = digits.length; end > 0; end -= 3) {
    groups.add(digits.substring(end > 3 ? end - 3 : 0, end));
  }
  return '${groups.reversed.join('.')} ₫';
}
