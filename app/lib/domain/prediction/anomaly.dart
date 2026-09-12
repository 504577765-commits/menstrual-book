import '../entities/cycle.dart';
import '../util/dates.dart';

enum AnomalyType { irregular, tooLong, tooShort }

class Anomaly {
  const Anomaly({
    required this.type,
    required this.date,
    required this.detail,
  });

  final AnomalyType type;

  /// 触发日期（该周期的开始日）。
  final DateTime date;
  final String detail;
}

/// 异常评估器（只做标记与温和提示，不做任何医疗诊断）。
///
/// 规则：
/// - 周期长度与平均值偏差 > 7 天，且**连续 2 次** → irregular
/// - 经期 > 8 天 → tooLong
/// - 经期 < 2 天 → tooShort
class AnomalyEvaluator {
  const AnomalyEvaluator({
    this.irregularThresholdDays = 7,
    this.longPeriodDays = 8,
    this.shortPeriodDays = 2,
  });

  final int irregularThresholdDays;
  final int longPeriodDays;
  final int shortPeriodDays;

  List<Anomaly> evaluate({
    required List<Cycle> cycles,
    required int avgCycleLen,
  }) {
    final sorted = <Cycle>[...cycles]
      ..sort((a, b) => dateOnly(a.startDate).compareTo(dateOnly(b.startDate)));

    final result = <Anomaly>[];

    var previousIrregular = false;
    for (var i = 0; i < sorted.length - 1; i++) {
      final len = daysBetween(sorted[i].startDate, sorted[i + 1].startDate);
      if (len <= 0) continue;

      final deviation = (len - avgCycleLen).abs();
      final currentIrregular = deviation > irregularThresholdDays;

      if (currentIrregular && previousIrregular) {
        result.add(Anomaly(
          type: AnomalyType.irregular,
          date: dateOnly(sorted[i + 1].startDate),
          detail: '本次周期 $len 天，与你的平均 $avgCycleLen 天相差 $deviation 天',
        ));
        // 连续更长时避免重复堆叠提示，重置后再计。
        previousIrregular = false;
      } else {
        previousIrregular = currentIrregular;
      }
    }

    for (final c in sorted) {
      final len = c.lengthInDays;
      if (len == null) continue;
      if (len > longPeriodDays) {
        result.add(Anomaly(
          type: AnomalyType.tooLong,
          date: dateOnly(c.startDate),
          detail: '本次经期持续 $len 天，长于常规范围',
        ));
      } else if (len < shortPeriodDays) {
        result.add(Anomaly(
          type: AnomalyType.tooShort,
          date: dateOnly(c.startDate),
          detail: '本次经期仅 $len 天，短于常规范围',
        ));
      }
    }

    result.sort((a, b) => a.date.compareTo(b.date));
    return result;
  }
}
