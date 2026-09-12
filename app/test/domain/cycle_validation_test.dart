import 'package:flutter_test/flutter_test.dart';
import 'package:yuejingben/domain/entities/cycle.dart';
import 'package:yuejingben/domain/validation/cycle_validation.dart';

void main() {
  final today = DateTime(2026, 3, 15);

  Cycle c(int id, DateTime start, DateTime? end) =>
      Cycle(id: id, startDate: start, endDate: end);

  group('findOverlappingCycle', () {
    test('区间重叠时返回该记录', () {
      final cycles = [c(1, DateTime(2026, 3, 1), DateTime(2026, 3, 5))];

      final found = findOverlappingCycle(
        cycles: cycles,
        start: DateTime(2026, 3, 4),
        end: DateTime(2026, 3, 8),
        today: today,
      );

      expect(found?.id, 1);
    });

    test('相邻但不重叠时为 null', () {
      final cycles = [c(1, DateTime(2026, 3, 1), DateTime(2026, 3, 5))];

      final found = findOverlappingCycle(
        cycles: cycles,
        start: DateTime(2026, 3, 6),
        end: DateTime(2026, 3, 9),
        today: today,
      );

      expect(found, isNull);
    });

    test('进行中的记录以 today 为结束日参与比较', () {
      final cycles = [c(1, DateTime(2026, 3, 10), null)];

      final found = findOverlappingCycle(
        cycles: cycles,
        start: DateTime(2026, 3, 12),
        end: DateTime(2026, 3, 13),
        today: today,
      );

      expect(found?.id, 1);
    });

    test('excludeId 可排除自身', () {
      final cycles = [c(1, DateTime(2026, 3, 1), DateTime(2026, 3, 5))];

      final found = findOverlappingCycle(
        cycles: cycles,
        start: DateTime(2026, 3, 1),
        end: DateTime(2026, 3, 5),
        today: today,
        excludeId: 1,
      );

      expect(found, isNull);
    });
  });

  group('validateCycleRange', () {
    test('结束日早于开始日时报错', () {
      final msg = validateCycleRange(
        cycles: const [],
        start: DateTime(2026, 3, 10),
        end: DateTime(2026, 3, 1),
        today: today,
      );

      expect(msg, '结束日期不能早于开始日期');
    });

    test('不允许进行中却留空结束日时报错', () {
      final msg = validateCycleRange(
        cycles: const [],
        start: DateTime(2026, 3, 10),
        end: null,
        today: today,
        allowOngoing: false,
      );

      expect(msg, contains('进行中'));
    });

    test('与已有记录重叠时报错', () {
      final msg = validateCycleRange(
        cycles: [c(1, DateTime(2026, 3, 1), DateTime(2026, 3, 5))],
        start: DateTime(2026, 3, 3),
        end: DateTime(2026, 3, 7),
        today: today,
      );

      expect(msg, contains('重叠'));
    });

    test('合法区间返回 null', () {
      final msg = validateCycleRange(
        cycles: [c(1, DateTime(2026, 3, 1), DateTime(2026, 3, 5))],
        start: DateTime(2026, 3, 29),
        end: null,
        today: today,
      );

      expect(msg, isNull);
    });
  });
}
