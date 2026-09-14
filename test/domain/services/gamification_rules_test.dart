import 'package:flutter_test/flutter_test.dart';
import 'package:spendify/domain/services/gamification_rules.dart';

void main() {
  group('level curve', () {
    test('documented thresholds', () {
      expect(xpThresholdForLevel(1), 0);
      expect(xpThresholdForLevel(2), 200);
      expect(xpThresholdForLevel(3), 500);
      expect(xpThresholdForLevel(4), 900);
      expect(xpThresholdForLevel(5), 1400);
      expect(xpThresholdForLevel(6), 2000);
    });

    test('gaps grow by a flat 100 XP per level (early fast, later slow)', () {
      for (var l = 2; l <= 20; l++) {
        final gap = xpThresholdForLevel(l + 1) - xpThresholdForLevel(l);
        final prevGap = xpThresholdForLevel(l) - xpThresholdForLevel(l - 1);
        expect(gap - prevGap, 100);
      }
    });

    test('levelForXp is the inverse — exact on thresholds', () {
      for (var l = 1; l <= 15; l++) {
        expect(levelForXp(xpThresholdForLevel(l)), l);
        if (l > 1) {
          expect(levelForXp(xpThresholdForLevel(l) - 1), l - 1);
        }
      }
    });

    test('0 or negative XP -> level 1', () {
      expect(levelForXp(0), 1);
      expect(levelForXp(-50), 1);
    });
  });
}
