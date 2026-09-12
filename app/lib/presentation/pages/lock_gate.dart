import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// 应用锁栅栏：启动与「从后台回到前台超过阈值」时要求验证。
///
/// 仅使用生物识别，不可用时由系统自动回退到手机锁屏凭据；
/// 不设独立 App 密码，因此不存在「忘记密码导致数据永久锁死」的问题。
class LockGate extends ConsumerStatefulWidget {
  const LockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LockGate> createState() => _LockGateState();
}

class _LockGateState extends ConsumerState<LockGate> with WidgetsBindingObserver {
  bool _unlocked = false;
  bool _authenticating = false;
  bool _autoPrompted = false;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final appState = ref.read(appStateProvider);
    if (!appState.lockEnabled) return;

    // 验证过程中，系统生物识别弹窗自身会引起 paused/resumed，
    // 必须忽略，否则会陷入「验证 → 暂停 → 恢复 → 再验证」的循环。
    if (_authenticating) {
      _pausedAt = null;
      return;
    }

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _pausedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final pausedAt = _pausedAt;
      _pausedAt = null;
      if (pausedAt == null) return;
      final elapsed = DateTime.now().difference(pausedAt).inSeconds;
      // 用 > 而非 >=：阈值设为 0 时表示「离开即锁」，但不应把 0 秒的瞬时切换也算进去。
      if (elapsed > appState.autoLockSeconds) {
        setState(() => _unlocked = false);
        _authenticate();
      }
    }
  }

  Future<void> _authenticate() async {
    if (_authenticating) return;
    setState(() => _authenticating = true);

    final lock = ref.read(lockServiceProvider);
    final ok = await lock.authenticate(reason: '解锁月经本');

    if (!mounted) return;
    setState(() {
      _authenticating = false;
      if (ok) _unlocked = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);

    if (!appState.isReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (appState.hasLoadError) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text('无法打开本地数据', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  appState.loadError ?? '',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => ref.read(appStateProvider).load(),
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!appState.lockEnabled) return widget.child;

    if (_unlocked) return widget.child;

    if (!_autoPrompted) {
      _autoPrompted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _authenticate();
      });
    }

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text('月经本已锁定', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                '使用指纹 / 面容解锁，不可用时将回退到手机锁屏密码。',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _authenticating ? null : _authenticate,
                child: Text(_authenticating ? '验证中…' : '解锁'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
