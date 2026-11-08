import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stockease/models/exchange_rate.dart';
import 'package:stockease/models/purchase_price.dart';
import 'package:stockease/models/product.dart';
import 'package:stockease/services/exchange_rate_service.dart';

void main() {
  // Fixed values below are test fixtures only, never fallback production rates.
  test(
    'GET validates endpoint, headers, real response shape and numeric rate',
    () async {
      final service = ExchangeRateService(
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(
            request.url.toString(),
            'https://api.frankfurter.dev/v2/rate/USD/VND',
          );
          expect(request.headers['Accept'], 'application/json');
          return http.Response(
            jsonEncode({
              'date': '2025-01-02',
              'base': 'USD',
              'quote': 'VND',
              'rate': 100.25,
            }),
            200,
          );
        }),
      );
      addTearDown(service.close);
      final rate = await service.getUsdVnd();
      expect(rate.rate, 100.25);
      expect(rate.date, '2025-01-02');
    },
  );
  for (final status in [404, 422, 429, 500]) {
    test('HTTP $status becomes an actionable error', () async {
      final service = ExchangeRateService(
        client: MockClient((_) async => http.Response('{}', status)),
      );
      addTearDown(service.close);
      await expectLater(
        service.getUsdVnd(),
        throwsA(isA<ExchangeRateException>()),
      );
    });
  }
  test(
    'network errors and timeout are caught without fabricated rates',
    () async {
      final offline = ExchangeRateService(
        client: MockClient((_) async => throw http.ClientException('offline')),
      );
      addTearDown(offline.close);
      await expectLater(
        offline.getUsdVnd(),
        throwsA(isA<ExchangeRateException>()),
      );
      final pending = Completer<http.Response>();
      final timeout = ExchangeRateService(
        client: MockClient((_) => pending.future),
        timeout: const Duration(milliseconds: 10),
      );
      addTearDown(timeout.close);
      await expectLater(
        timeout.getUsdVnd(),
        throwsA(isA<ExchangeRateException>()),
      );
      pending.complete(http.Response('{}', 200));
    },
  );
  test('invalid JSON, currency, date or rate are rejected', () async {
    for (final body in [
      'invalid json',
      '[]',
      '{}',
      jsonEncode({
        'date': '2025-01-02',
        'base': 'EUR',
        'quote': 'VND',
        'rate': 1,
      }),
      jsonEncode({
        'date': '2025-01-02',
        'base': 'USD',
        'quote': 'EUR',
        'rate': 1,
      }),
      for (final rate in [null, 0, -1, '100'])
        jsonEncode({
          'date': '2025-01-02',
          'base': 'USD',
          'quote': 'VND',
          'rate': rate,
        }),
      jsonEncode({
        'date': '2025-02-30',
        'base': 'USD',
        'quote': 'VND',
        'rate': 1,
      }),
    ]) {
      final service = ExchangeRateService(
        client: MockClient((_) async => http.Response(body, 200)),
      );
      await expectLater(
        service.getUsdVnd(),
        throwsA(isA<ExchangeRateException>()),
      );
      service.close();
    }
    expect(
      () => ExchangeRate.fromJson({
        'date': '2025-01-01',
        'base': 'USD',
        'quote': 'VND',
        'rate': double.infinity,
      }),
      throwsFormatException,
    );
  });
  test(
    'amount parsing rejects negative, empty, exponents and excessive decimals',
    () {
      for (final value in ['', '-1', 'NaN', '1e3', 'abc', '1.234']) {
        expect(parsePurchaseAmount(value, 'USD'), isNull);
      }
      expect(parsePurchaseAmount('10,25', 'USD'), 10.25);
      expect(parsePurchaseAmount('10.25', 'VND'), isNull);
      expect(parsePurchaseAmount('0', 'VND'), 0);
      expect(parsePurchaseAmount('1000000000000', 'USD'), isNull);
    },
  );
  test(
    'purchase data round trips while old product preserves selling price',
    () {
      const purchase = PurchasePrice(
        original: 2,
        currency: 'USD',
        rate: 100.25,
        vnd: 201,
        rateDate: '2025-01-02',
      );
      expect(purchase.isValid, isTrue);
      expect(PurchasePrice.fromData(purchase.toData())!.vnd, 201);
      expect(formatVnd(123456), '123.456 ₫');
      final legacy = {
        'userId': 'u',
        'name': 'Old',
        'sku': 'OLD',
        'category': 'Khác',
        'price': 10000,
        'quantity': 4,
        'minStock': 1,
        'unit': 'box',
      };
      expect(Product.fromData('p', legacy).purchasePrice, isNull);
      final loaded = Product.fromData('p', {...legacy, ...purchase.toData()});
      expect(loaded.price, 10000);
      expect(loaded.quantity, 4);
      expect(loaded.purchasePrice!.original, 2);
      expect(loaded.purchasePrice!.rateDate, '2025-01-02');
      expect(
        const PurchasePrice(
          original: 1,
          currency: 'VND',
          rate: 2,
          vnd: 2,
        ).isValid,
        isFalse,
      );
      expect(
        const PurchasePrice(
          original: -1,
          currency: 'VND',
          rate: 1,
          vnd: -1,
        ).isValid,
        isFalse,
      );
    },
  );
}
