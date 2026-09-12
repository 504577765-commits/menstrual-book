import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/stats/cycle_stats.dart';
import '../providers.dart';
import '../theme/app_theme.dart';

class TrendsPage extends ConsumerWidget {
  const TrendsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    final stats = state.stats;

    if (stats.completedCount == 0 && stats.avgCycleLen == 0) {
      return Scaffold(
        appBar: AppBar(title: const Text('趋势')),
        body: const Center(child: Text('记录 2 次以上就能看到周期趋势')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('趋势')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: '平均周期',
                  value: stats.avgCycleLen == 0
                      ? '—'
                      : stats.avgCycleLen.toStringAsFixed(1),
                  unit: '天',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  label: '平均经期',
                  value: stats.avgPeriodLen == 0
                      ? '—'
                      : stats.avgPeriodLen.toStringAsFixed(1),
                  unit: '天',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('近 6 个月周期长度', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  _CycleBarChart(months: stats.months),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('近 6 个月经期天数', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  _PeriodBarChart(months: stats.months),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '统计仅基于你的历史记录推算，仅供参考，不作为医疗诊断依据。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.unit});

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.labelMedium),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 4),
                Text(unit, style: theme.textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 柱高：无数据时给 4px 占位；有数据时按最大值归一化并限制在 [8, chartHeight]。
/// 单独抽出可避免在 widget 树里使用非空断言。
double _barHeight(int? value, int maxValue, double chartHeight) {
  if (value == null) return 4;
  if (maxValue <= 0) return 8;
  return (chartHeight * value / maxValue).clamp(8.0, chartHeight);
}

/// 简约柱状图：列高度按数值归一化，最高值标注数值。
class _BarChart extends StatelessWidget {
  const _BarChart({
    required this.months,
    required this.valueOf,
    required this.color,
  });

  final List<MonthlyStat> months;
  final int? Function(MonthlyStat) valueOf;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final values = months.map(valueOf).toList();
    final present = values.whereType<int>().toList();

    if (present.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text('这段时间还没有数据', style: theme.textTheme.bodySmall),
      );
    }

    final maxValue = present.reduce((a, b) => a > b ? a : b);

    if (maxValue <= 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text('这段时间还没有数据', style: theme.textTheme.bodySmall),
      );
    }

    const chartHeight = 120.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < months.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == months.length - 1 ? 0 : 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (values[i] != null)
                    Text(
                      '${values[i]}',
                      style: theme.textTheme.labelSmall,
                    ),
                  const SizedBox(height: 4),
                  Container(
                    height: _barHeight(values[i], maxValue, chartHeight),
                    decoration: BoxDecoration(
                      color: values[i] == null
                          ? theme.colorScheme.surfaceContainerHighest
                          : color,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${months[i].month}月',
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _CycleBarChart extends StatelessWidget {
  const _CycleBarChart({required this.months});

  final List<MonthlyStat> months;

  @override
  Widget build(BuildContext context) {
    return _BarChart(
      months: months,
      valueOf: (m) => m.cycleLen,
      color: AppColors.predicted,
    );
  }
}

class _PeriodBarChart extends StatelessWidget {
  const _PeriodBarChart({required this.months});

  final List<MonthlyStat> months;

  @override
  Widget build(BuildContext context) {
    return _BarChart(
      months: months,
      valueOf: (m) => m.periodLen,
      color: AppColors.period,
    );
  }
}
