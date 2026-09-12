import 'package:flutter_test/flutter_test.dart';
import 'package:menstrual_book/domain/entities/cycle.dart';
import 'package:menstrual_book/domain/entities/reminder_settings.dart';
import 'package:menstrual_book/domain/prediction/prediction_engine.dart';
import 'package:menstrual_book/domain/prediction/reminder_plan.dart';
import 'package:menstrual_book/services/notification_service.dart';

void main() {
  const engine = PredictionEngine();

  PredictionResult predict(List<Cycle> cycles, DateTime today, {int cycleLen = 28}) =>
      engine.predict(PredictionInput(
        cycles: cycles,
        today: today,
        defaultCycleLen: cycleLen,
        defaultPeriodLen: 5,
      ));

  Cycle c(DateTime start, DateTime? end) => Cycle(startDate: start, endDate: end);

  const settings = ReminderSettings();

  group('常规情况', () {
    test('经前 + 经期当天 + 排卵 + 易孕 共 4 条，时间与预测一致', () {
      final today = DateTime(2026, 3, 1, 8, 0);
      final prediction = predict([c(DateTime(2026, 2, 20), DateTime(2026, 2, 24))], today);

      final plan = buildReminderPlan(
        prediction: prediction,
        settings: settings,
        now: today,
      );

      final nextStart = prediction.nextStart!;
      expect(plan, hasLength(4));

      final prePeriod = plan.firstWhere((p) => p.kind == ReminderKind.prePeriod);
      final preDay = nextStart.subtract(Duration(days: settings.prePeriodDays));
      expect(prePeriod.when, DateTime(preDay.year, preDay.month, preDay.day, 9, 0));

      final periodStart = plan.firstWhere((p) => p.kind == ReminderKind.periodStart);
      expect(periodStart.when, DateTime(nextStart.year, nextStart.month, nextStart.day, 9, 0));
    });

    test('关闭某些节点后不再排对应提醒', () {
      final today = DateTime(2026, 3, 1, 8, 0);
      final prediction = predict([c(DateTime(2026, 2, 20), DateTime(2026, 2, 24))], today);

      final plan = buildReminderPlan(
        prediction: prediction,
        settings: settings.copyWith(prePeriod: false, fertile: false, ovulation: false),
        now: today,
      );

      expect(plan, hasLength(1));
      expect(plan.single.kind, ReminderKind.periodStart);
    });

    test('提前天数可配置', () {
      final today = DateTime(2026, 3, 1, 8, 0);
      final prediction = predict([c(DateTime(2026, 2, 20), DateTime(2026, 2, 24))], today);

      final plan = buildReminderPlan(
        prediction: prediction,
        settings: settings.copyWith(prePeriodDays: 5),
        now: today,
      );

      final prePeriod = plan.firstWhere((p) => p.kind == ReminderKind.prePeriod);
      final expectedDay = prediction.nextStart!.subtract(const Duration(days: 5));
      expect(prePeriod.when.day, expectedDay.day);
    });
  });

  group('已推迟', () {
    test('推迟时改排「该记录了吗」，且不再排经前/经期当天提醒', () {
      final today = DateTime(2026, 3, 1, 8, 0);
      final prediction = predict([c(DateTime(2026, 1, 1), DateTime(2026, 1, 5))], today);

      expect(prediction.overdueDays, greaterThan(0));

      final plan = buildReminderPlan(
        prediction: prediction,
        settings: settings,
        now: today,
      );

      expect(plan.any((p) => p.kind == ReminderKind.overduePrompt), isTrue);
      expect(plan.any((p) => p.kind == ReminderKind.prePeriod), isFalse);
      expect(plan.any((p) => p.kind == ReminderKind.periodStart), isFalse);
    });
  });

  group('经期进行中', () {
    test('超过平均天数时排「还在继续吗」，且时间为最近的一次未来时刻', () {
      final today = DateTime(2026, 3, 9, 8, 0);
      final prediction = predict([c(DateTime(2026, 3, 1), null)], today);

      expect(prediction.ongoingOverExpected, isTrue);

      final plan = buildReminderPlan(
        prediction: prediction,
        settings: settings,
        now: today,
      );

      final check = plan.firstWhere((p) => p.kind == ReminderKind.ongoingCheck);
      // 今天 09:00 还没到 → 用今天（而不是永远推到明天）
      expect(check.when, DateTime(2026, 3, 9, 9, 0));
    });
  });

  group('不排已过去的提醒', () {
    test('预测日已在过去的节点不会被排入计划', () {
      final today = DateTime(2026, 3, 1, 8, 0);
      final prediction = predict([c(DateTime(2026, 2, 20), DateTime(2026, 2, 24))], today);

      final plan = buildReminderPlan(
        prediction: prediction,
        settings: settings,
        now: today,
      );

      for (final item in plan) {
        expect(item.when.isAfter(today), isTrue, reason: '$item');
      }
    });
  });

  group('免打扰', () {
    test('提醒时刻落在勿扰区间时顺延到勿扰结束时刻', () {
      final today = DateTime(2026, 3, 1, 8, 0);
      final prediction = predict([c(DateTime(2026, 2, 20), DateTime(2026, 2, 24))], today);

      final plan = buildReminderPlan(
        prediction: prediction,
        settings: settings.copyWith(
          hour: 23,
          dndEnabled: true,
          dndStartHour: 22,
          dndEndHour: 8,
        ),
        now: today,
      );

      for (final item in plan) {
        expect(item.when.hour, 8, reason: '$item');
      }
    });
  });

  group('通知 id 稳定', () {
    test('每种提醒类型映射到唯一且固定的 id（调用真实映射）', () {
      final ids = ReminderKind.values.map(NotificationService.idFor).toSet();
      expect(ids, hasLength(ReminderKind.values.length));
      // 固定值：id 变化会导致旧通知无法被覆盖。
      expect(NotificationService.idFor(ReminderKind.prePeriod), 1001);
      expect(NotificationService.idFor(ReminderKind.overduePrompt), 1006);
    });
  });
}
