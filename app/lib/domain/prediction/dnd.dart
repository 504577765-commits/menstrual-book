/// 免打扰时段判断与顺延（纯函数，便于单测）。
library;

/// [hour] 是否落在勿扰区间 [startHour, endHour) 内。
///
/// 支持跨天区间，例如 22 → 8 表示 22:00–08:00。
/// 起止相同时视为「未启用」。
bool isInDndWindow({
  required int hour,
  required int startHour,
  required int endHour,
}) {
  if (startHour == endHour) return false;
  if (startHour < endHour) return hour >= startHour && hour < endHour;
  return hour >= startHour || hour < endHour;
}

/// 把落在勿扰区间内的提醒时刻顺延到免打扰结束时刻。
///
/// 若顺延得到的时刻不晚于原时刻（例如原定 07:00、勿扰结束 08:00 时同日顺延
/// 结果其实是「更早」的语义冲突），则再推一天，避免提醒被挤到过去而被丢弃。
DateTime shiftOutOfDnd(DateTime when, {required int endHour, required int minute}) {
  final shifted = DateTime(when.year, when.month, when.day, endHour, minute);
  return shifted.isAfter(when) ? shifted : shifted.add(const Duration(days: 1));
}

/// 下一次「每天的 hour:minute」时刻：今天的该时刻还没到就用今天，否则用明天。
///
/// 用途：像「经期还在继续吗」这类每日提醒，若每次都固定取"明天"，用户每打开
/// 一次应用都会把它再推后一天，最终永远不会触发。取"最近的一次未来时刻"可避免。
DateTime nextDailyOccurrence(
  DateTime now, {
  required int hour,
  required int minute,
}) {
  final today = DateTime(now.year, now.month, now.day, hour, minute);
  return today.isAfter(now) ? today : today.add(const Duration(days: 1));
}
