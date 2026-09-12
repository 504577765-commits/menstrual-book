import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'presentation/pages/home_page.dart';
import 'presentation/pages/lock_gate.dart';
import 'presentation/pages/onboarding_page.dart';
import 'presentation/pages/records_page.dart';
import 'presentation/pages/settings_page.dart';
import 'presentation/pages/trends_page.dart';
import 'presentation/providers.dart';
import 'presentation/state/app_state.dart';
import 'presentation/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 提醒按本地时区调度。当前面向国内用户，显式设定时区；
  // 若时区数据异常则回退默认值，避免启动失败（非 UTC+8 用户提醒时间会偏移，
  // 后续版本改为读取设备时区）。
  try {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
  } catch (error) {
    debugPrint('时区初始化失败，使用默认时区：$error');
  }

  final container = ProviderContainer();
  await container.read(notificationServiceProvider).initialize();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const YuejingBenApp(),
    ),
  );
}

class YuejingBenApp extends ConsumerStatefulWidget {
  const YuejingBenApp({super.key});

  @override
  ConsumerState<YuejingBenApp> createState() => _YuejingBenAppState();
}

class _YuejingBenAppState extends ConsumerState<YuejingBenApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(appStateProvider).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);

    return MaterialApp(
      title: '月经本',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: switch (state.themeMode) {
        ThemeModeSetting.system => ThemeMode.system,
        ThemeModeSetting.light => ThemeMode.light,
        ThemeModeSetting.dark => ThemeMode.dark,
      },
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(state.fontScale.clamp(0.9, 1.6)),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: LockGate(
        child: state.onboardingDone ? const RootShell() : const OnboardingPage(),
      ),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  static const _pages = [
    HomePage(),
    RecordsPage(),
    TrendsPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: '记录',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: '趋势',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
