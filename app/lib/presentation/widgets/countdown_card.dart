import 'package:flutter/material.dart';

import '../../domain/prediction/prediction_engine.dart';
import '../theme/app_theme.dart';

class CountdownCard extends StatelessWidget {
  const CountdownCard({
    super.key,
    required this.prediction,
    required this.onStartPeriod,
    required this.onEndPeriod,
    required this.onNotYet,
  });

  final PredictionResult prediction;
  final VoidCallback onStartPeriod;
  final VoidCallback onEndPeriod;
  final VoidCallback onNotYet;

  String get _confidenceLabel => switch (prediction.confidence) {
        Confidence.none => '暂无数据',
        Confidence.low => '置信度：低',
        Confidence.medium => '置信度：中',
        Confidence.high => '置信度：高',
      };

  String _fmt(DateTime d) => '${d.month} 月 ${d.day} 日';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ongoing = prediction.state == CycleState.ongoing;

    return Card(
      color: scheme.primaryContainer.withValues(alpha: 0.55),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ongoing ? '经期进行中' : '距离下次经期',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (!ongoing)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_confidenceLabel, style: theme.textTheme.labelSmall),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _BigValue(
              ongoing: ongoing,
              prediction: prediction,
              fmt: _fmt,
            ),
            const SizedBox(height: 12),
            if (ongoing)
              _OngoingActions(
                prediction: prediction,
                onEndPeriod: onEndPeriod,
                onNotYet: onNotYet,
                fmt: _fmt,
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onStartPeriod,
                  icon: const Icon(Icons.add),
                  label: const Text('经期来了'),
                ),
              ),
            if (prediction.confidence == Confidence.low && !ongoing) ...[
              const SizedBox(height: 8),
              Text(
                '记录越多，预测越准。',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BigValue extends StatelessWidget {
  const _BigValue({
    required this.ongoing,
    required this.prediction,
    required this.fmt,
  });

  final bool ongoing;
  final PredictionResult prediction;
  final String Function(DateTime) fmt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (ongoing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  '第 ${prediction.ongoingDayIndex ?? 1} 天',
                  style: theme.textTheme.displaySmall
                      ?.copyWith(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (prediction.ongoingExpectedEnd != null) ...[
            const SizedBox(height: 4),
            Text(
              '预计 ${fmt(prediction.ongoingExpectedEnd!)} 结束',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      );
    }

    final days = prediction.daysUntilNext;
    if (days == null) {
      return Text('记录一次即可开始预测', style: theme.textTheme.titleMedium);
    }

    // 预测日已过去：以「已推迟 N 天」为主信息，避免与"还有 N 天"自相矛盾。
    if (prediction.overdueDays > 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  '已推迟 ${prediction.overdueDays}',
                  style: theme.textTheme.displaySmall
                      ?.copyWith(fontWeight: FontWeight.w500, color: AppColors.attention),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Text('天', style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 4),
          Text('记录一下开始日期，预测会更准', style: theme.textTheme.bodySmall),
        ],
      );
    }

    final isToday = days == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                isToday ? '就是今天' : '$days',
                style: theme.textTheme.displayMedium
                    ?.copyWith(fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!isToday) ...[
              const SizedBox(width: 6),
              Text('天', style: theme.textTheme.titleMedium),
            ],
          ],
        ),
        if (prediction.nextStart != null)
          Text(
            isToday ? '预计就是今天' : '预计 ${fmt(prediction.nextStart!)}',
            style: theme.textTheme.bodySmall,
          ),
      ],
    );
  }
}

class _OngoingActions extends StatelessWidget {
  const _OngoingActions({
    required this.prediction,
    required this.onEndPeriod,
    required this.onNotYet,
    required this.fmt,
  });

  final PredictionResult prediction;
  final VoidCallback onEndPeriod;
  final VoidCallback onNotYet;
  final String Function(DateTime) fmt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (prediction.ongoingOverExpected) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.attention.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '已经超过你平时的天数了，还在继续吗？',
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: onEndPeriod,
                child: const Text('经期结束'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: onNotYet,
                child: const Text('仍在继续'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
