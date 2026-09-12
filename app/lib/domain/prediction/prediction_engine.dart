import '../entities/cycle.dart';
import '../util/dates.dart';

/// 预测置信度。样本越少越不可信，UI 必须明示。
enum Confidence { none, low, medium, high }

/// 当前周期状态。
enum CycleState { idle, ongoing }

class PredictionInput {
  const PredictionInput({
    this.cycles = const <Cycle>[],
    required this.today,
    this.defaultCycleLen = 28,
    this.defaultPeriodLen = 5,
    this.lastKnownStart,
  });

  /// 全部经期记录（任意顺序，内部按开始日升序处理）。
  final List<Cycle> cycles;

  final DateTime today;

  /// 用户设置的默认周期天数（首启引导填写）。
  final int defaultCycleLen;

  /// 用户设置的默认经期天数。
  final int defaultPeriodLen;

  /// 引导阶段填写的「上次经期开始日」，无任何记录时作为兜底锚点。
  final DateTime? lastKnownStart;
}

class PredictionResult {
  const PredictionResult({
    required this.state,
    required this.confidence,
    required this.avgCycleLen,
    required this.avgPeriodLen,
    required this.hasData,
    required this.sampleCount,
    this.ongoingCycle,
    this.ongoingDayIndex,
    this.ongoingExpectedEnd,
    this.ongoingOverExpected = false,
    this.nextStart,
    this.nextEnd,
    this.ovulationDate,
    this.fertileStart,
    this.fertileEnd,
    this.daysUntilNext,
    this.overdueDays = 0,
  });

  final CycleState state;
  final Confidence confidence;
  final int avgCycleLen;
  final int avgPeriodLen;
  final bool hasData;

  /// 已观测到的完整周期数（决定置信度）。
  final int sampleCount;

  /// 进行中的周期；无则为 null。
  final Cycle? ongoingCycle;

  /// 经期第几天（从 1 起）。
  final int? ongoingDayIndex;

  final DateTime? ongoingExpectedEnd;

  /// 进行中天数已超过平均经期天数 → 触发「还在继续吗」温和提醒。
  final bool ongoingOverExpected;

  final DateTime? nextStart;
  final DateTime? nextEnd;

  /// 日历法估算：下次经期 − 14 天。误差较大，UI 必须标注。
  final DateTime? ovulationDate;
  final DateTime? fertileStart;
  final DateTime? fertileEnd;

  final int? daysUntilNext;

  /// 预测日已过去多少天（0 表示未推迟）。
  final int overdueDays;
}

/// 两段式预测引擎：
/// - 样本 < 3：规则兜底（平均值 / 用户设置值），置信度低
/// - 样本 3–5：去极值 + 近期加权平均，置信度中
/// - 样本 ≥ 6：加权平均 + 线性回归趋势修正，置信度高
///
/// 纯 Dart 实现，无任何 Flutter 依赖，可直接单测。
class PredictionEngine {
  const PredictionEngine({
    this.minCycleLen = 18,
    this.maxCycleLen = 60,
    this.ovulationOffset = 14,
    this.fertileWindow = 5,
  });

  final int minCycleLen;
  final int maxCycleLen;
  final int ovulationOffset;
  final int fertileWindow;

  PredictionResult predict(PredictionInput input) {
    final today = dateOnly(input.today);
    final cycles = <Cycle>[...input.cycles]
      ..sort((a, b) => dateOnly(a.startDate).compareTo(dateOnly(b.startDate)));

    final ongoing = _latestOngoing(cycles);
    final cycleLengths = _cycleLengths(cycles);
    final periodLengths = _periodLengths(cycles);

    final avgCycleLen = _smartAverage(cycleLengths, input.defaultCycleLen);
    final avgPeriodLen = _periodAverage(periodLengths, input.defaultPeriodLen);
    final confidence = _confidenceOf(cycleLengths.length);

    final baseStart = ongoing?.startDate ??
        (cycles.isNotEmpty ? cycles.last.startDate : input.lastKnownStart);

    if (baseStart == null) {
      return PredictionResult(
        state: CycleState.idle,
        confidence: Confidence.none,
        avgCycleLen: avgCycleLen,
        avgPeriodLen: avgPeriodLen,
        hasData: false,
        sampleCount: 0,
      );
    }

    final rawNext = dateOnly(baseStart).add(Duration(days: avgCycleLen));
    final overdue = ongoing != null || !isBeforeDay(rawNext, today)
        ? 0
        : daysBetween(rawNext, today);
    final nextStart = _nextOccurrence(baseStart, avgCycleLen, today);

    final nextEnd = nextStart.add(Duration(days: avgPeriodLen - 1));
    final ovulation = nextStart.subtract(Duration(days: ovulationOffset));

    if (ongoing != null) {
      final dayIndex = daysBetween(ongoing.startDate, today) + 1;
      return PredictionResult(
        state: CycleState.ongoing,
        confidence: confidence,
        avgCycleLen: avgCycleLen,
        avgPeriodLen: avgPeriodLen,
        hasData: true,
        sampleCount: cycleLengths.length,
        ongoingCycle: ongoing,
        ongoingDayIndex: dayIndex < 1 ? 1 : dayIndex,
        ongoingExpectedEnd: dateOnly(ongoing.startDate).add(Duration(days: avgPeriodLen - 1)),
        ongoingOverExpected: dayIndex > avgPeriodLen,
        nextStart: nextStart,
        nextEnd: nextEnd,
        ovulationDate: ovulation,
        fertileStart: ovulation.subtract(Duration(days: fertileWindow)),
        fertileEnd: ovulation.add(Duration(days: fertileWindow)),
        daysUntilNext: daysBetween(today, nextStart),
        overdueDays: 0,
      );
    }

    return PredictionResult(
      state: CycleState.idle,
      confidence: confidence,
      avgCycleLen: avgCycleLen,
      avgPeriodLen: avgPeriodLen,
      hasData: cycles.isNotEmpty,
      sampleCount: cycleLengths.length,
      nextStart: nextStart,
      nextEnd: nextEnd,
      ovulationDate: ovulation,
      fertileStart: ovulation.subtract(Duration(days: fertileWindow)),
      fertileEnd: ovulation.add(Duration(days: fertileWindow)),
      daysUntilNext: daysBetween(today, nextStart),
      overdueDays: overdue,
    );
  }

  /// 观测到的相邻周期长度序列。
  List<int> _cycleLengths(List<Cycle> cycles) {
    final result = <int>[];
    for (var i = 0; i < cycles.length - 1; i++) {
      final len = daysBetween(cycles[i].startDate, cycles[i + 1].startDate);
      if (len > 0) result.add(len);
    }
    return result;
  }

  List<int> _periodLengths(List<Cycle> cycles) =>
      cycles.map((c) => c.lengthInDays).whereType<int>().toList();

  Cycle? _latestOngoing(List<Cycle> cycles) {
    Cycle? candidate;
    for (final c in cycles) {
      if (c.isOngoing && (candidate == null || isAfterDay(c.startDate, candidate.startDate))) {
        candidate = c;
      }
    }
    return candidate;
  }

  DateTime _nextOccurrence(DateTime base, int step, DateTime today) {
    // 防御：步长必须为正，否则下面的循环永远无法推进（会导致界面卡死）。
    final safeStep = step < 1 ? 1 : step;
    var d = dateOnly(base).add(Duration(days: safeStep));

    // 再加一层迭代上限，避免任何意外输入造成无限循环。
    var guard = 0;
    while (isBeforeDay(d, today) && guard < 10000) {
      d = d.add(Duration(days: safeStep));
      guard++;
    }
    return d;
  }

  int _smartAverage(List<int> lens, int fallback) {
    if (lens.isEmpty) return fallback.clamp(minCycleLen, maxCycleLen);
    if (lens.length < 3) return _mean(lens).round().clamp(minCycleLen, maxCycleLen);

    final sample = lens.length > 12 ? lens.sublist(lens.length - 12) : lens;
    final base = _trimmedWeighted(sample);
    if (sample.length < 6) return base.clamp(minCycleLen, maxCycleLen);

    final trend = _linearNext(sample);
    final blended = base * 0.7 + trend * 0.3;
    return blended.round().clamp(minCycleLen, maxCycleLen);
  }

  int _periodAverage(List<int> lens, int fallback) {
    if (lens.isEmpty) return fallback;
    // 中位数比均值更稳：单次极长/极短的经期不会显著拉偏整体判断。
    final sorted = [...lens]..sort();
    final mid = sorted.length ~/ 2;
    final median = sorted.length.isOdd
        ? sorted[mid]
        : ((sorted[mid - 1] + sorted[mid]) / 2).round();
    return median.clamp(1, 15);
  }

  double _mean(List<int> values) => values.reduce((a, b) => a + b) / values.length;

  /// 去掉最大最小值后按时间指数加权（越近权重越高，1x/2x/4x/8x…）。
  /// 相比线性加权更强调近期样本，对最近习惯变化更敏感。
  int _trimmedWeighted(List<int> values) {
    var vals = <int>[...values];
    if (vals.length >= 3) {
      vals.sort();
      vals = vals.sublist(1, vals.length - 1);
    }
    if (vals.isEmpty) return _mean(values).round();

    var sum = 0.0;
    var weightSum = 0.0;
    for (var i = 0; i < vals.length; i++) {
      final w = (1 << i).toDouble(); // 1,2,4,8,…
      sum += vals[i] * w;
      weightSum += w;
    }
    return (sum / weightSum).round();
  }

  /// 一元线性回归，外推下一个周期长度。
  double _linearNext(List<int> values) {
    final n = values.length;
    final mx = (n - 1) / 2.0;
    final my = _mean(values);
    var numerator = 0.0;
    var denominator = 0.0;
    for (var i = 0; i < n; i++) {
      numerator += (i - mx) * (values[i] - my);
      denominator += (i - mx) * (i - mx);
    }
    final slope = denominator == 0 ? 0.0 : numerator / denominator;
    return my + slope * (n - mx);
  }

  Confidence _confidenceOf(int sampleCount) {
    if (sampleCount >= 6) return Confidence.high;
    if (sampleCount >= 3) return Confidence.medium;
    // 只要有锚点（哪怕只有一条记录或引导填写值）就一定给出了预测，
    // 此时置信度是「低」而不是「无数据」，否则会与界面上的倒计时自相矛盾。
    return Confidence.low;
  }
}
