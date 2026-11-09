import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Barcode stays case-sensitive text, independently of the internal SKU.
String normalizeBarcode(String value) => value.trim();

// ML Kit may report UPC-A as EAN-13 prefixed with zero. Keep stored text intact.
String barcodeIdentity(String value) {
  final code = normalizeBarcode(value);
  return RegExp(r'^[0-9]{12}$').hasMatch(code) ? '0$code' : code;
}

List<String> barcodeAliases(String value) {
  final code = normalizeBarcode(value);
  final identity = barcodeIdentity(code);
  return RegExp(r'^0[0-9]{12}$').hasMatch(identity)
      ? {code, identity, identity.substring(1)}.toList()
      : [code];
}

bool validBarcode(String value) =>
    value.length <= 128 &&
    (value.isEmpty || RegExp(r'^[\x20-\x7E]+$').hasMatch(value));

/// A deterministic safe Firestore ID, including for Code 128 containing '/'.
String barcodeReservationId(String value) =>
    sha256.convert(utf8.encode(barcodeIdentity(value))).toString();
