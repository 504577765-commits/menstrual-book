import '../util/dates.dart';

/// 流量强度：三档，UI 用水滴数量三重编码（1/2/3 滴）。
class FlowLevel {
  static const int light = 0;
  static const int medium = 1;
  static const int heavy = 2;

  static const List<String> labels = ['少', '中', '多'];
  static const List<int> drops = [1, 2, 3];
}

/// 痛经程度：四档。
class CrampLevel {
  static const int none = 0;
  static const int mild = 1;
  static const int moderate = 2;
  static const int severe = 3;

  static const List<String> labels = ['无', '轻', '中', '重'];
}

/// 经期主记录（按「次」）。endDate 为 null 表示经期进行中。
class Cycle {
  const Cycle({
    this.id,
    required this.startDate,
    this.endDate,
    this.overallFlow = FlowLevel.medium,
    this.overallCramp = CrampLevel.none,
    this.note,
  });

  final int? id;
  final DateTime startDate;
  final DateTime? endDate;
  final int overallFlow;
  final int overallCramp;
  final String? note;

  bool get isOngoing => endDate == null;

  /// 经期天数（含首尾）；进行中返回 null。
  int? get lengthInDays {
    final end = endDate;
    if (end == null) return null;
    final d = daysBetween(startDate, end) + 1;
    return d > 0 ? d : null;
  }

  /// 该日期是否落在本期经期内（进行中则到今天为止）。
  bool covers(DateTime date, {DateTime? ongoingUntil}) {
    final end = endDate ?? ongoingUntil ?? date;
    return !isBeforeDay(date, startDate) && !isAfterDay(date, end);
  }

  Cycle copyWith({
    int? id,
    DateTime? startDate,
    Object? endDate = _sentinel,
    int? overallFlow,
    int? overallCramp,
    Object? note = _sentinel,
  }) {
    return Cycle(
      id: id ?? this.id,
      startDate: startDate ?? this.startDate,
      endDate: identical(endDate, _sentinel) ? this.endDate : endDate as DateTime?,
      overallFlow: overallFlow ?? this.overallFlow,
      overallCramp: overallCramp ?? this.overallCramp,
      note: identical(note, _sentinel) ? this.note : note as String?,
    );
  }

  static const Object _sentinel = Object();
}
