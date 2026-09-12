import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuejingben/domain/entities/cycle.dart';
import 'package:yuejingben/presentation/widgets/record_sheets.dart';

/// 打开一个底部弹层，收集其返回值。
class SheetHost<T> {
  T? result;
  bool closed = false;
}

Future<SheetHost<T>> openSheet<T>(
  WidgetTester tester,
  Widget sheet, {
  double scale = 1.0,
  double width = 400,
}) async {
  final host = SheetHost<T>();

  await tester.pumpWidget(MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: Builder(
      builder: (context) => Scaffold(
        body: SizedBox(
          width: width,
          child: Center(
            child: ElevatedButton(
              onPressed: () async {
                host.result = await Navigator.of(context).push<T>(sheetRoute(sheet));
                host.closed = true;
              },
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    ),
  ));

  await tester.tap(find.text('打开'));
  await tester.pumpAndSettle();
  return host;
}

void main() {
  group('StartPeriodSheet', () {
    testWidgets('保存后返回所选日期与档位', (tester) async {
      final host = await openSheet<StartPeriodResult>(
        tester,
        StartPeriodSheet(today: DateTime(2026, 3, 20)),
      );

      expect(find.text('经期来了'), findsOneWidget);

      await tester.tap(find.text('多'));
      await tester.tap(find.text('轻'));
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(host.result, isNotNull);
      expect(host.result!.date, DateTime(2026, 3, 20));
      expect(host.result!.flow, 2);
      expect(host.result!.cramp, 1);
    });

    testWidgets('大字号（1.4 倍）下不溢出', (tester) async {
      await openSheet<StartPeriodResult>(
        tester,
        StartPeriodSheet(today: DateTime(2026, 3, 20)),
        scale: 1.4,
        width: 320,
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('DayDetailSheet', () {
    testWidgets('未做任何改动时返回 noop，不写入伪数据', (tester) async {
      final host = await openSheet<DayDetailResult>(
        tester,
        DayDetailSheet(
          date: DateTime(2026, 3, 20),
          initialFlow: null,
          initialCramp: null,
          fallbackFlow: 1,
          fallbackCramp: 0,
        ),
      );

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(host.result, isNotNull);
      expect(host.result!.isNoop, isTrue);
    });

    testWidgets('改动后返回具体数值', (tester) async {
      final host = await openSheet<DayDetailResult>(
        tester,
        DayDetailSheet(
          date: DateTime(2026, 3, 20),
          initialFlow: null,
          initialCramp: null,
          fallbackFlow: 1,
          fallbackCramp: 0,
        ),
      );

      await tester.tap(find.text('多'));
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(host.result!.isNoop, isFalse);
      expect(host.result!.flow, 2);
    });

    testWidgets('大字号（1.4 倍）下不溢出', (tester) async {
      await openSheet<DayDetailResult>(
        tester,
        DayDetailSheet(
          date: DateTime(2026, 3, 20),
          initialFlow: 1,
          initialCramp: 1,
          fallbackFlow: 1,
          fallbackCramp: 0,
        ),
        scale: 1.4,
        width: 320,
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('EditCycleSheet', () {
    Cycle cycle({required DateTime start, DateTime? end}) => Cycle(
          id: 1,
          startDate: start,
          endDate: end,
        );

    testWidgets('开始日与已有记录重叠时报错且不返回结果', (tester) async {
      final host = await openSheet<EditCycleResult>(
        tester,
        EditCycleSheet(
          cycle: cycle(start: DateTime(2026, 3, 1), end: DateTime(2026, 3, 5)),
          today: DateTime(2026, 3, 20),
          others: [
            Cycle(id: 2, startDate: DateTime(2026, 3, 3), endDate: DateTime(2026, 3, 7)),
          ],
          allowOngoing: false,
        ),
      );

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(find.textContaining('重叠'), findsOneWidget);
      expect(host.result, isNull);
    });

    testWidgets('不允许进行中却保留进行中状态时报错', (tester) async {
      final host = await openSheet<EditCycleResult>(
        tester,
        EditCycleSheet(
          cycle: cycle(start: DateTime(2026, 3, 10)),
          today: DateTime(2026, 3, 20),
          others: const [],
          allowOngoing: false,
        ),
      );

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(find.textContaining('进行中'), findsWidgets);
      expect(host.result, isNull);
    });

    testWidgets('合法记录可正常保存', (tester) async {
      final host = await openSheet<EditCycleResult>(
        tester,
        EditCycleSheet(
          cycle: cycle(start: DateTime(2026, 3, 1), end: DateTime(2026, 3, 5)),
          today: DateTime(2026, 3, 20),
          others: const [],
          allowOngoing: true,
        ),
      );

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(host.result, isNotNull);
      expect(host.result!.start, DateTime(2026, 3, 1));
      expect(host.result!.end, DateTime(2026, 3, 5));
    });

    testWidgets('大字号（1.4 倍）下不溢出', (tester) async {
      await openSheet<EditCycleResult>(
        tester,
        EditCycleSheet(
          cycle: cycle(start: DateTime(2026, 3, 1), end: DateTime(2026, 3, 5)),
          today: DateTime(2026, 3, 20),
          others: const [],
          allowOngoing: true,
        ),
        scale: 1.4,
        width: 320,
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
