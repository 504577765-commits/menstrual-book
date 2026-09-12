import 'package:flutter_test/flutter_test.dart';
import 'package:menstrual_book/domain/entities/cycle.dart';
import 'package:menstrual_book/domain/stats/cycle_stats.dart';

void main() {
  const calc = CycleStatsCalculator();

  Cycle c(DateTime start, DateTime? end) => Cycle(startDate: start, endDate: end);

  test('无数据时平均值为 0，且仍返回 6 个月序列', () {
    final stats = calc.compute(cycles: const [], today: DateTime(2026, 3, 15));

    expect(stats.avgCycleLen, 0);
    expect(stats.avgPeriodLen, 0);
    expect(stats.months, hasLength(6));
    expect(stats.completedCount, 0);
  });

  test('平均周期与平均经期天数计算正确', () {
    final stats = calc.compute(
      cycles: [
        c(DateTime(2026, 1, 1), DateTime(2026, 1, 5)),
        c(DateTime(2026, 1, 29), DateTime(2026, 2, 2)),
        c(DateTime(2026, 2, 26), DateTime(2026, 3, 2)),
      ],
      today: DateTime(2026, 3, 15),
    );

    expect(stats.avgCycleLen, 28);
    expect(stats.avgPeriodLen, 5);
    expect(stats.completedCount, 3);
  });

  test('月份序列按时间升序，且覆盖到当前月', () {
    final stats = calc.compute(
      cycles: [c(DateTime(2026, 3, 1), DateTime(2026, 3, 5))],
      today: DateTime(2026, 3, 15),
    );

    expect(stats.months.first.year, 2025);
    expect(stats.months.first.month, 10);
    expect(stats.months.last.year, 2026);
    expect(stats.months.last.month, 3);

    final march = stats.months.last;
    expect(march.periodLen, 5);
    expect(march.cycleLen, isNull);
  });

  test('进行中的经期不计入平均经期天数', () {
    final stats = calc.compute(
      cycles: [
        c(DateTime(2026, 1, 1), DateTime(2026, 1, 5)),
        c(DateTime(2026, 3, 1), null),
      ],
      today: DateTime(2026, 3, 3),
    );

    expect(stats.avgPeriodLen, 5);
    expect(stats.completedCount, 1);
  });
}
