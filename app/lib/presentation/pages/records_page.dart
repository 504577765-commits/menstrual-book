import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/cycle.dart';
import '../providers.dart';
import '../theme/app_theme.dart';
import '../widgets/level_widgets.dart';
import '../widgets/record_sheets.dart';

class RecordsPage extends ConsumerWidget {
  const RecordsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    final cycles = state.cycles.reversed.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('记录')),
      body: cycles.isEmpty
          ? const _EmptyState()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              itemCount: cycles.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final cycle = cycles[index];
                final id = cycle.id;
                return _CycleTile(
                  cycle: cycle,
                  dayCount: id == null ? 0 : state.daysOf(id).length,
                  onEdit: () => _showEditSheet(context, ref, cycle),
                  onDelete: () => _confirmDelete(context, ref, cycle),
                );
              },
            ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Cycle cycle,
  ) async {
    final id = cycle.id;
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这条记录？'),
        content: const Text('删除后无法恢复（本应用不提供备份）。'),
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
    if (ok == true) {
      try {
        await ref.read(appStateProvider).deleteCycle(id);
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('已删除这条记录')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('删除失败：$e')));
        }
      }
    }
  }

  Future<void> _showEditSheet(
    BuildContext context,
    WidgetRef ref,
    Cycle cycle,
  ) async {
    final state = ref.read(appStateProvider);
    final ongoing = state.ongoingCycle;
    final others = state.cycles.where((c) => c.id != cycle.id).toList();

    final result = await Navigator.of(context).push<EditCycleResult>(
      sheetRoute(EditCycleSheet(
        cycle: cycle,
        today: state.today,
        others: others,
        // 只允许「当前这条」保持进行中，避免出现两条同时进行中的记录。
        allowOngoing: ongoing == null || ongoing.id == cycle.id,
      )),
    );

    if (result == null) return;
    try {
      await state.updateCycle(Cycle(
        id: cycle.id,
        startDate: result.start,
        endDate: result.end,
        overallFlow: result.flow,
        overallCramp: result.cramp,
        note: cycle.note,
      ));
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已保存修改')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存失败：$e')));
      }
    }
  }
}

class _CycleTile extends StatelessWidget {
  const _CycleTile({
    required this.cycle,
    required this.dayCount,
    required this.onEdit,
    required this.onDelete,
  });

  final Cycle cycle;
  final int dayCount;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String _fmt(DateTime d) => '${d.year}/${d.month.toString().padLeft(2, '0')}/'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final len = cycle.lengthInDays;

    return Dismissible(
      key: ValueKey('cycle-${cycle.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        ),
        child: Icon(
          Icons.delete_outline,
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
      child: Card(
        child: ListTile(
          onTap: onEdit,
          title: Text('${_fmt(cycle.startDate)} 起'),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 14,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  cycle.isOngoing ? '进行中 · 第 $dayCount 天' : '经期 $len 天',
                  style: theme.textTheme.bodySmall,
                ),
                FlowDrops(level: cycle.overallFlow, size: 13),
                CrampDots(level: cycle.overallCramp, size: 10),
                if (dayCount > 0)
                  Text('已填 $dayCount 天详情', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_note_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text('还没有记录', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '在首页点「经期来了」记一次，之后就能预测下一次了。',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
