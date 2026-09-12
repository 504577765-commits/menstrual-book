import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/cycle.dart';
import '../../domain/entities/cycle_day.dart';
import '../../domain/prediction/anomaly.dart';
import '../../domain/util/dates.dart';
import '../providers.dart';
import '../theme/app_theme.dart';
import '../widgets/countdown_card.dart';
import '../widgets/month_calendar.dart';
import '../widgets/record_sheets.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);

  /// 两段式补录：第一次点击选定的开始日（再点一次可取消）。
  DateTime? _pendingStart;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final prediction = state.prediction;
    final anomalies = state.anomalies;

    return Scaffold(
      appBar: AppBar(
        title: const Text('潮汐'),
        actions: [
          IconButton(
            tooltip: '回到本月',
            onPressed: () {
              final now = DateTime.now();
              setState(() => _month = DateTime(now.year, now.month, 1));
            },
            icon: const Icon(Icons.today_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          if (anomalies.isNotEmpty) ...[
            _AnomalyBanner(anomalies: anomalies),
            const SizedBox(height: 12),
          ],
          CountdownCard(
            prediction: prediction,
            onStartPeriod: () => _showStartSheet(context, ref),
            onEndPeriod: () => _endPeriod(context, ref),
            onNotYet: () => _snack(context, '好的，明天再问你一次'),
          ),
          const SizedBox(height: 18),
          // 月份切换时整块月历淡入 + 轻微右滑过渡。
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(begin: const Offset(0.05, 0), end: Offset.zero)
                    .animate(animation),
                child: child,
              ),
            ),
            child: Card(
              key: ValueKey('month-${_month.year}-${_month.month}'),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: MonthCalendar(
                  month: _month,
                  cycles: state.cycles,
                  prediction: prediction,
                  today: state.today,
                  selectedStart: _pendingStart,
                  onChangeMonth: (m) => setState(() => _month = m),
                  onDayTap: (date) => _showDaySheet(context, ref, date),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const _Disclaimer(),
        ],
      ),
    );
  }

  Future<void> _endPeriod(BuildContext context, WidgetRef ref) async {
    final state = ref.read(appStateProvider);
    if (state.ongoingCycle == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('结束这次经期？'),
        content: Text('结束日：${formatDate(state.today)}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认结束'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await state.endPeriod(state.today);
    if (context.mounted) _snack(context, '已记录经期结束');
  }

  Future<void> _showStartSheet(BuildContext context, WidgetRef ref) async {
    // 从其它入口记录时，清空未完成的补录待选状态，避免误结算。
    if (_pendingStart != null) setState(() => _pendingStart = null);
    final state = ref.read(appStateProvider);
    final result = await Navigator.of(context).push<StartPeriodResult>(
      sheetRoute(StartPeriodSheet(today: state.today)),
    );
    if (result == null) return;

    try {
      final error = await state.startPeriod(
        startDate: result.date,
        overallFlow: result.flow,
        overallCramp: result.cramp,
      );
      if (!context.mounted) return;
      _snack(context, error ?? '已记录，预测已更新');
    } catch (e) {
      if (!context.mounted) return;
      _snack(context, '保存失败：$e');
    }
  }

  Future<void> _showDaySheet(
    BuildContext context,
    WidgetRef ref,
    DateTime date,
  ) async {
    final state = ref.read(appStateProvider);

    Cycle? owner;
    for (final c in state.cycles) {
      if (c.covers(date, ongoingUntil: c.isOngoing ? state.today : null)) {
        owner = c;
        break;
      }
    }

    if (owner == null) {
      // 两段式补录进行中：第二次点击选定结束日（再次点击同一天可取消）。
      final pending = _pendingStart;
      if (pending != null) {
        setState(() => _pendingStart = null);
        if (isSameDay(date, pending)) {
          _snack(context, '已取消补录');
          return;
        }

        final start = date.isBefore(pending) ? date : pending;
        final end = date.isBefore(pending) ? pending : date;
        final result = await Navigator.of(context).push<BackfillResult>(
          sheetRoute(BackfillSheet(
            start: start,
            end: end,
            others: state.cycles,
            today: state.today,
          )),
        );
        if (result == null || !context.mounted) return;

        try {
          final days = end.difference(start).inDays + 1;
          final error = await state.startPeriod(
            startDate: result.start,
            overallFlow: result.flow,
            overallCramp: result.cramp,
            ongoing: false,
            endDate: result.end,
          );
          if (!context.mounted) return;
          _snack(context, error ?? '已补录为经期 $days 天');
        } catch (e) {
          if (!context.mounted) return;
          _snack(context, '补录失败：$e');
        }
        return;
      }

      // 非经期日：让用户选择「补录经期」或「记录当天日常」。
      final choice = await showModalBottomSheet<_DayAction>(
        context: context,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTheme.sheetRadius),
          ),
        ),
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_note),
                title: const Text('记录当天日常'),
                subtitle: const Text('爱爱、症状、心情、体重、白带、日记'),
                onTap: () => Navigator.pop(ctx, _DayAction.record),
              ),
              ListTile(
                leading: const Icon(Icons.schedule),
                title: const Text('补录经期'),
                subtitle: const Text('把选中的区间记为一段经期'),
                onTap: () => Navigator.pop(ctx, _DayAction.backfill),
              ),
            ],
          ),
        ),
      );
      if (!context.mounted || choice == null) return;

      if (choice == _DayAction.backfill) {
        setState(() => _pendingStart = date);
        _snack(
          context,
          '已选 ${formatDate(date)} 为开始日，再点一天作为结束日（再次点该日可取消）',
        );
        return;
      }

      await _openDayDetail(
        context,
        ref,
        date,
        fallbackFlow: FlowLevel.medium,
        fallbackCramp: CrampLevel.none,
        showFlowControls: false,
      );
      return;
    }

    await _openDayDetail(
      context,
      ref,
      date,
      owner: owner,
      fallbackFlow: owner.overallFlow,
      fallbackCramp: owner.overallCramp,
    );
  }

  /// 打开某天的详情弹层（六类日常记录 + 经期日的流量/痛经），并处理保存结果。
  Future<void> _openDayDetail(
    BuildContext context,
    WidgetRef ref,
    DateTime date, {
    Cycle? owner,
    required int fallbackFlow,
    required int fallbackCramp,
    bool showFlowControls = true,
  }) async {
    final state = ref.read(appStateProvider);

    final dayRows = owner == null
        ? const <CycleDay>[]
        : state
            .daysOf(owner.id ?? -1)
            .where((d) => isSameDay(d.date, date))
            .toList();
    final day = dayRows.isEmpty ? null : dayRows.first;

    final result = await Navigator.of(context).push<DayDetailResult>(
      sheetRoute(DayDetailSheet(
        date: date,
        initialFlow: day?.flowLevel,
        initialCramp: day?.crampLevel,
        fallbackFlow: fallbackFlow,
        fallbackCramp: fallbackCramp,
        daily: state.dailyOf(date),
        showFlowControls: showFlowControls,
        actions: DailyRecordActions(
          saveIntimacy: (r) async {
            await state.saveIntimacy(r);
            return state.dailyOf(date);
          },
          deleteIntimacy: (id) async {
            await state.deleteIntimacy(id);
            return state.dailyOf(date);
          },
          saveSymptom: (r) async {
            await state.saveSymptom(r);
            return state.dailyOf(date);
          },
          deleteSymptom: (id) async {
            await state.deleteSymptom(id);
            return state.dailyOf(date);
          },
          saveMood: (r) async {
            await state.saveMood(r);
            return state.dailyOf(date);
          },
          deleteMood: (d) async {
            await state.deleteMoodOn(d);
            return state.dailyOf(date);
          },
          saveWeight: (r) async {
            await state.saveWeight(r);
            return state.dailyOf(date);
          },
          deleteWeight: (d) async {
            await state.deleteWeightOn(d);
            return state.dailyOf(date);
          },
          saveDischarge: (r) async {
            await state.saveDischarge(r);
            return state.dailyOf(date);
          },
          deleteDischarge: (d) async {
            await state.deleteDischargeOn(d);
            return state.dailyOf(date);
          },
          saveDiary: (r) async {
            await state.saveDiary(r);
            return state.dailyOf(date);
          },
          deleteDiary: (id) async {
            await state.deleteDiary(id);
            return state.dailyOf(date);
          },
        ),
      )),
    );

    // 非经期日（仅记录日常）或用户未做经期相关的改动时，无流量/痛经可保存。
    if (result == null || result.isNoop || owner == null) return;
    try {
      await state.saveDay(
        cycle: owner,
        date: date,
        flow: result.flow,
        cramp: result.cramp,
      );
      if (context.mounted) _snack(context, '已更新当日详情');
    } catch (e) {
      if (context.mounted) _snack(context, '保存当日详情失败：$e');
    }
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

/// 非经期日点击弹出的操作选择。
enum _DayAction { record, backfill }

class _AnomalyBanner extends StatelessWidget {
  const _AnomalyBanner({required this.anomalies});

  final List<Anomaly> anomalies;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final latest = anomalies.last;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.attention.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: AppColors.attention.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 20, color: AppColors.attention),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('关注提示', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(latest.detail, style: theme.textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(
                  '建议留意；若持续异常可咨询医生。以上信息仅供参考，不作为医疗诊断依据。',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        '预测基于历史记录推算，仅供参考，不作为医疗诊断依据。',
        style: Theme.of(context).textTheme.bodySmall,
        textAlign: TextAlign.center,
      ),
    );
  }
}
