import 'package:flutter_test/flutter_test.dart';
import 'package:yuejingben/domain/prediction/dnd.dart';

void main() {
  group('isInDndWindow', () {
    test('同日区间（22–23）判断正确', () {
      expect(isInDndWindow(hour: 21, startHour: 22, endHour: 23), isFalse);
      expect(isInDndWindow(hour: 22, startHour: 22, endHour: 23), isTrue);
      expect(isInDndWindow(hour: 23, startHour: 22, endHour: 23), isFalse);
    });

    test('跨天区间（22–8）判断正确', () {
      expect(isInDndWindow(hour: 23, startHour: 22, endHour: 8), isTrue);
      expect(isInDndWindow(hour: 3, startHour: 22, endHour: 8), isTrue);
      expect(isInDndWindow(hour: 7, startHour: 22, endHour: 8), isTrue);
      expect(isInDndWindow(hour: 8, startHour: 22, endHour: 8), isFalse);
      expect(isInDndWindow(hour: 12, startHour: 22, endHour: 8), isFalse);
    });

    test('起止相同视为未启用', () {
      expect(isInDndWindow(hour: 10, startHour: 10, endHour: 10), isFalse);
    });
  });

  group('shiftOutOfDnd', () {
    test('原时刻早于勿扰结束时刻时，顺延到当日勿扰结束', () {
      final when = DateTime(2026, 3, 20, 7, 0);
      final shifted = shiftOutOfDnd(when, endHour: 8, minute: 0);

      expect(shifted, DateTime(2026, 3, 20, 8, 0));
    });

    test('原时刻晚于勿扰结束时刻时，顺延到次日勿扰结束（取下一个 08:00）', () {
      final when = DateTime(2026, 3, 20, 23, 0);
      final shifted = shiftOutOfDnd(when, endHour: 8, minute: 0);

      expect(shifted, DateTime(2026, 3, 21, 8, 0));
    });

    test('顺延结果一定晚于原时刻', () {
      for (var h = 0; h < 24; h++) {
        final when = DateTime(2026, 3, 20, h, 0);
        final shifted = shiftOutOfDnd(when, endHour: 8, minute: 0);
        expect(shifted.isAfter(when), isTrue, reason: 'hour=$h');
      }
    });
  });

  group('nextDailyOccurrence', () {
    test('今天的提醒时刻还没到 → 用今天', () {
      final now = DateTime(2026, 3, 20, 8, 0);
      final next = nextDailyOccurrence(now, hour: 9, minute: 0);

      expect(next, DateTime(2026, 3, 20, 9, 0));
    });

    test('今天的提醒时刻已过 → 用明天（避免提醒被顺延丢失）', () {
      final now = DateTime(2026, 3, 20, 10, 0);
      final next = nextDailyOccurrence(now, hour: 9, minute: 0);

      expect(next, DateTime(2026, 3, 21, 9, 0));
    });

    test('结果一定晚于当前时刻', () {
      for (var h = 0; h < 24; h++) {
        for (final m in [0, 30]) {
          final now = DateTime(2026, 3, 20, h, m);
          final next = nextDailyOccurrence(now, hour: h, minute: m);
          expect(next.isAfter(now), isTrue, reason: '$h:$m');
        }
      }
    });
  });
}
