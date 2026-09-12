import 'package:flutter/material.dart';

import '../../domain/entities/cycle.dart';
import '../../domain/validation/cycle_validation.dart';
import '../theme/app_theme.dart';
import 'level_widgets.dart';

/// 「经期来了」弹层返回结果。
class StartPeriodResult {
  const StartPeriodResult(this.date, this.flow, this.cramp);

  final DateTime date;
  final int flow;
  final int cramp;
}

/// 每日详情弹层返回结果。
class DayDetailResult {
  const DayDetailResult(this.flow, this.cramp) : isNoop = false;

  /// 用户只是查看、未做任何改动，且当日原本没有数据 → 视为无操作，避免写入伪数据。
  const DayDetailResult.noop()
      : flow = null,
        cramp = null,
        isNoop = true;

  final int? flow;
  final int? cramp;
  final bool isNoop;
}

/// 编辑历史记录弹层返回结果。
class EditCycleResult {
  const EditCycleResult(this.start, this.end, this.flow, this.cramp);

  final DateTime start;
  final DateTime? end;
  final int flow;
  final int cramp;
}

/// 两段式补录（先选开始日、再选结束日）后弹出的补录面板返回结果。
class BackfillResult {
  const BackfillResult(this.start, this.end, this.flow, this.cramp);

  final DateTime start;
  final DateTime end;
  final int flow;
  final int cramp;
}

String formatDate(DateTime d) => '${d.year} 年 ${d.month} 月 ${d.day} 日';

/// 两段式补录面板：展示所选区间，选择整体流量与痛经后保存。
class BackfillSheet extends StatefulWidget {
  const BackfillSheet({
    super.key,
    required this.start,
    required this.end,
    required this.others,
    required this.today,
  });

  final DateTime start;
  final DateTime end;

  /// 除本次补录外的其余记录，用于重叠校验。
  final List<Cycle> others;
  final DateTime today;

  @override
  State<BackfillSheet> createState() => _BackfillSheetState();
}

class _BackfillSheetState extends State<BackfillSheet> {
  late int _flow = FlowLevel.medium;
  late int _cramp = CrampLevel.none;
  String? _error;

  int get _days => widget.end.difference(widget.start).inDays + 1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SheetScaffold(
      title: '补录经期',
      subtitle:
          '${formatDate(widget.start)} 至 ${formatDate(widget.end)}，共 $_days 天',
      children: [
        if (_error != null) ...[
          const SizedBox(height: 4),
          Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
        ],
        const SizedBox(height: 8),
        Text('整体流量', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        FlowSelector(value: _flow, onChanged: (v) => setState(() => _flow = v)),
        const SizedBox(height: 16),
        Text('整体痛经程度', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        CrampSelector(value: _cramp, onChanged: (v) => setState(() => _cramp = v)),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () {
              final error = validateCycleRange(
                cycles: widget.others,
                start: widget.start,
                end: widget.end,
                today: widget.today,
                allowOngoing: false,
              );
              if (error != null) {
                setState(() => _error = error);
                return;
              }
              setState(() => _error = null);
              Navigator.pop(
                context,
                BackfillResult(widget.start, widget.end, _flow, _cramp),
              );
            },
            child: const Text('保存补录'),
          ),
        ),
      ],
    );
  }
}

/// 记录一次经期：日期 + 整次流量/痛经概览。
class StartPeriodSheet extends StatefulWidget {
  const StartPeriodSheet({super.key, this.today});

  final DateTime? today;

  @override
  State<StartPeriodSheet> createState() => _StartPeriodSheetState();
}

class _StartPeriodSheetState extends State<StartPeriodSheet> {
  late DateTime _date = widget.today ?? DateTime.now();
  int _flow = FlowLevel.medium;
  int _cramp = CrampLevel.none;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SheetScaffold(
      title: '经期来了',
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('开始日期'),
          subtitle: Text(formatDate(_date)),
          trailing: const Icon(Icons.edit_calendar_outlined),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _date,
              firstDate: DateTime(2000),
              lastDate: widget.today ?? DateTime.now(),
            );
            if (picked != null) setState(() => _date = picked);
          },
        ),
        const SizedBox(height: 8),
        Text('整体流量', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        FlowSelector(value: _flow, onChanged: (v) => setState(() => _flow = v)),
        const SizedBox(height: 16),
        Text('整体痛经程度', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        CrampSelector(value: _cramp, onChanged: (v) => setState(() => _cramp = v)),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () =>
                Navigator.pop(context, StartPeriodResult(_date, _flow, _cramp)),
            child: const Text('保存'),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '经期内可以逐天补充流量与痛经，不填也能用。',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// 某一天的流量/痛经详情（选填）。
class DayDetailSheet extends StatefulWidget {
  const DayDetailSheet({
    super.key,
    required this.date,
    required this.initialFlow,
    required this.initialCramp,
    required this.fallbackFlow,
    required this.fallbackCramp,
  });

  final DateTime date;
  final int? initialFlow;
  final int? initialCramp;
  final int fallbackFlow;
  final int fallbackCramp;

  @override
  State<DayDetailSheet> createState() => _DayDetailSheetState();
}

class _DayDetailSheetState extends State<DayDetailSheet> {
  late int? _flow = widget.initialFlow;
  late int? _cramp = widget.initialCramp;
  bool _flowTouched = false;
  bool _crampTouched = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SheetScaffold(
      title: '${widget.date.month} 月 ${widget.date.day} 日',
      subtitle: _flow == null && _cramp == null
          ? '未填写，展示时使用整次概览：'
              '${FlowLevel.labels[widget.fallbackFlow]} / '
              '${CrampLevel.labels[widget.fallbackCramp]}'
          : '当日详情已填写，优先展示当日数据',
      children: [
        Text('当日流量', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        FlowSelector(
          value: _flow ?? widget.fallbackFlow,
          onChanged: (v) => setState(() {
            _flow = v;
            _flowTouched = true;
          }),
        ),
        const SizedBox(height: 16),
        Text('当日痛经', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        CrampSelector(
          value: _cramp ?? widget.fallbackCramp,
          onChanged: (v) => setState(() {
            _cramp = v;
            _crampTouched = true;
          }),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () {
              final untouched = !_flowTouched && !_crampTouched;
              final wasEmpty =
                  widget.initialFlow == null && widget.initialCramp == null;
              if (untouched && wasEmpty) {
                Navigator.pop(context, const DayDetailResult.noop());
                return;
              }
              Navigator.pop(context, DayDetailResult(_flow, _cramp));
            },
            child: const Text('保存'),
          ),
        ),
      ],
    );
  }
}

/// 编辑一条历史经期记录。
class EditCycleSheet extends StatefulWidget {
  const EditCycleSheet({
    super.key,
    required this.cycle,
    required this.today,
    required this.others,
    required this.allowOngoing,
  });

  final Cycle cycle;
  final DateTime today;

  /// 除本条外的其余记录，用于重叠校验。
  final List<Cycle> others;

  /// 是否允许本条保持「进行中」。
  final bool allowOngoing;

  @override
  State<EditCycleSheet> createState() => _EditCycleSheetState();
}

class _EditCycleSheetState extends State<EditCycleSheet> {
  late DateTime _start = widget.cycle.startDate;
  late DateTime? _end = widget.cycle.endDate;
  late int _flow = widget.cycle.overallFlow;
  late int _cramp = widget.cycle.overallCramp;
  String? _error;

  /// 复用领域层统一校验规则，避免与状态层出现两套规则。
  String? _validate() => validateCycleRange(
        cycles: widget.others,
        start: _start,
        end: _end,
        today: widget.today,
        allowOngoing: widget.allowOngoing,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SheetScaffold(
      title: '编辑记录',
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('开始日期'),
          subtitle: Text(formatDate(_start)),
          trailing: const Icon(Icons.edit_calendar_outlined),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _start,
              firstDate: DateTime(2000),
              lastDate: widget.today,
            );
            if (picked != null) setState(() => _start = picked);
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('结束日期'),
          subtitle: Text(_end == null ? '进行中（未结束）' : formatDate(_end!)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_end != null)
                IconButton(
                  tooltip: '标记为进行中',
                  onPressed: () => setState(() => _end = null),
                  icon: const Icon(Icons.restart_alt),
                ),
              const Icon(Icons.edit_calendar_outlined),
            ],
          ),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _end ?? _start,
              firstDate: _start,
              lastDate: widget.today,
            );
            if (picked != null) setState(() => _end = picked);
          },
        ),
        if (_error != null) ...[
          const SizedBox(height: 4),
          Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
        ],
        const SizedBox(height: 8),
        Text('整体流量', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        FlowSelector(value: _flow, onChanged: (v) => setState(() => _flow = v)),
        const SizedBox(height: 16),
        Text('整体痛经程度', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        CrampSelector(value: _cramp, onChanged: (v) => setState(() => _cramp = v)),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () {
              final error = _validate();
              if (error != null) {
                setState(() => _error = error);
                return;
              }
              setState(() => _error = null);
              Navigator.pop(
                context,
                EditCycleResult(_start, _end, _flow, _cramp),
              );
            },
            child: const Text('保存'),
          ),
        ),
      ],
    );
  }
}

/// 弹层通用外壳：可滚动 + 自适应键盘，避免大字号下垂直溢出。
class SheetScaffold extends StatelessWidget {
  const SheetScaffold({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 入场动画：内容淡入 + 轻微上移，让弹层打开更柔和。
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - t)),
          child: child,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: theme.textTheme.bodySmall),
              ],
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// 统一的底部弹层样式，供调用方复用。
Route<T> sheetRoute<T>(Widget child) {
  return ModalBottomSheetRoute<T>(
    builder: (_) => child,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.sheetRadius)),
    ),
  );
}
