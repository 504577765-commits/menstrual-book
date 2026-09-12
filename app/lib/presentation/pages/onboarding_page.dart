import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// 首启引导：3 步认知 + 周期参数填写。
/// 填写上次经期与周期长度后，首月即可给出可用预测（而不是默认 28 天的瞎猜）。
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _controller = PageController();
  int _page = 0;

  DateTime? _lastStart;
  int _cycleLen = 28;
  int _periodLen = 5;
  bool _finishing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  const _IntroSlide(
                    icon: Icons.event_note_outlined,
                    title: '月经本',
                    body: '不用天天打卡。经期来和走时各记一次，就够了。',
                  ),
                  const _IntroSlide(
                    icon: Icons.auto_graph_outlined,
                    title: '记一次，就够准',
                    body: 'App 会根据你的历史记录推算下一次，并提前提醒你。\n'
                        '记录越多，预测越准。',
                  ),
                  const _IntroSlide(
                    icon: Icons.lock_outline,
                    title: '数据只在你手机里',
                    body: '不联网、不上传、无账号，数据库整库加密。\n'
                        '可用指纹 / 面容加锁。',
                  ),
                  _SetupSlide(
                    lastStart: _lastStart,
                    cycleLen: _cycleLen,
                    periodLen: _periodLen,
                    onPickDate: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => _lastStart = picked);
                    },
                    onCycleChanged: (v) => setState(() => _cycleLen = v.round()),
                    onPeriodChanged: (v) => setState(() => _periodLen = v.round()),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < 4; i++)
                        Container(
                          width: i == _page ? 18 : 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: i == _page
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_page < 3)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => _controller.nextPage(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOut,
                        ),
                        child: const Text('下一步'),
                      ),
                    )
                  else ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _finish,
                        child: const Text('开始使用'),
                      ),
                    ),
                    TextButton(
                      onPressed: _finish,
                      child: const Text('跳过，稍后再填'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);

    // 先申请通知权限：completeOnboarding 会把根页面切到主界面并销毁本页，
    // 之后再访问 ref 是不安全的，因此顺序不能颠倒。
    await ref.read(notificationServiceProvider).requestNotificationPermission();

    await ref.read(appStateProvider).completeOnboarding(
          lastStart: _lastStart,
          cycleLen: _cycleLen,
          periodLen: _periodLen,
        );
  }
}

class _IntroSlide extends StatelessWidget {
  const _IntroSlide({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 24),
          Text(title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 16),
          Text(body, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _SetupSlide extends StatelessWidget {
  const _SetupSlide({
    required this.lastStart,
    required this.cycleLen,
    required this.periodLen,
    required this.onPickDate,
    required this.onCycleChanged,
    required this.onPeriodChanged,
  });

  final DateTime? lastStart;
  final int cycleLen;
  final int periodLen;
  final VoidCallback onPickDate;
  final ValueChanged<double> onCycleChanged;
  final ValueChanged<double> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('最后一步', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          '填两个数字，首次预测就能贴近你的实际情况。',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        Card(
          child: ListTile(
            title: const Text('上次经期开始日'),
            subtitle: Text(
              lastStart == null
                  ? '未填写（可跳过）'
                  : '${lastStart!.year} 年 ${lastStart!.month} 月 ${lastStart!.day} 日',
            ),
            trailing: const Icon(Icons.edit_calendar_outlined),
            onTap: onPickDate,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: Text('通常周期长度', style: theme.textTheme.bodyMedium)),
            Text('$cycleLen 天', style: theme.textTheme.labelLarge),
          ],
        ),
        Slider(
          value: cycleLen.toDouble(),
          min: 21,
          max: 35,
          divisions: 14,
          onChanged: onCycleChanged,
        ),
        Row(
          children: [
            Expanded(child: Text('通常经期天数', style: theme.textTheme.bodyMedium)),
            Text('$periodLen 天', style: theme.textTheme.labelLarge),
          ],
        ),
        Slider(
          value: periodLen.toDouble(),
          min: 2,
          max: 8,
          divisions: 6,
          onChanged: onPeriodChanged,
        ),
      ],
    );
  }
}
