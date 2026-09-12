import '../entities/reminder_settings.dart';
import 'dnd.dart';
import 'prediction_engine.dart';

/// 提醒类型。通知 id 由服务层映射，领域层不关心平台 id。
enum ReminderKind {
  prePeriod,
  periodStart,
  fertile,
  ovulation,
  ongoingCheck,
  overduePrompt,
}

/// 一条待排定的提醒。
class PlannedReminder {
  const PlannedReminder({
    required this.kind,
    required this.title,
    required this.body,
    required this.when,
  });

  final ReminderKind kind;
  final String title;
  final String body;
  final DateTime when;

  @override
  String toString() => 'PlannedReminder($kind, $when)';
}

/// 由预测结果与提醒设置推导出「要排哪些提醒、什么时候排」。
///
/// 抽成纯函数的原因：这段逻辑是核心功能，且历史上出现过两类缺陷——
/// 1) 预测已推迟时仍按未来滚动日排「经前提醒」，与界面上的推迟提示自相矛盾；
/// 2) 每日提醒固定取"明天"，用户每次打开应用都会把它顺延，导致永不触发。
/// 纯函数化之后可直接单测覆盖，不必依赖通知插件。
List<PlannedReminder> buildReminderPlan({
  required PredictionResult prediction,
  required ReminderSettings settings,
  required DateTime now,
}) {
  final plan = <PlannedReminder>[];
  final hour = settings.hour;
  final minute = settings.minute;

  // 把某天的提醒时刻算出来，并处理免打扰顺延。
  DateTime at(DateTime day) {
    final target = DateTime(day.year, day.month, day.day, hour, minute);
    if (!settings.dndEnabled ||
        !isInDndWindow(
          hour: hour,
          startHour: settings.dndStartHour,
          endHour: settings.dndEndHour,
        )) {
      return target;
    }
    return shiftOutOfDnd(target, endHour: settings.dndEndHour, minute: minute);
  }

  // 只排未来的时刻：已经过去的不排，避免装一堆立即触发的通知。
  void add(ReminderKind kind, String title, String body, DateTime day) {
    final when = at(day);
    if (when.isAfter(now)) {
      plan.add(PlannedReminder(kind: kind, title: title, body: body, when: when));
    }
  }

  final nextStart = prediction.nextStart;

  if (prediction.overdueDays > 0) {
    // 预测日已过去且没有新记录：继续按"未来滚动日"排经前提醒会自相矛盾，
    // 改为提示用户去记录。
    add(
      ReminderKind.overduePrompt,
      '上一次经期是不是已经开始了？',
      '预测日已过去 ${prediction.overdueDays} 天，记一下会更准。',
      nextDailyOccurrence(now, hour: hour, minute: minute),
    );
  } else if (nextStart != null) {
    if (settings.prePeriod) {
      add(
        ReminderKind.prePeriod,
        '经期快到了',
        '预计 ${settings.prePeriodDays} 天后开始，提前做好准备。',
        nextStart.subtract(Duration(days: settings.prePeriodDays)),
      );
    }
    if (settings.periodStart) {
      add(
        ReminderKind.periodStart,
        '预计今天开始',
        '如果已经来了，记得在「潮汐」里点一下记录。',
        nextStart,
      );
    }
  }

  final ovulation = prediction.ovulationDate;
  if (settings.ovulation && ovulation != null) {
    add(
      ReminderKind.ovulation,
      '排卵日估算',
      '日历法估算，误差较大，仅供参考。',
      ovulation,
    );
  }

  final fertileStart = prediction.fertileStart;
  if (settings.fertile && fertileStart != null) {
    add(
      ReminderKind.fertile,
      '易孕窗口开始',
      '日历法估算，误差较大，仅供参考。',
      fertileStart,
    );
  }

  if (prediction.state == CycleState.ongoing && prediction.ongoingOverExpected) {
    add(
      ReminderKind.ongoingCheck,
      '经期还在继续吗',
      '已经超过你平时的天数了，点一下「已结束」或「仍在继续」。',
      nextDailyOccurrence(now, hour: hour, minute: minute),
    );
  }

  return plan;
}
