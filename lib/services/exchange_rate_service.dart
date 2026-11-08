import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/exchange_rate.dart';

class ExchangeRateException implements Exception {
  const ExchangeRateException(this.message);
  final String message;
}

class ExchangeRateService {
  ExchangeRateService({
    http.Client? client,
    this.timeout = const Duration(seconds: 12),
  }) : _client = client ?? http.Client();

  static final endpoint = Uri.https('api.frankfurter.dev', '/v2/rate/USD/VND');
  final http.Client _client;
  final Duration timeout;

  Future<ExchangeRate> getUsdVnd() async {
    try {
      final response = await _client
          .get(endpoint, headers: {'Accept': 'application/json'})
          .timeout(timeout);
      if (response.statusCode != 200) {
        throw ExchangeRateException(
          'Không lấy được tỷ giá (HTTP ${response.statusCode}). Hãy thử lại hoặc chọn VND.',
        );
      }
      return ExchangeRate.fromJson(jsonDecode(response.body));
    } on ExchangeRateException {
      rethrow;
    } on TimeoutException {
      throw const ExchangeRateException(
        'API tỷ giá phản hồi quá lâu. Hãy thử lại hoặc chọn VND.',
      );
    } on FormatException {
      throw const ExchangeRateException(
        'API trả về tỷ giá không hợp lệ. Hãy thử lại hoặc chọn VND.',
      );
    } on Exception {
      throw const ExchangeRateException(
        'Không thể kết nối API tỷ giá. Kiểm tra Internet, thử lại hoặc chọn VND.',
      );
    }
  }

  void close() => _client.close();
}
