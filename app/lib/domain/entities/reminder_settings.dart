/// 提醒设置（领域层值对象）。
///
/// 放在领域层而非数据层：数据层负责持久化，领域层负责规则，
/// 依赖方向应为 data → domain，不能反向。
class ReminderSettings {
  const ReminderSettings({
    this.prePeriod = true,
    this.prePeriodDays = 2,
    this.periodStart = true,
    this.fertile = true,
    this.ovulation = true,
    this.hour = 9,
    this.minute = 0,
    this.dndEnabled = false,
    this.dndStartHour = 22,
    this.dndEndHour = 8,
  });

  final bool prePeriod;
  final int prePeriodDays;
  final bool periodStart;
  final bool fertile;
  final bool ovulation;
  final int hour;
  final int minute;
  final bool dndEnabled;
  final int dndStartHour;
  final int dndEndHour;

  ReminderSettings copyWith({
    bool? prePeriod,
    int? prePeriodDays,
    bool? periodStart,
    bool? fertile,
    bool? ovulation,
    int? hour,
    int? minute,
    bool? dndEnabled,
    int? dndStartHour,
    int? dndEndHour,
  }) {
    return ReminderSettings(
      prePeriod: prePeriod ?? this.prePeriod,
      prePeriodDays: prePeriodDays ?? this.prePeriodDays,
      periodStart: periodStart ?? this.periodStart,
      fertile: fertile ?? this.fertile,
      ovulation: ovulation ?? this.ovulation,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      dndEnabled: dndEnabled ?? this.dndEnabled,
      dndStartHour: dndStartHour ?? this.dndStartHour,
      dndEndHour: dndEndHour ?? this.dndEndHour,
    );
  }
}
