import 'package:cloud_firestore/cloud_firestore.dart';

String cleanProfileText(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ');
String cleanPhone(String value) => value.replaceAll(RegExp(r'[\s().-]'), '');
bool validProfilePhone(String value) =>
    value.isEmpty || RegExp(r'^\+?[0-9]{7,15}$').hasMatch(value);

class StoreProfile {
  const StoreProfile({
    required this.uid,
    this.name = '',
    this.storeName = '',
    this.phoneNumber = '',
    this.storeAddress = '',
    this.createdAt,
    this.updatedAt,
  });
  factory StoreProfile.fromData(String uid, Map<String, dynamic> data) =>
      StoreProfile(
        uid: uid,
        name: data['name'] as String? ?? '',
        storeName: data['storeName'] as String? ?? '',
        phoneNumber: data['phoneNumber'] as String? ?? '',
        storeAddress: data['storeAddress'] as String? ?? '',
        createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
        updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      );
  final String uid;
  final String name;
  final String storeName;
  final String phoneNumber;
  final String storeAddress;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  StoreProfile get normalized => StoreProfile(
    uid: uid,
    name: cleanProfileText(name),
    storeName: cleanProfileText(storeName),
    phoneNumber: cleanPhone(phoneNumber),
    storeAddress: cleanProfileText(storeAddress),
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
  bool sameInformation(StoreProfile other) =>
      uid == other.uid &&
      name == other.name &&
      storeName == other.storeName &&
      phoneNumber == other.phoneNumber &&
      storeAddress == other.storeAddress;
  bool get isValid =>
      name.isNotEmpty &&
      name.length <= 80 &&
      storeName.isNotEmpty &&
      storeName.length <= 80 &&
      validProfilePhone(phoneNumber) &&
      storeAddress.length <= 200;
  Map<String, dynamic> toData() => {
    'name': name,
    'storeName': storeName,
    'phoneNumber': phoneNumber,
    'storeAddress': storeAddress,
  };
}
