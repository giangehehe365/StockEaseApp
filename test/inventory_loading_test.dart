// SDK interfaces are implemented only by test doubles.
// ignore_for_file: subtype_of_sealed_class
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockease/models/stock_movement.dart';
import 'package:stockease/screens/dashboard_screen.dart';
import 'package:stockease/services/inventory_service.dart';
import 'package:stockease/services/product_service.dart';

import 'dashboard_navigation_test.dart'
    show
        NavigationFirestore,
        NavigationCollection,
        NavigationDocument,
        NavigationQuerySnapshot;

class WaitingFirestore extends NavigationFirestore {
  final snapshots =
      StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      WaitingCollection(this, path);
}

class WaitingCollection extends NavigationCollection {
  WaitingCollection(WaitingFirestore super.db, super.path);

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      WaitingDocument(db as WaitingFirestore, '${this.path}/${path ?? 'new'}');

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) => (db as WaitingFirestore).snapshots.stream;
}

class WaitingDocument extends NavigationDocument {
  WaitingDocument(WaitingFirestore super.db, super.path);

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      WaitingCollection(db as WaitingFirestore, '$path/$collectionPath');
}

void main() {
  testWidgets(
    'first snapshot timeout is visible and a late snapshot recovers',
    (tester) async {
      final db = WaitingFirestore();
      var retries = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardScreen(
              name: 'Demo',
              storeName: 'Kho demo',
              products: const [],
              onAdd: null,
              onProducts: () {},
              onOpen: (_) {},
              movements: InventoryService(db, 'owner').watchMovements(),
              onRetryMovements: () => retries++,
            ),
          ),
        ),
      );
      await tester.pump(InventoryService.initialLoadTimeout);
      await tester.pump();
      await tester.scrollUntilVisible(find.text('Giao dịch kho'), 250);
      expect(
        find.textContaining('Tải giao dịch kho lâu hơn dự kiến'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Thử lại'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thử lại'));
      expect(retries, 1);
      db.snapshots.add(NavigationQuerySnapshot([]));
      await tester.pump();
      expect(
        find.textContaining('Tải giao dịch kho lâu hơn dự kiến'),
        findsNothing,
      );
      expect(find.text('Giao dịch nhập kho'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        await db.snapshots.close();
        await db.changes.close();
      });
    },
  );

  testWidgets('loaded idle stream stays healthy and cancellation detaches', (
    tester,
  ) async {
    final db = WaitingFirestore();
    final errors = <Object>[];
    final values = <List<StockMovement>>[];
    final sub = InventoryService(
      db,
      'owner',
    ).watchMovements().listen(values.add, onError: errors.add);
    db.snapshots.add(NavigationQuerySnapshot([]));
    await tester.pump();
    await tester.pump(const Duration(minutes: 2));
    expect(values, hasLength(1));
    expect(errors, isEmpty);
    await tester.runAsync(sub.cancel);
    expect(db.snapshots.hasListener, isFalse);
    await tester.runAsync(() async {
      await db.snapshots.close();
      await db.changes.close();
    });
  });

  testWidgets('permission error is preserved without a later timeout error', (
    tester,
  ) async {
    final db = WaitingFirestore();
    final errors = <Object>[];
    final sub = InventoryService(
      db,
      'owner',
    ).watchMovements().listen((_) {}, onError: errors.add);
    db.snapshots.addError(
      FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
    );
    await tester.pump();
    await tester.pump(const Duration(minutes: 1));
    expect(errors, hasLength(1));
    expect(productErrorMessage(errors.single), contains('Không có quyền'));
    await tester.runAsync(() async {
      await sub.cancel();
      await db.snapshots.close();
      await db.changes.close();
    });
  });
}
