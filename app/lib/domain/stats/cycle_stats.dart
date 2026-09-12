import '../entities/cycle.dart';
import '../util/dates.dart';

/// 单月统计项。cycleLen 为该月「开始的周期」到下一次开始的天数，
/// 未产生下一次记录时为 null。
class MonthlyStat {
  const MonthlyStat({
    required this.year,
    required this.month,
    this.cycleLen,
    this.periodLen,
  });

  final int year;
  final int month;
  final int? cycleLen;
  final int? periodLen;
}

class CycleStats {
  const CycleStats({
    required this.avgCycleLen,
    required this.avgPeriodLen,
    required this.months,
    required this.completedCount,
  });

  /// 平均周期长度（无数据为 0）。
  final double avgCycleLen;

  /// 平均经期天数（无数据为 0）。
  final double avgPeriodLen;

  /// 近 N 个月序列（按时间升序）。
  final List<MonthlyStat> months;

  final int completedCount;
}

/// 趋势与统计计算（纯 Dart，可单测）。
class CycleStatsCalculator {
  const CycleStatsCalculator({this.months = 6});

  final int months;

  CycleStats compute({
    required List<Cycle> cycles,
    required DateTime today,
  }) {
    final sorted = <Cycle>[...cycles]
      ..sort((a, b) => dateOnly(a.startDate).compareTo(dateOnly(b.startDate)));

    final cycleLens = <int>[];
    for (var i = 0; i < sorted.length - 1; i++) {
      final len = daysBetween(sorted[i].startDate, sorted[i + 1].startDate);
      if (len > 0) cycleLens.add(len);
    }
    final periodLens = sorted.map((c) => c.lengthInDays).whereType<int>().toList();

    return CycleStats(
      avgCycleLen: _mean(cycleLens),
      avgPeriodLen: _mean(periodLens),
      months: _monthlySeries(sorted, today),
      completedCount: periodLens.length,
    );
  }

  List<MonthlyStat> _monthlySeries(List<Cycle> sorted, DateTime today) {
    final series = <MonthlyStat>[];
    final anchor = DateTime(today.year, today.month, 1);

    for (var offset = months - 1; offset >= 0; offset--) {
      final monthDate = DateTime(anchor.year, anchor.month - offset, 1);
      final y = monthDate.year;
      final m = monthDate.month;

      int? cycleLen;
      int? periodLen;

      for (var i = 0; i < sorted.length; i++) {
        final c = sorted[i];
        if (c.startDate.year != y || c.startDate.month != m) continue;

        periodLen ??= c.lengthInDays;
        if (i < sorted.length - 1) {
          cycleLen ??= daysBetween(c.startDate, sorted[i + 1].startDate);
        }
      }

      series.add(MonthlyStat(
        year: y,
        month: m,
        cycleLen: cycleLen,
        periodLen: periodLen,
      ));
    }
    return series;
  }

  double _mean(List<int> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }
}
