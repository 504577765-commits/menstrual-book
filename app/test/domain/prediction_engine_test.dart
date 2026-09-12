import 'package:flutter_test/flutter_test.dart';
import 'package:yuejingben/domain/entities/cycle.dart';
import 'package:yuejingben/domain/prediction/prediction_engine.dart';

void main() {
  const engine = PredictionEngine();

  Cycle c(DateTime start, {DateTime? end}) => Cycle(startDate: start, endDate: end);

  group('无数据 / 冷启动', () {
    test('完全没有数据时置信度为 none 且不给出预测', () {
      final r = engine.predict(PredictionInput(
        cycles: const [],
        today: DateTime(2026, 3, 1),
        defaultCycleLen: 28,
        defaultPeriodLen: 5,
      ));

      expect(r.hasData, isFalse);
      expect(r.confidence, Confidence.none);
      expect(r.nextStart, isNull);
      expect(r.state, CycleState.idle);
    });

    test('仅有引导填写的上次经期时，用默认周期推算首次预测', () {
      final r = engine.predict(PredictionInput(
        cycles: const [],
        today: DateTime(2026, 3, 1),
        defaultCycleLen: 28,
        lastKnownStart: DateTime(2026, 2, 20),
      ));

      expect(r.nextStart, DateTime(2026, 3, 20));
      // 已经给出了预测，置信度应为「低」，不能显示成「暂无数据」。
      expect(r.confidence, Confidence.low);
      expect(r.daysUntilNext, 19);
    });

    test('只有 1 条记录时置信度为低而不是无数据', () {
      final r = engine.predict(PredictionInput(
        cycles: [c(DateTime(2026, 2, 20), end: DateTime(2026, 2, 24))],
        today: DateTime(2026, 3, 1),
      ));

      expect(r.sampleCount, 0);
      expect(r.confidence, Confidence.low);
      expect(r.nextStart, DateTime(2026, 3, 20));
    });
  });

  group('置信度分级', () {
    test('1 个完整周期间隔 → low', () {
      final r = engine.predict(PredictionInput(
        cycles: [c(DateTime(2026, 1, 1), end: DateTime(2026, 1, 5)), c(DateTime(2026, 1, 29), end: DateTime(2026, 2, 2))],
        today: DateTime(2026, 2, 10),
      ));

      expect(r.sampleCount, 1);
      expect(r.confidence, Confidence.low);
      expect(r.avgCycleLen, 28);
    });

    test('3 个周期间隔 → medium', () {
      final r = engine.predict(PredictionInput(
        cycles: [
          c(DateTime(2026, 1, 1), end: DateTime(2026, 1, 5)),
          c(DateTime(2026, 1, 29), end: DateTime(2026, 2, 2)),
          c(DateTime(2026, 2, 26), end: DateTime(2026, 3, 2)),
          c(DateTime(2026, 3, 26), end: DateTime(2026, 3, 30)),
        ],
        today: DateTime(2026, 4, 1),
      ));

      expect(r.sampleCount, 3);
      expect(r.confidence, Confidence.medium);
      expect(r.avgCycleLen, 28);
    });

    test('6 个周期间隔 → high', () {
      final cycles = List.generate(7, (i) {
        final start = DateTime(2026, 1, 1).add(Duration(days: i * 28));
        return c(start, end: start.add(const Duration(days: 4)));
      });

      final r = engine.predict(PredictionInput(
        cycles: cycles,
        today: DateTime(2026, 1, 10),
      ));

      expect(r.sampleCount, 6);
      expect(r.confidence, Confidence.high);
      expect(r.avgCycleLen, 28);
    });
  });

  group('经期进行中', () {
    test('正确计算第 N 天与预计结束日，未超期不提醒', () {
      final r = engine.predict(PredictionInput(
        cycles: [c(DateTime(2026, 3, 1))],
        today: DateTime(2026, 3, 4),
        defaultPeriodLen: 5,
      ));

      expect(r.state, CycleState.ongoing);
      expect(r.ongoingDayIndex, 4);
      expect(r.ongoingExpectedEnd, DateTime(2026, 3, 5));
      expect(r.ongoingOverExpected, isFalse);
    });

    test('超过平均经期天数后标记为超期（触发温和提醒）', () {
      final r = engine.predict(PredictionInput(
        cycles: [c(DateTime(2026, 3, 1))],
        today: DateTime(2026, 3, 8),
        defaultPeriodLen: 5,
      ));

      expect(r.ongoingDayIndex, 8);
      expect(r.ongoingOverExpected, isTrue);
    });
  });

  group('预测日期已过去', () {
    test('自动滚动到最近的下一个未来周期，并记录推迟天数', () {
      final r = engine.predict(PredictionInput(
        cycles: [c(DateTime(2026, 1, 1), end: DateTime(2026, 1, 5))],
        today: DateTime(2026, 3, 1),
        defaultCycleLen: 28,
      ));

      expect(r.nextStart, DateTime(2026, 3, 26));
      expect(r.overdueDays, 31);
    });
  });

  group('抗离群值', () {
    test('单个极端周期不会污染平均周期长度', () {
      final r = engine.predict(PredictionInput(
        cycles: [
          c(DateTime(2026, 1, 1), end: DateTime(2026, 1, 5)),
          c(DateTime(2026, 1, 29), end: DateTime(2026, 2, 2)),
          c(DateTime(2026, 2, 26), end: DateTime(2026, 3, 2)),
          c(DateTime(2026, 5, 27), end: DateTime(2026, 5, 31)),
          c(DateTime(2026, 6, 24), end: DateTime(2026, 6, 28)),
        ],
        today: DateTime(2026, 7, 1),
      ));

      expect(r.avgCycleLen, 28);
    });
  });

  group('健壮性 / 防御性', () {
    test('默认周期被写坏为 0 或负数时不会死循环，并回落到合法区间', () {
      final r = engine.predict(PredictionInput(
        cycles: const [],
        today: DateTime(2026, 3, 1),
        defaultCycleLen: 0,
        lastKnownStart: DateTime(2026, 2, 20),
      ));

      expect(r.avgCycleLen, greaterThanOrEqualTo(18));
      expect(r.avgCycleLen, lessThanOrEqualTo(60));
      expect(r.nextStart, isNotNull);
    });

    test('默认周期异常偏大时也会被收敛到合法区间', () {
      final r = engine.predict(PredictionInput(
        cycles: const [],
        today: DateTime(2026, 3, 1),
        defaultCycleLen: 9999,
        lastKnownStart: DateTime(2026, 2, 20),
      ));

      expect(r.avgCycleLen, lessThanOrEqualTo(60));
    });

    test('结束日早于开始日的异常记录不会导致崩溃', () {
      final r = engine.predict(PredictionInput(
        cycles: [
          Cycle(startDate: DateTime(2026, 2, 10), endDate: DateTime(2026, 2, 1)),
        ],
        today: DateTime(2026, 3, 1),
      ));

      expect(r.hasData, isTrue);
      expect(r.avgPeriodLen, greaterThan(0));
    });
  });

  group('排卵期', () {
    test('排卵日为下次经期前 14 天，易孕窗口 ±5 天', () {
      final r = engine.predict(PredictionInput(
        cycles: [c(DateTime(2026, 2, 20), end: DateTime(2026, 2, 24))],
        today: DateTime(2026, 3, 1),
        defaultCycleLen: 28,
      ));

      expect(r.nextStart, DateTime(2026, 3, 20));
      expect(r.ovulationDate, DateTime(2026, 3, 6));
      expect(r.fertileStart, DateTime(2026, 3, 1));
      expect(r.fertileEnd, DateTime(2026, 3, 11));
    });
  });
}
