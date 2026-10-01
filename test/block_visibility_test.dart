import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:halisaha_app/modules/friends/controllers/block_controller.dart';

void main() {
  testWidgets('cached and newly arriving content react to block and unblock', (
    tester,
  ) async {
    final blocks = BlockController();
    final cached = <String>['alice', 'bob'].obs;
    await tester.pumpWidget(
      MaterialApp(
        home: Obx(() => Text(cached.where(blocks.visible).join(','))),
      ),
    );
    expect(
      find.text('alice,bob'),
      findsNothing,
    ); // No flash before initial block list.
    blocks.blockedUserIds.assignAll(['alice']);
    blocks.ready.value = true;
    await tester.pump();
    expect(find.text('bob'), findsOneWidget);
    cached.assignAll([
      'alice',
      'bob',
      'carol',
    ]); // A late async result must still be filtered.
    await tester.pump();
    expect(find.text('bob,carol'), findsOneWidget);
    blocks.blockedUserIds.remove('alice');
    await tester.pump();
    expect(find.text('alice,bob,carol'), findsOneWidget);
    blocks.blockedUserIds.add('bob');
    await tester.pump();
    expect(find.text('alice,carol'), findsOneWidget);
  });
}
