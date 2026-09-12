import 'package:flutter/material.dart';

import '../../domain/entities/cycle.dart';
import '../../domain/entities/daily_record.dart';
import '../../domain/validation/cycle_validation.dart';
import '../theme/app_theme.dart';
import 'level_widgets.dart';

/// 六类日常记录的操作契约：每次操作后返回归档的最新当日聚合，
/// 供弹层本地刷新（弹层不依赖全局状态重建）。
class DailyRecordActions {
  const DailyRecordActions({
    this.saveIntimacy,
    this.deleteIntimacy,
    this.saveSymptom,
    this.deleteSymptom,
    this.saveMood,
    this.deleteMood,
    this.saveWeight,
    this.deleteWeight,
    this.saveDischarge,
    this.deleteDischarge,
    this.saveDiary,
    this.deleteDiary,
  });

  final Future<DailyRecords> Function(IntimacyRecord r)? saveIntimacy;
  final Future<DailyRecords> Function(int id)? deleteIntimacy;
  final Future<DailyRecords> Function(SymptomRecord r)? saveSymptom;
  final Future<DailyRecords> Function(int id)? deleteSymptom;
  final Future<DailyRecords> Function(MoodRecord r)? saveMood;
  final Future<DailyRecords> Function(DateTime date)? deleteMood;
  final Future<DailyRecords> Function(WeightRecord r)? saveWeight;
  final Future<DailyRecords> Function(DateTime date)? deleteWeight;
  final Future<DailyRecords> Function(DischargeRecord r)? saveDischarge;
  final Future<DailyRecords> Function(DateTime date)? deleteDischarge;
  final Future<DailyRecords> Function(DiaryEntry r)? saveDiary;
  final Future<DailyRecords> Function(int id)? deleteDiary;
}

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
    this.daily = DailyRecords.empty,
    this.actions,
    this.showFlowControls = true,
  });

  final DateTime date;
  final int? initialFlow;
  final int? initialCramp;
  final int fallbackFlow;
  final int fallbackCramp;

  /// 当日六类记录（由调用方传入，操作后会通过 actions 回调刷新）。
  final DailyRecords daily;

  /// 六类记录操作；为 null 表示只读（测试/无数据场景）。
  final DailyRecordActions? actions;

  /// 是否展示「当日流量/痛经」选择区。非经期日无周期可归属，隐藏后仅记录日常。
  final bool showFlowControls;

  @override
  State<DayDetailSheet> createState() => _DayDetailSheetState();
}

class _DayDetailSheetState extends State<DayDetailSheet> {
  late int? _flow = widget.initialFlow;
  late int? _cramp = widget.initialCramp;
  bool _flowTouched = false;
  bool _crampTouched = false;
  late DailyRecords _daily = widget.daily;

  DailyRecordActions? get _a => widget.actions;

  /// 执行一次记录操作，成功后用返回的最新聚合刷新本弹层；
  /// 失败不抛出未处理异常，而是弹提示条告知用户，避免保存静默失败。
  Future<void> _mutate(Future<DailyRecords> op) async {
    try {
      final latest = await op;
      if (mounted) setState(() => _daily = latest);
    } catch (e) {
      debugPrint('日常记录操作失败：$e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败，请重试：$e')),
        );
      }
    }
  }

  Future<void> _confirmDelete(String what, VoidCallback onConfirm) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除$what？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) onConfirm();
  }

  Future<void> _open<T>(
    Widget sheet, {
    required Future<DailyRecords> Function(T) onSaved,
  }) async {
    final result = await Navigator.of(context).push<T>(sheetRoute(sheet));
    if (result == null || !mounted) return;
    await _mutate(onSaved(result));
  }

  // ---------- 各记录区的展示与操作 ----------

  Widget _intimacySection() {
    return _DailySection(
      icon: Icons.favorite_outline,
      title: '爱爱',
      onAdd: _a?.saveIntimacy == null
          ? null
          : () => _open<IntimacyRecord>(IntimacyFormSheet(
                date: widget.date,
              ), onSaved: (r) => _a!.saveIntimacy!(r)),
      child: _daily.intimacies.isEmpty
          ? _empty('未记录')
          : Column(
              children: [
                for (final r in _daily.intimacies)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(r.protected ? '使用了安全措施' : '未使用安全措施'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: _a == null
                              ? null
                              : () => _open<IntimacyRecord>(
                                    IntimacyFormSheet(date: widget.date, initial: r),
                                    onSaved: (v) => _a!.saveIntimacy!(v),
                                  ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          onPressed: _a == null
                              ? null
                              : () => _confirmDelete(
                                    '这条爱爱记录',
                                    () => _mutate(_a!.deleteIntimacy!(r.id!)),
                                  ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _symptomSection() {
    return _DailySection(
      icon: Icons.healing_outlined,
      title: '症状',
      onAdd: _a?.saveSymptom == null
          ? null
          : () => _open<SymptomRecord>(
                SymptomFormSheet(date: widget.date),
                onSaved: (r) => _a!.saveSymptom!(r),
              ),
      child: _daily.symptoms.isEmpty
          ? _empty('未记录')
          : Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final r in _daily.symptoms)
                  InputChip(
                    label: Text(
                      '${SymptomKind.items[r.symptom]} · '
                      '${SymptomSeverity.items[r.severity]}',
                    ),
                    onPressed: _a == null
                        ? null
                        : () => _open<SymptomRecord>(
                              SymptomFormSheet(date: widget.date, initial: r),
                              onSaved: (v) => _a!.saveSymptom!(v),
                            ),
                    onDeleted: _a == null
                        ? null
                        : () => _confirmDelete(
                              '症状「${SymptomKind.items[r.symptom]}」',
                              () => _mutate(_a!.deleteSymptom!(r.id!)),
                            ),
                  ),
              ],
            ),
    );
  }

  Widget _moodSection() {
    const face = ['😣', '🙁', '😐', '🙂', '😄'];
    final mood = _daily.mood;
    return _DailySection(
      icon: Icons.mood_outlined,
      title: '心情',
      onAdd: _a?.saveMood == null
          ? null
          : () => _open<MoodRecord>(
                MoodFormSheet(date: widget.date, initial: mood),
                onSaved: (r) => _a!.saveMood!(r),
              ),
      child: mood == null
          ? _empty('未记录')
          : InputChip(
              label: Text(
                '${face[mood.score - 1]} ${mood.emotions.map((e) => MoodEmotion.items[e]).join(' ')}'
                '${mood.emotions.isNotEmpty ? ' ' : ''}${mood.note ?? ''}'.trim(),
              ),
              onDeleted: _a == null
                  ? null
                  : () => _confirmDelete(
                        '当天心情',
                        () => _mutate(_a!.deleteMood!(widget.date)),
                      ),
            ),
    );
  }

  Widget _weightSection() {
    final w = _daily.weight;
    return _DailySection(
      icon: Icons.monitor_weight_outlined,
      title: '体重',
      onAdd: _a?.saveWeight == null
          ? null
          : () => _open<WeightRecord>(
                WeightFormSheet(date: widget.date, initial: w),
                onSaved: (r) => _a!.saveWeight!(r),
              ),
      child: w == null
          ? _empty('未记录')
          : ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text('${w.kg.toStringAsFixed(1)} kg'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                onPressed: _a == null
                    ? null
                    : () => _confirmDelete(
                          '当天体重',
                          () => _mutate(_a!.deleteWeight!(widget.date)),
                        ),
              ),
            ),
    );
  }

  Widget _dischargeSection() {
    final d = _daily.discharge;
    return _DailySection(
      icon: Icons.water_drop_outlined,
      title: '白带',
      onAdd: _a?.saveDischarge == null
          ? null
          : () => _open<DischargeRecord>(
                DischargeFormSheet(date: widget.date, initial: d),
                onSaved: (r) => _a!.saveDischarge!(r),
              ),
      child: d == null
          ? _empty('未记录')
          : ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                '${DischargeStatus.items[d.status]} · 量${DischargeAmount.items[d.amount]}'
                ' · 气味${DischargeSense.items[d.smell]}'
                '${d.itch ? ' · 瘙痒' : ''}',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                onPressed: _a == null
                    ? null
                    : () => _confirmDelete(
                          '当天白带',
                          () => _mutate(_a!.deleteDischarge!(widget.date)),
                        ),
              ),
            ),
    );
  }

  Widget _diarySection() {
    return _DailySection(
      icon: Icons.edit_note,
      title: '日记',
      onAdd: _a?.saveDiary == null
          ? null
          : () => _open<DiaryEntry>(
                DiaryFormSheet(date: widget.date),
                onSaved: (r) => _a!.saveDiary!(r),
              ),
      child: _daily.diaries.isEmpty
          ? _empty('未记录')
          : Column(
              children: [
                for (final d in _daily.diaries)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(d.content, maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: _a == null
                              ? null
                              : () => _open<DiaryEntry>(
                                    DiaryFormSheet(date: widget.date, initial: d),
                                    onSaved: (v) => _a!.saveDiary!(v),
                                  ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          onPressed: _a == null
                              ? null
                              : () => _confirmDelete(
                                    '这篇日记',
                                    () => _mutate(_a!.deleteDiary!(d.id!)),
                                  ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _empty(String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall),
    );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SheetScaffold(
      title: '${widget.date.month} 月 ${widget.date.day} 日',
      subtitle: widget.showFlowControls
          ? (_flow == null && _cramp == null
              ? '未填写，展示时使用整次概览：'
                  '${FlowLevel.labels[widget.fallbackFlow]} / '
                  '${CrampLevel.labels[widget.fallbackCramp]}'
              : '当日详情已填写，优先展示当日数据')
          : '记录当天的日常',
      children: [
        if (widget.showFlowControls) ...[
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
        ] else
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () =>
                  Navigator.pop(context, const DayDetailResult.noop()),
              child: const Text('完成'),
            ),
          ),
        const Divider(height: 28),
        _intimacySection(),
        _symptomSection(),
        _moodSection(),
        _weightSection(),
        _dischargeSection(),
        _diarySection(),
      ],
    );
  }
}

/// 弹层内一个记录分区：标题 + 右上角添加按钮 + 内容。
class _DailySection extends StatelessWidget {
  const _DailySection({
    required this.icon,
    required this.title,
    required this.child,
    this.onAdd,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
            if (onAdd != null)
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 20),
                tooltip: '添加$title',
                onPressed: onAdd,
              ),
          ],
        ),
        const SizedBox(height: 2),
        child,
        const SizedBox(height: 16),
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

// ==================== 六类日常记录表单 ====================

/// 记录爱爱。
class IntimacyFormSheet extends StatefulWidget {
  const IntimacyFormSheet({super.key, required this.date, this.initial});

  final DateTime date;
  final IntimacyRecord? initial;

  @override
  State<IntimacyFormSheet> createState() => _IntimacyFormSheetState();
}

class _IntimacyFormSheetState extends State<IntimacyFormSheet> {
  late bool _protected = widget.initial?.protected ?? false;

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: '记录爱爱',
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('使用了安全措施'),
          value: _protected,
          onChanged: (v) => setState(() => _protected = v),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.pop(
              context,
              IntimacyRecord(
                id: widget.initial?.id,
                date: widget.date,
                protected: _protected,
              ),
            ),
            child: const Text('保存'),
          ),
        ),
      ],
    );
  }
}

/// 记录一条症状。
class SymptomFormSheet extends StatefulWidget {
  const SymptomFormSheet({super.key, required this.date, this.initial});

  final DateTime date;
  final SymptomRecord? initial;

  @override
  State<SymptomFormSheet> createState() => _SymptomFormSheetState();
}

class _SymptomFormSheetState extends State<SymptomFormSheet> {
  late int _symptom = widget.initial?.symptom ?? 0;
  late int _severity = widget.initial?.severity ?? 0;
  late final TextEditingController _note =
      TextEditingController(text: widget.initial?.note ?? '');

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SheetScaffold(
      title: '记录症状',
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < SymptomKind.items.length; i++)
              ChoiceChip(
                label: Text(SymptomKind.items[i]),
                selected: _symptom == i,
                onSelected: (_) => setState(() => _symptom = i),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text('程度', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          segments: [
            for (var i = 0; i < SymptomSeverity.items.length; i++)
              ButtonSegment(value: i, label: Text(SymptomSeverity.items[i])),
          ],
          selected: {_severity},
          onSelectionChanged: (s) => setState(() => _severity = s.first),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _note,
          maxLines: 2,
          decoration: const InputDecoration(labelText: '备注（选填）'),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.pop(
              context,
              SymptomRecord(
                id: widget.initial?.id,
                date: widget.date,
                symptom: _symptom,
                severity: _severity,
                note: _note.text.trim().isEmpty ? null : _note.text.trim(),
              ),
            ),
            child: const Text('保存'),
          ),
        ),
      ],
    );
  }
}

/// 记录心情（一天一条）。
class MoodFormSheet extends StatefulWidget {
  const MoodFormSheet({super.key, required this.date, this.initial});

  final DateTime date;
  final MoodRecord? initial;

  @override
  State<MoodFormSheet> createState() => _MoodFormSheetState();
}

class _MoodFormSheetState extends State<MoodFormSheet> {
  static const _face = ['😣', '🙁', '😐', '🙂', '😄'];
  late int _score = widget.initial?.score ?? 3;
  late final Set<int> _emotions = {...?widget.initial?.emotions};
  late final TextEditingController _note =
      TextEditingController(text: widget.initial?.note ?? '');

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SheetScaffold(
      title: '记录心情',
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var s = 1; s <= 5; s++)
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _score = s),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _score == s
                        ? theme.colorScheme.primaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(_face[s - 1], style: const TextStyle(fontSize: 26)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < MoodEmotion.items.length; i++)
              FilterChip(
                label: Text(MoodEmotion.items[i]),
                selected: _emotions.contains(i),
                onSelected: (v) => setState(() {
                  if (v) {
                    _emotions.add(i);
                  } else {
                    _emotions.remove(i);
                  }
                }),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _note,
          maxLines: 2,
          decoration: const InputDecoration(labelText: '备注（选填）'),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.pop(
              context,
              MoodRecord(
                id: widget.initial?.id,
                date: widget.date,
                score: _score,
                emotions: _emotions.toList()..sort(),
                note: _note.text.trim().isEmpty ? null : _note.text.trim(),
              ),
            ),
            child: const Text('保存'),
          ),
        ),
      ],
    );
  }
}

/// 记录体重（一天一条）。
class WeightFormSheet extends StatefulWidget {
  const WeightFormSheet({super.key, required this.date, this.initial});

  final DateTime date;
  final WeightRecord? initial;

  @override
  State<WeightFormSheet> createState() => _WeightFormSheetState();
}

class _WeightFormSheetState extends State<WeightFormSheet> {
  late final TextEditingController _kg =
      TextEditingController(text: widget.initial?.kg.toString() ?? '');

  @override
  void dispose() {
    _kg.dispose();
    super.dispose();
  }

  double? _parse() {
    final v = double.tryParse(_kg.text.trim());
    if (v == null || v <= 0 || v > 300) return null;
    return v;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SheetScaffold(
      title: '记录体重',
      children: [
        TextField(
          controller: _kg,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: '体重（kg）', helperText: '例：52.5'),
        ),
        if (_parse() == null && _kg.text.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('请输入有效的体重（0–300 kg）',
                style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
          ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () {
              final kg = _parse();
              if (kg == null) return;
              Navigator.pop(
                context,
                WeightRecord(id: widget.initial?.id, date: widget.date, kg: kg),
              );
            },
            child: const Text('保存'),
          ),
        ),
      ],
    );
  }
}

/// 记录白带（一天一条）。
class DischargeFormSheet extends StatefulWidget {
  const DischargeFormSheet({super.key, required this.date, this.initial});

  final DateTime date;
  final DischargeRecord? initial;

  @override
  State<DischargeFormSheet> createState() => _DischargeFormSheetState();
}

class _DischargeFormSheetState extends State<DischargeFormSheet> {
  static const _groups = [
    (label: '正常', from: 0, to: 3),
    (label: '异常', from: 3, to: 7),
    (label: '建议关注', from: 7, to: 10),
  ];
  late int _status = widget.initial?.status ?? 0;
  late int _amount = widget.initial?.amount ?? 1;
  late int _smell = widget.initial?.smell ?? 0;
  late bool _itch = widget.initial?.itch ?? false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SheetScaffold(
      title: '记录白带',
      children: [
        for (final g in _groups) ...[
          Text(g.label, style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = g.from; i < g.to; i++)
                ChoiceChip(
                  label: Text(DischargeStatus.items[i]),
                  selected: _status == i,
                  onSelected: (_) => setState(() => _status = i),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(child: Text('量', style: theme.textTheme.bodyMedium)),
            SegmentedButton<int>(
              segments: [
                for (var i = 0; i < DischargeAmount.items.length; i++)
                  ButtonSegment(value: i, label: Text(DischargeAmount.items[i])),
              ],
              selected: {_amount},
              onSelectionChanged: (s) => setState(() => _amount = s.first),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: Text('气味', style: theme.textTheme.bodyMedium)),
            SegmentedButton<int>(
              segments: [
                for (var i = 0; i < DischargeSense.items.length; i++)
                  ButtonSegment(value: i, label: Text(DischargeSense.items[i])),
              ],
              selected: {_smell},
              onSelectionChanged: (s) => setState(() => _smell = s.first),
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('伴随瘙痒'),
          value: _itch,
          onChanged: (v) => setState(() => _itch = v),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.pop(
              context,
              DischargeRecord(
                id: widget.initial?.id,
                date: widget.date,
                status: _status,
                amount: _amount,
                smell: _smell,
                itch: _itch,
              ),
            ),
            child: const Text('保存'),
          ),
        ),
      ],
    );
  }
}

/// 写日记（一天可多篇；图片在后续版本接入）。
class DiaryFormSheet extends StatefulWidget {
  const DiaryFormSheet({super.key, required this.date, this.initial});

  final DateTime date;
  final DiaryEntry? initial;

  @override
  State<DiaryFormSheet> createState() => _DiaryFormSheetState();
}

class _DiaryFormSheetState extends State<DiaryFormSheet> {
  late final TextEditingController _content =
      TextEditingController(text: widget.initial?.content ?? '');

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: '写日记',
      children: [
        TextField(
          controller: _content,
          minLines: 4,
          maxLines: 10,
          decoration: const InputDecoration(
            labelText: '今天想记点什么…',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () {
              final text = _content.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(
                context,
                DiaryEntry(
                  id: widget.initial?.id,
                  date: widget.date,
                  content: text,
                  images: widget.initial?.images ?? const [],
                ),
              );
            },
            child: const Text('保存日记'),
          ),
        ),
      ],
    );
  }
}
