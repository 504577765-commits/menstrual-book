import 'package:flutter/material.dart';

import '../../domain/entities/cycle.dart';
import '../../domain/prediction/prediction_engine.dart';
import '../../domain/util/dates.dart';
import '../theme/app_theme.dart';

/// 月历：实际经期 / 预测经期 / 易孕窗口 / 排卵日 用不同色块区分。
class MonthCalendar extends StatelessWidget {
  const MonthCalendar({
    super.key,
    required this.month,
    required this.cycles,
    required this.prediction,
    required this.today,
    required this.onDayTap,
    required this.onChangeMonth,
  });

  final DateTime month;
  final List<Cycle> cycles;
  final PredictionResult prediction;
  final DateTime today;
  final ValueChanged<DateTime> onDayTap;
  final ValueChanged<DateTime> onChangeMonth;

  static const _weekLabels = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = daysInMonth(month);
    final leading = weekdayOfFirstDay(month) - 1;
    final cells = <Widget>[];

    for (var i = 0; i < leading; i++) {
      cells.add(const SizedBox.shrink());
    }

    for (var day = 1; day <= total; day++) {
      final date = DateTime(month.year, month.month, day);
      cells.add(_DayCell(
        date: date,
        mark: _markFor(date),
        isToday: isSameDay(date, today),
        onTap: () => onDayTap(date),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${month.year} 年 ${month.month} 月',
                style: theme.textTheme.titleMedium,
              ),
            ),
            IconButton(
              onPressed: () => onChangeMonth(DateTime(month.year, month.month - 1, 1)),
              icon: const Icon(Icons.chevron_left),
              tooltip: '上个月',
            ),
            IconButton(
              onPressed: () => onChangeMonth(DateTime(month.year, month.month + 1, 1)),
              icon: const Icon(Icons.chevron_right),
              tooltip: '下个月',
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (final w in _weekLabels)
              Expanded(
                child: Center(
                  child: Text(w, style: theme.textTheme.labelSmall),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 0.92,
          children: cells,
        ),
        const SizedBox(height: 10),
        const Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            _LegendDot(color: AppColors.period, label: '经期'),
            _LegendDot(color: AppColors.predicted, label: '预测'),
            _LegendDot(color: AppColors.fertile, label: '易孕窗口'),
          ],
        ),
      ],
    );
  }

  _DayMark _markFor(DateTime date) {
    for (final c in cycles) {
      if (c.covers(date, ongoingUntil: c.isOngoing ? today : null)) {
        return _DayMark.period;
      }
    }

    final nextStart = prediction.nextStart;
    final nextEnd = prediction.nextEnd;
    if (nextStart != null && nextEnd != null) {
      if (!isBeforeDay(date, nextStart) && !isAfterDay(date, nextEnd)) {
        return _DayMark.predicted;
      }
    }

    final ovulation = prediction.ovulationDate;
    if (ovulation != null && isSameDay(date, ovulation)) {
      return _DayMark.ovulation;
    }

    final fertileStart = prediction.fertileStart;
    final fertileEnd = prediction.fertileEnd;
    if (fertileStart != null && fertileEnd != null) {
      if (!isBeforeDay(date, fertileStart) && !isAfterDay(date, fertileEnd)) {
        return _DayMark.fertile;
      }
    }

    return _DayMark.none;
  }
}

enum _DayMark { none, period, predicted, fertile, ovulation }

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.mark,
    required this.isToday,
    required this.onTap,
  });

  final DateTime date;
  final _DayMark mark;
  final bool isToday;
  final VoidCallback onTap;

  Color? get _fill {
    switch (mark) {
      case _DayMark.period:
        return AppColors.period.withValues(alpha: 0.85);
      case _DayMark.predicted:
        return AppColors.predicted.withValues(alpha: 0.75);
      case _DayMark.fertile:
        return AppColors.fertile.withValues(alpha: 0.35);
      case _DayMark.ovulation:
        return AppColors.fertile.withValues(alpha: 0.85);
      case _DayMark.none:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fill = _fill;
    final onFill = mark == _DayMark.period || mark == _DayMark.predicted;

    return Padding(
      padding: const EdgeInsets.all(2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(10),
            border: isToday
                ? Border.all(color: theme.colorScheme.primary, width: 1.5)
                : null,
          ),
          child: Center(
            child: Text(
              '${date.day}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: onFill ? Colors.white : theme.colorScheme.onSurface,
                fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
