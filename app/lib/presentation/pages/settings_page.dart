import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../providers.dart';
import '../state/app_state.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _SectionCard(
            title: '提醒',
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('经前提醒'),
                subtitle: Text('提前 ${state.reminders.prePeriodDays} 天'),
                value: state.reminders.prePeriod,
                onChanged: (v) =>
                    state.updateReminders(state.reminders.copyWith(prePeriod: v)),
              ),
              if (state.reminders.prePeriod)
                _StepperTile(
                  label: '提前天数',
                  value: state.reminders.prePeriodDays,
                  min: 1,
                  max: 7,
                  suffix: '天',
                  onChanged: (v) => state.updateReminders(
                    state.reminders.copyWith(prePeriodDays: v),
                  ),
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('经期当天提醒'),
                value: state.reminders.periodStart,
                onChanged: (v) =>
                    state.updateReminders(state.reminders.copyWith(periodStart: v)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('易孕窗口提醒'),
                subtitle: const Text('日历法估算，误差较大，仅供参考'),
                value: state.reminders.fertile,
                onChanged: (v) =>
                    state.updateReminders(state.reminders.copyWith(fertile: v)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('排卵日提醒'),
                subtitle: const Text('日历法估算，误差较大，仅供参考'),
                value: state.reminders.ovulation,
                onChanged: (v) =>
                    state.updateReminders(state.reminders.copyWith(ovulation: v)),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('提醒时间'),
                subtitle: Text(
                  '${state.reminders.hour.toString().padLeft(2, '0')}:'
                  '${state.reminders.minute.toString().padLeft(2, '0')}',
                ),
                trailing: const Icon(Icons.schedule),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(
                      hour: state.reminders.hour,
                      minute: state.reminders.minute,
                    ),
                  );
                  if (picked != null) {
                    await state.updateReminders(state.reminders.copyWith(
                      hour: picked.hour,
                      minute: picked.minute,
                    ));
                  }
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('免打扰时段'),
                subtitle: Text(
                  !state.reminders.dndEnabled
                      ? '关闭'
                      : state.reminders.dndStartHour == state.reminders.dndEndHour
                          ? '起止时间相同，未生效'
                          : '${state.reminders.dndStartHour}:00 至 '
                              '${state.reminders.dndEndHour}:00，落在其中的提醒会顺延',
                ),
                value: state.reminders.dndEnabled,
                onChanged: (v) => state
                    .updateReminders(state.reminders.copyWith(dndEnabled: v)),
              ),
              if (state.reminders.dndEnabled)
                Row(
                  children: [
                    Expanded(
                      child: _HourPicker(
                        label: '开始',
                        value: state.reminders.dndStartHour,
                        onChanged: (h) => state
                            .updateReminders(state.reminders.copyWith(dndStartHour: h)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _HourPicker(
                        label: '结束',
                        value: state.reminders.dndEndHour,
                        onChanged: (h) => state
                            .updateReminders(state.reminders.copyWith(dndEndHour: h)),
                      ),
                    ),
                  ],
                ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('提醒自检'),
                subtitle: const Text('检查通知、精确闹钟、电池优化是否会影响提醒'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ReminderSelfCheckPage()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: '安全与隐私',
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('应用锁'),
                subtitle: const Text('使用指纹 / 面容，不可用时回退手机锁屏密码'),
                value: state.lockEnabled,
                onChanged: (v) async {
                  if (!v) {
                    await state.setLockEnabled(false);
                    return;
                  }
                  // 开启前先做一次真实验证：若设备既没有生物识别、也没有锁屏凭据，
                  // 一旦开启用户将永远无法进入应用（数据被锁死）。
                  final ok = await ref
                      .read(lockServiceProvider)
                      .authenticate(reason: '验证身份以开启应用锁');
                  if (!context.mounted) return;
                  if (!ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          '验证未通过。请先在系统设置中录入指纹/面容或设置锁屏密码，'
                          '否则开启应用锁后将无法进入应用。',
                        ),
                      ),
                    );
                    return;
                  }
                  await state.setLockEnabled(true);
                },
              ),
              _SliderTile(
                label: '离开后台多久自动锁定',
                value: state.autoLockSeconds.toDouble(),
                min: 0,
                max: 120,
                suffix: '秒',
                onChanged: (v) => state.setAutoLockSeconds(v.round()),
              ),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.shield_outlined),
                title: Text('数据仅保存在本机'),
                subtitle: Text('不联网、不上传、无账号。请注意：移除手机锁屏密码可能导致数据无法解密。'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: '显示与无障碍',
            children: [
              _SliderTile(
                label: '字体大小',
                value: state.fontScale,
                min: 0.9,
                max: 1.4,
                suffix: '×',
                decimals: 1,
                onChanged: (v) => state.setFontScale(v),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('深色模式'),
                subtitle: Text(state.themeMode.label),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final next = switch (state.themeMode) {
                    ThemeModeSetting.system => ThemeModeSetting.light,
                    ThemeModeSetting.light => ThemeModeSetting.dark,
                    ThemeModeSetting.dark => ThemeModeSetting.system,
                  };
                  await state.setThemeMode(next);
                },
              ),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.visibility_outlined),
                title: Text('色弱友好'),
                subtitle: Text('流量与痛经均以图标数量 + 文字双重编码，不依赖颜色区分'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _SectionCard(
            title: '关于',
            children: [
              _VersionTile(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('免责声明'),
                subtitle: Text('本应用用于个人周期记录与推算，不提供医疗诊断或用药建议。'
                    '预测与异常提示均基于历史数据估算，如有健康疑虑请咨询专业医生。'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 运行时读取 pubspec.yaml 中的版本号（单一来源）并展示。
class _VersionTile extends StatefulWidget {
  const _VersionTile();

  @override
  State<_VersionTile> createState() => _VersionTileState();
}

class _VersionTileState extends State<_VersionTile> {
  String _version = '…';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) {
        setState(() => _version = '${info.version}+${info.buildNumber}');
      }
    }).catchError((Object _) {
      // 读不到时保持占位，不影响页面其它功能。
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('版本'),
      trailing: Text(_version),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...children,
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _StepperTile extends StatelessWidget {
  const _StepperTile({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.suffix,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final String suffix;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          IconButton(
            tooltip: '减少',
            onPressed: value > min ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Text('$value$suffix', style: theme.textTheme.labelLarge),
          IconButton(
            tooltip: '增加',
            onPressed: value < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }
}

class _HourPicker extends StatelessWidget {
  const _HourPicker({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(width: 8),
        DropdownButton<int>(
          value: value,
          underline: const SizedBox.shrink(),
          items: [
            for (var h = 0; h < 24; h++)
              DropdownMenuItem(value: h, child: Text('$h:00')),
          ],
          onChanged: (h) {
            if (h != null) onChanged(h);
          },
        ),
      ],
    );
  }
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.suffix,
    required this.onChanged,
    this.decimals = 0,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String suffix;
  final int decimals;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
            Text(
              '${value.toStringAsFixed(decimals)}$suffix',
              style: theme.textTheme.labelLarge,
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: ((max - min) * (decimals == 0 ? 1 : 10)).round(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// 提醒自检页：逐项检测三项关键权限并给出修复入口。
class ReminderSelfCheckPage extends ConsumerStatefulWidget {
  const ReminderSelfCheckPage({super.key});

  @override
  ConsumerState<ReminderSelfCheckPage> createState() => _ReminderSelfCheckPageState();
}

class _ReminderSelfCheckPageState extends ConsumerState<ReminderSelfCheckPage> {
  bool? _notifications;
  bool? _exactAlarm;
  bool? _battery;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final service = ref.read(notificationServiceProvider);
    final results = await Future.wait([
      service.hasNotificationPermission(),
      service.hasExactAlarmPermission(),
      service.hasIgnoreBatteryOptimizations(),
    ]);
    if (!mounted) return;
    setState(() {
      _notifications = results[0];
      _exactAlarm = results[1];
      _battery = results[2];
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.read(notificationServiceProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('提醒自检')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('只要有一项未开启，提醒就可能不响。'),
          const SizedBox(height: 16),
          _CheckTile(
            title: '通知权限',
            ok: _notifications,
            onFix: () async {
              await service.requestNotificationPermission();
              await _check();
            },
          ),
          _CheckTile(
            title: '精确闹钟权限',
            ok: _exactAlarm,
            onFix: () async {
              await service.requestExactAlarmPermission();
              await _check();
            },
          ),
          _CheckTile(
            title: '忽略电池优化',
            ok: _battery,
            onFix: () async {
              await service.requestIgnoreBatteryOptimizations();
              await _check();
            },
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _check, child: const Text('重新检测')),
        ],
      ),
    );
  }
}

class _CheckTile extends StatelessWidget {
  const _CheckTile({required this.title, required this.ok, required this.onFix});

  final String title;
  final bool? ok;
  final Future<void> Function() onFix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = ok == null ? '检测中…' : (ok! ? '已开启' : '未开启');
    final color = ok == null
        ? theme.colorScheme.outline
        : (ok! ? theme.colorScheme.primary : theme.colorScheme.error);

    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: Text(status, style: TextStyle(color: color)),
        trailing: ok == true
            ? const Icon(Icons.check_circle_outline)
            : FilledButton.tonal(onPressed: onFix, child: const Text('去开启')),
      ),
    );
  }
}
