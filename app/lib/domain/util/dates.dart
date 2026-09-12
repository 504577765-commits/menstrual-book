/// 日期工具：全应用统一按「日历日」计算，忽略时分秒。
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// b - a，按日历日计算（可为负数）。
int daysBetween(DateTime a, DateTime b) => dateOnly(b).difference(dateOnly(a)).inDays;

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool isBeforeDay(DateTime a, DateTime b) => dateOnly(a).isBefore(dateOnly(b));

bool isAfterDay(DateTime a, DateTime b) => dateOnly(a).isAfter(dateOnly(b));

/// 该月第一天。
DateTime startOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

/// 该月天数。
int daysInMonth(DateTime d) {
  final first = startOfMonth(d);
  final next = DateTime(first.year, first.month + 1, 1);
  return next.difference(first).inDays;
}

/// 该月第一天是周几（周一=1 … 周日=7）。
int weekdayOfFirstDay(DateTime d) => startOfMonth(d).weekday;
