import 'package:flutter_test/flutter_test.dart';
import 'package:yuejingben/domain/entities/cycle.dart';
import 'package:yuejingben/domain/prediction/anomaly.dart';

void main() {
  const evaluator = AnomalyEvaluator();

  Cycle c(DateTime start, DateTime end) => Cycle(startDate: start, endDate: end);

  test('单次周期波动不提示（需连续 2 次）', () {
    final result = evaluator.evaluate(
      cycles: [
        c(DateTime(2026, 1, 1), DateTime(2026, 1, 5)),
        c(DateTime(2026, 1, 29), DateTime(2026, 2, 2)),
        c(DateTime(2026, 3, 10), DateTime(2026, 3, 14)),
      ],
      avgCycleLen: 28,
    );

    expect(result.where((a) => a.type == AnomalyType.irregular), isEmpty);
  });

  test('连续 2 次波动 > 7 天才提示周期不规律', () {
    final result = evaluator.evaluate(
      cycles: [
        c(DateTime(2026, 1, 1), DateTime(2026, 1, 5)),
        c(DateTime(2026, 2, 10), DateTime(2026, 2, 14)),
        c(DateTime(2026, 3, 22), DateTime(2026, 3, 26)),
      ],
      avgCycleLen: 28,
    );

    final irregular = result.where((a) => a.type == AnomalyType.irregular).toList();
    expect(irregular, hasLength(1));
    expect(irregular.first.date, DateTime(2026, 3, 22));
  });

  test('经期超过 8 天标记 tooLong', () {
    final result = evaluator.evaluate(
      cycles: [c(DateTime(2026, 1, 1), DateTime(2026, 1, 12))],
      avgCycleLen: 28,
    );

    expect(result.single.type, AnomalyType.tooLong);
  });

  test('经期不足 2 天标记 tooShort', () {
    final result = evaluator.evaluate(
      cycles: [c(DateTime(2026, 1, 1), DateTime(2026, 1, 1))],
      avgCycleLen: 28,
    );

    expect(result.single.type, AnomalyType.tooShort);
  });

  test('结果按日期升序返回', () {
    final result = evaluator.evaluate(
      cycles: [
        c(DateTime(2026, 3, 1), DateTime(2026, 3, 1)),
        c(DateTime(2026, 1, 1), DateTime(2026, 1, 12)),
      ],
      avgCycleLen: 28,
    );

    expect(result.first.date.isBefore(result.last.date), isTrue);
  });
}
