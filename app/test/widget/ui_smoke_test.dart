import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuejingben/domain/entities/cycle.dart';
import 'package:yuejingben/domain/prediction/prediction_engine.dart';
import 'package:yuejingben/presentation/widgets/countdown_card.dart';
import 'package:yuejingben/presentation/widgets/level_widgets.dart';
import 'package:yuejingben/presentation/widgets/month_calendar.dart';

/// 把组件放进最小可运行环境；scale 用于验证大字号下不会布局溢出
/// （RenderFlex overflow 在测试中会直接抛错，能让测试失败）。
Widget harness(Widget child, {double scale = 1.0, double width = 400}) {
  return MaterialApp(
    builder: (context, inner) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
      child: inner!,
    ),
    home: Scaffold(
      body: SizedBox(
        width: width,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  );
}

PredictionResult predict(List<Cycle> cycles, DateTime today, {int cycleLen = 28}) {
  return const PredictionEngine().predict(PredictionInput(
    cycles: cycles,
    today: today,
    defaultCycleLen: cycleLen,
    defaultPeriodLen: 5,
  ));
}

Widget cardFrom(PredictionResult p) => CountdownCard(
      prediction: p,
      onStartPeriod: () {},
      onEndPeriod: () {},
      onNotYet: () {},
    );

void main() {
  group('CountdownCard', () {
    testWidgets('无数据时提示先记录一次', (tester) async {
      final p = predict(const [], DateTime(2026, 3, 1));

      await tester.pumpWidget(harness(cardFrom(p)));

      expect(find.text('记录一次即可开始预测'), findsOneWidget);
    });

    testWidgets('正常倒计时显示剩余天数', (tester) async {
      final p = predict(
        [Cycle(startDate: DateTime(2026, 2, 20), endDate: DateTime(2026, 2, 24))],
        DateTime(2026, 3, 1),
      );

      await tester.pumpWidget(harness(cardFrom(p)));

      expect(find.text('19'), findsOneWidget);
      expect(find.text('天'), findsOneWidget);
      expect(find.textContaining('预计'), findsOneWidget);
    });

    testWidgets('预测日就是今天时显示「就是今天」而不是 0 天', (tester) async {
      final p = predict(
        [Cycle(startDate: DateTime(2026, 2, 20), endDate: DateTime(2026, 2, 24))],
        DateTime(2026, 3, 20),
      );

      await tester.pumpWidget(harness(cardFrom(p)));

      expect(find.text('就是今天'), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('已推迟时以推迟天数为主信息，不再显示自相矛盾的倒计时', (tester) async {
      final p = predict(
        [Cycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 5))],
        DateTime(2026, 3, 1),
      );

      expect(p.overdueDays, 31);

      await tester.pumpWidget(harness(cardFrom(p)));

      expect(find.textContaining('已推迟 31'), findsOneWidget);
      expect(find.text('记录一下开始日期，预测会更准'), findsOneWidget);
    });

    testWidgets('进行中显示第 N 天与结束按钮', (tester) async {
      final p = predict(
        [Cycle(startDate: DateTime(2026, 3, 1))],
        DateTime(2026, 3, 4),
      );

      await tester.pumpWidget(harness(cardFrom(p)));

      expect(find.text('第 4 天'), findsOneWidget);
      expect(find.text('经期结束'), findsOneWidget);
      expect(find.text('仍在继续'), findsOneWidget);
    });

    testWidgets('进行中且超过平均天数时给出温和提示', (tester) async {
      final p = predict(
        [Cycle(startDate: DateTime(2026, 3, 1))],
        DateTime(2026, 3, 9),
      );

      await tester.pumpWidget(harness(cardFrom(p)));

      expect(find.textContaining('还在继续吗'), findsOneWidget);
    });

    testWidgets('大字号（1.4 倍）下不溢出', (tester) async {
      final p = predict(
        [Cycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 5))],
        DateTime(2026, 3, 1),
      );

      await tester.pumpWidget(harness(cardFrom(p), scale: 1.4, width: 320));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('MonthCalendar', () {
    testWidgets('无数据也能正常渲染并可切换月份', (tester) async {
      final p = predict(const [], DateTime(2026, 3, 1));
      DateTime? changedTo;

      await tester.pumpWidget(harness(MonthCalendar(
        month: DateTime(2026, 3, 1),
        cycles: const [],
        prediction: p,
        today: DateTime(2026, 3, 1),
        onDayTap: (_) {},
        onChangeMonth: (m) => changedTo = m,
      )));

      expect(find.text('2026 年 3 月'), findsOneWidget);
      expect(find.text('经期'), findsOneWidget);
      expect(find.text('预测'), findsOneWidget);

      await tester.tap(find.byTooltip('下个月'));
      expect(changedTo, DateTime(2026, 4, 1));
    });

    testWidgets('点击日期会回传对应日期', (tester) async {
      final p = predict(const [], DateTime(2026, 3, 1));
      DateTime? tapped;

      await tester.pumpWidget(harness(MonthCalendar(
        month: DateTime(2026, 3, 1),
        cycles: const [],
        prediction: p,
        today: DateTime(2026, 3, 10),
        onDayTap: (d) => tapped = d,
        onChangeMonth: (_) {},
      )));

      await tester.tap(find.text('15'));
      expect(tapped, DateTime(2026, 3, 15));
    });

    testWidgets('有记录与预测时带色块渲染不报错', (tester) async {
      final p = predict(
        [Cycle(startDate: DateTime(2026, 3, 1), endDate: DateTime(2026, 3, 5))],
        DateTime(2026, 3, 10),
      );

      await tester.pumpWidget(harness(MonthCalendar(
        month: DateTime(2026, 3, 1),
        cycles: [Cycle(startDate: DateTime(2026, 3, 1), endDate: DateTime(2026, 3, 5))],
        prediction: p,
        today: DateTime(2026, 3, 10),
        onDayTap: (_) {},
        onChangeMonth: (_) {},
      )));

      expect(tester.takeException(), isNull);
    });
  });

  group('流量 / 痛经选择器', () {
    testWidgets('点击会回传对应档位', (tester) async {
      int? flow;
      int? cramp;

      await tester.pumpWidget(harness(Column(
        children: [
          FlowSelector(value: 1, onChanged: (v) => flow = v),
          const SizedBox(height: 12),
          CrampSelector(value: 0, onChanged: (v) => cramp = v),
        ],
      )));

      await tester.tap(find.text('多'));
      await tester.tap(find.text('重'));

      expect(flow, 2);
      expect(cramp, 3);
    });

    testWidgets('大字号（1.4 倍）下不溢出', (tester) async {
      await tester.pumpWidget(harness(
        Column(
          children: [
            FlowSelector(value: 0, onChanged: (_) {}),
            const SizedBox(height: 12),
            CrampSelector(value: 0, onChanged: (_) {}),
          ],
        ),
        scale: 1.4,
        width: 320,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
