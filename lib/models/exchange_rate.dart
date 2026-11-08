class ExchangeRate {
  const ExchangeRate({required this.rate, required this.date});

  factory ExchangeRate.fromJson(Object? json) {
    if (json is! Map<String, dynamic> ||
        json['base'] != 'USD' ||
        json['quote'] != 'VND') {
      throw const FormatException('Invalid currency pair');
    }
    final rate = json['rate'];
    final date = json['date'];
    if (rate is! num ||
        !rate.isFinite ||
        rate <= 0 ||
        date is! String ||
        !isRateDate(date)) {
      throw const FormatException('Invalid exchange rate');
    }
    return ExchangeRate(rate: rate.toDouble(), date: date);
  }

  final double rate;

  /// The API's calendar date, kept without a timezone conversion.
  final String date;
}

bool isRateDate(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
  final parsed = DateTime.tryParse(value);
  return parsed != null && parsed.toIso8601String().startsWith(value);
}
