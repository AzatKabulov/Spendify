import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spendify/core/constants.dart';
import 'package:spendify/data/repositories/hive_transaction_repository.dart';
import 'package:spendify/domain/entities/enums.dart';
import 'package:spendify/domain/entities/transaction.dart';

import '../../support/hive_test_harness.dart';

void main() {
  test(
    'a written transaction note is not readable as plaintext on disk',
    () async {
      const marker = 'PLAINTEXT_CANARY_teh_tarik_8f3aa1';

      final harness = await HiveTestHarness.start();
      addTearDown(harness.dispose);

      final repo = HiveTransactionRepository(
        harness.store.transactions,
        userId: kLocalUserId,
      );
      await repo.add(
        Transaction.create(
          id: 'enc-1',
          userId: kLocalUserId,
          amountMinor: 450,
          type: TransactionType.expense,
          categoryId: 'cat-food',
          date: DateTime.utc(2026, 9, 6),
          now: DateTime.utc(2026, 9, 6),
          note: marker,
        ),
      );

      // Flush to disk.
      await harness.store.transactions.flush();

      final file = File(harness.hiveFilePath(HiveBoxes.transactions));
      expect(file.existsSync(), isTrue);
      final bytes = await file.readAsBytes();

      // The note must not appear as UTF-8 or Latin-1 bytes anywhere in the file.
      expect(
        _containsAscii(bytes, marker),
        isFalse,
        reason: 'note leaked into the .hive file in cleartext',
      );

      // Sanity: the same box, reopened with the same key, still decrypts.
      final reread = await repo.getByIdIncludingDeleted('enc-1');
      expect(reread!.note, marker);
    },
  );
}

bool _containsAscii(List<int> haystack, String needleAscii) {
  final needle = needleAscii.codeUnits;
  if (needle.isEmpty || haystack.length < needle.length) return false;
  for (var i = 0; i <= haystack.length - needle.length; i++) {
    var match = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        match = false;
        break;
      }
    }
    if (match) return true;
  }
  return false;
}
