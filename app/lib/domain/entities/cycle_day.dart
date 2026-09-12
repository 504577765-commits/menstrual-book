import '../util/dates.dart';

/// 经期每日详情（选填）。flowLevel / crampLevel 为 null 表示当天未填写，
/// 展示时回落到所属周期的整体概览值。
class CycleDay {
  const CycleDay({
    this.id,
    required this.cycleId,
    required this.date,
    required this.dayIndex,
    this.flowLevel,
    this.crampLevel,
    this.note,
  });

  final int? id;
  final int cycleId;
  final DateTime date;
  final int dayIndex;

  /// 0 少 / 1 中 / 2 多；null = 未填写。
  final int? flowLevel;

  /// 0 无 / 1 轻 / 2 中 / 3 重；null = 未填写。
  final int? crampLevel;

  final String? note;

  bool get hasFlow => flowLevel != null;
  bool get hasCramp => crampLevel != null;

  /// 有值用当日值，否则回落到整次概览。
  int effectiveFlow(int overallFlow) => flowLevel ?? overallFlow;
  int effectiveCramp(int overallCramp) => crampLevel ?? overallCramp;

  CycleDay copyWith({
    int? id,
    int? cycleId,
    DateTime? date,
    int? dayIndex,
    Object? flowLevel = _sentinel,
    Object? crampLevel = _sentinel,
    Object? note = _sentinel,
  }) {
    return CycleDay(
      id: id ?? this.id,
      cycleId: cycleId ?? this.cycleId,
      date: date ?? this.date,
      dayIndex: dayIndex ?? this.dayIndex,
      flowLevel: identical(flowLevel, _sentinel) ? this.flowLevel : flowLevel as int?,
      crampLevel: identical(crampLevel, _sentinel) ? this.crampLevel : crampLevel as int?,
      note: identical(note, _sentinel) ? this.note : note as String?,
    );
  }

  static const Object _sentinel = Object();

  static int indexOf(DateTime cycleStart, DateTime date) => daysBetween(cycleStart, date) + 1;
}
