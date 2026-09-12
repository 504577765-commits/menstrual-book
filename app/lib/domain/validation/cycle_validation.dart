import '../entities/cycle.dart';
import '../util/dates.dart';

/// 查找与 [start, end] 区间重叠的已有记录（可排除自身），没有则返回 null。
/// 进行中的记录以 [today] 作为其结束日参与比较。
Cycle? findOverlappingCycle({
  required List<Cycle> cycles,
  required DateTime start,
  required DateTime end,
  required DateTime today,
  int? excludeId,
}) {
  for (final cycle in cycles) {
    if (excludeId != null && cycle.id == excludeId) continue;
    final cycleEnd = cycle.endDate ?? today;
    final overlaps =
        !isBeforeDay(end, cycle.startDate) && !isBeforeDay(cycleEnd, start);
    if (overlaps) return cycle;
  }
  return null;
}

/// 校验一条待写入的经期记录是否合法，返回错误文案；null 表示通过。
///
/// 规则：
/// - 结束日不得早于开始日
/// - [allowOngoing] 为 false 时不允许留空结束日（避免出现两条进行中的记录）
/// - 不得与已有记录区间重叠
String? validateCycleRange({
  required List<Cycle> cycles,
  required DateTime start,
  required DateTime? end,
  required DateTime today,
  int? excludeId,
  bool allowOngoing = true,
}) {
  if (end != null && isBeforeDay(end, start)) {
    return '结束日期不能早于开始日期';
  }

  if (end == null && !allowOngoing) {
    return '已经有一条进行中的经期了，不能同时存在两条';
  }

  final conflict = findOverlappingCycle(
    cycles: cycles,
    start: start,
    end: end ?? today,
    today: today,
    excludeId: excludeId,
  );
  if (conflict != null) {
    final d = conflict.startDate;
    return '与已有记录（${d.year}/${d.month}/${d.day} 起）重叠';
  }

  return null;
}
