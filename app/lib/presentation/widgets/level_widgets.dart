import 'package:flutter/material.dart';

import '../../domain/entities/cycle.dart';

/// 流量强度：水滴数量三重编码（图标数量 + 数字 + 文字），
/// 不单纯依赖颜色，保证色弱用户可辨。
class FlowDrops extends StatelessWidget {
  const FlowDrops({
    super.key,
    required this.level,
    this.size = 16,
    this.showLabel = true,
  });

  final int level;
  final double size;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final safe = level.clamp(0, 2);
    final count = safe + 1;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          Padding(
            padding: EdgeInsets.only(right: i == count - 1 ? 6 : 2),
            child: Icon(
              Icons.water_drop,
              size: size,
              color: scheme.primary.withValues(alpha: 0.55 + 0.15 * i),
            ),
          ),
        if (showLabel)
          Flexible(
            child: Text(
              '${FlowLevel.labels[safe]}（$count）',
              style: Theme.of(context).textTheme.labelMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}

/// 痛经程度：圆点数量编码（0–3），同样不依赖颜色。
class CrampDots extends StatelessWidget {
  const CrampDots({
    super.key,
    required this.level,
    this.size = 12,
    this.showLabel = true,
  });

  final int level;
  final double size;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final safe = level.clamp(0, 3);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (safe == 0)
          Icon(Icons.remove_circle_outline, size: size + 2, color: scheme.outline)
        else
          for (var i = 0; i < safe; i++)
            Padding(
              padding: EdgeInsets.only(right: i == safe - 1 ? 6 : 3),
              child: Icon(Icons.circle, size: size, color: scheme.secondary),
            ),
        if (showLabel)
          Flexible(
            child: Text(
              CrampLevel.labels[safe],
              style: Theme.of(context).textTheme.labelMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}

/// 流量三档选择器。
class FlowSelector extends StatelessWidget {
  const FlowSelector({super.key, required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < 3; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == 2 ? 0 : 8),
              child: _ChoiceTile(
                selected: value == i,
                onTap: () => onChanged(i),
                label: FlowLevel.labels[i],
                content: FlowDrops(level: i, showLabel: false, size: 14),
              ),
            ),
          ),
      ],
    );
  }
}

/// 痛经四档选择器。
class CrampSelector extends StatelessWidget {
  const CrampSelector({super.key, required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < 4; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == 3 ? 0 : 8),
              child: _ChoiceTile(
                selected: value == i,
                onTap: () => onChanged(i),
                label: CrampLevel.labels[i],
                content: CrampDots(level: i, showLabel: false),
              ),
            ),
          ),
      ],
    );
  }
}

/// 自适应高度的选项块：不写死高度，避免大字号下 RenderFlex 溢出。
class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.selected,
    required this.onTap,
    required this.label,
    required this.content,
  });

  final bool selected;
  final VoidCallback onTap;
  final String label;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minHeight: 68),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected ? scheme.primaryContainer : scheme.surfaceContainerHighest,
          border: Border.all(
            color: selected ? scheme.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 20, child: Center(child: content)),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
