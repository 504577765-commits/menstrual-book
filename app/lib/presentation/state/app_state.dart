// 注：字段为私有（_xxx），命名参数不能以下划线开头，因此无法使用 this._xxx 初始化形参。
// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

import '../../data/repositories/cycle_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/entities/cycle.dart';
import '../../domain/entities/cycle_day.dart';
import '../../domain/prediction/anomaly.dart';
import '../../domain/prediction/prediction_engine.dart';
import '../../domain/prediction/reminder_plan.dart';
import '../../domain/stats/cycle_stats.dart';
import '../../domain/validation/cycle_validation.dart';
import '../../services/notification_service.dart';

/// 全局应用状态。持有全部记录 + 设置，并负责派生预测/异常/统计与提醒调度。
class AppState extends ChangeNotifier {
  AppState({
    required CycleRepository cycleRepo,
    required SettingsRepository settingsRepo,
    required NotificationService notifications,
    DateTime Function()? clock,
  })  : _cycleRepo = cycleRepo,
        _settingsRepo = settingsRepo,
        _notifications = notifications,
        _clock = clock ?? DateTime.now;

  final CycleRepository _cycleRepo;
  final SettingsRepository _settingsRepo;
  final NotificationService _notifications;
  final DateTime Function() _clock;

  static const _engine = PredictionEngine();
  static const _anomalies = AnomalyEvaluator();
  static const _stats = CycleStatsCalculator();

  bool _ready = false;
  bool get isReady => _ready;

  String? _loadError;

  /// 启动期错误信息（非 null 表示加载失败，UI 应给出重试入口）。
  String? get loadError => _loadError;
  bool get hasLoadError => _loadError != null;

  List<Cycle> _cycles = const [];
  List<Cycle> get cycles => List.unmodifiable(_cycles);

  final Map<int, List<CycleDay>> _days = {};
  List<CycleDay> daysOf(int cycleId) => _days[cycleId] ?? const [];

  ReminderSettings _reminders = const ReminderSettings();
  ReminderSettings get reminders => _reminders;

  bool _onboardingDone = false;
  bool get onboardingDone => _onboardingDone;

  int _defaultCycleLen = 28;
  int get defaultCycleLen => _defaultCycleLen;

  int _defaultPeriodLen = 5;
  int get defaultPeriodLen => _defaultPeriodLen;

  DateTime? _lastKnownStart;
  DateTime? get lastKnownStart => _lastKnownStart;

  bool _lockEnabled = false;
  bool get lockEnabled => _lockEnabled;

  int _autoLockSeconds = 30;
  int get autoLockSeconds => _autoLockSeconds;

  double _fontScale = 1.0;
  double get fontScale => _fontScale;

  ThemeModeSetting _themeMode = ThemeModeSetting.system;
  ThemeModeSetting get themeMode => _themeMode;

  DateTime get today => _clock();

  Cycle? get ongoingCycle {
    Cycle? found;
    for (final c in _cycles) {
      if (c.isOngoing && (found == null || c.startDate.isAfter(found.startDate))) {
        found = c;
      }
    }
    return found;
  }

  /// 两段式预测结果。
  PredictionResult get prediction => _engine.predict(PredictionInput(
        cycles: _cycles,
        today: today,
        defaultCycleLen: _defaultCycleLen,
        defaultPeriodLen: _defaultPeriodLen,
        lastKnownStart: _lastKnownStart,
      ));

  /// 异常提示。冷启动阶段（完整周期不足 3 个）不做判定：
  /// 此时平均值本身不可靠，会把天生周期偏长/偏短的正常用户误伤。
  List<Anomaly> get anomalies {
    final p = prediction;
    if (p.sampleCount < 3) return const [];
    return _anomalies.evaluate(cycles: _cycles, avgCycleLen: p.avgCycleLen);
  }

  CycleStats get stats => _stats.compute(cycles: _cycles, today: today);

  Future<void> load() async {
    try {
      _onboardingDone = await _settingsRepo.getBool(SettingKeys.onboardingDone);
      _defaultCycleLen =
          await _settingsRepo.getInt(SettingKeys.defaultCycleLen, fallback: 28);
      _defaultPeriodLen =
          await _settingsRepo.getInt(SettingKeys.defaultPeriodLen, fallback: 5);
      _lockEnabled = await _settingsRepo.getBool(SettingKeys.lockEnabled);
      _autoLockSeconds =
          await _settingsRepo.getInt(SettingKeys.autoLockSeconds, fallback: 30);
      _fontScale = await _settingsRepo.getDouble(SettingKeys.fontScale, fallback: 1.0);
      _themeMode = ThemeModeSetting.fromName(
        await _settingsRepo.raw(SettingKeys.darkMode),
      );

      final lastStart = await _settingsRepo.raw(SettingKeys.lastKnownStart);
      _lastKnownStart = lastStart == null ? null : DateTime.tryParse(lastStart);

      _reminders = ReminderSettings(
        prePeriod:
            await _settingsRepo.getBool(SettingKeys.remindPrePeriod, fallback: true),
        prePeriodDays:
            await _settingsRepo.getInt(SettingKeys.remindPrePeriodDays, fallback: 2),
        periodStart:
            await _settingsRepo.getBool(SettingKeys.remindPeriodStart, fallback: true),
        fertile:
            await _settingsRepo.getBool(SettingKeys.remindFertile, fallback: true),
        ovulation:
            await _settingsRepo.getBool(SettingKeys.remindOvulation, fallback: true),
        hour: await _settingsRepo.getInt(SettingKeys.remindHour, fallback: 9),
        minute: await _settingsRepo.getInt(SettingKeys.remindMinute, fallback: 0),
        dndEnabled:
            await _settingsRepo.getBool(SettingKeys.dndEnabled, fallback: false),
        dndStartHour:
            await _settingsRepo.getInt(SettingKeys.dndStartHour, fallback: 22),
        dndEndHour: await _settingsRepo.getInt(SettingKeys.dndEndHour, fallback: 8),
      );

      await _reloadCycles();
      _loadError = null;
    } catch (error) {
      // 最常见原因：数据库口令保存在 Keystore 中，用户移除手机锁屏凭据后无法解密。
      _loadError = '读取本地数据失败：$error\n'
          '若你近期移除了手机锁屏密码 / 指纹，原有加密数据将无法解密。';
    }

    // 启动时重排一次提醒：放置较久后预测可能已变为「已推迟」，
    // 需要据此刷新提醒内容。失败不应影响应用可用性，因此单独兜底。
    try {
      await _rescheduleReminders();
    } catch (error) {
      debugPrint('重排提醒失败：$error');
    }

    _ready = true;
    notifyListeners();
  }

  Future<void> _reloadCycles() async {
    _cycles = await _cycleRepo.allCycles();
    _days.clear();
    for (final c in _cycles) {
      final id = c.id;
      if (id == null) continue;
      _days[id] = await _cycleRepo.daysOfCycle(id);
    }
  }

  Future<void> completeOnboarding({
    required DateTime? lastStart,
    required int cycleLen,
    required int periodLen,
  }) async {
    _lastKnownStart = lastStart;
    _defaultCycleLen = cycleLen;
    _defaultPeriodLen = periodLen;
    _onboardingDone = true;

    await _settingsRepo.setBool(SettingKeys.onboardingDone, true);
    await _settingsRepo.setInt(SettingKeys.defaultCycleLen, cycleLen);
    await _settingsRepo.setInt(SettingKeys.defaultPeriodLen, periodLen);
    if (lastStart != null) {
      await _settingsRepo.setRaw(
        SettingKeys.lastKnownStart,
        lastStart.toIso8601String(),
      );
    }
    await _rescheduleReminders();
    notifyListeners();
  }

  Future<void> setDefaultCycleLen(int value) async {
    _defaultCycleLen = value.clamp(21, 35);
    await _settingsRepo.setInt(SettingKeys.defaultCycleLen, _defaultCycleLen);
    await _rescheduleReminders();
    notifyListeners();
  }

  Future<void> setDefaultPeriodLen(int value) async {
    _defaultPeriodLen = value.clamp(2, 8);
    await _settingsRepo.setInt(SettingKeys.defaultPeriodLen, _defaultPeriodLen);
    await _rescheduleReminders();
    notifyListeners();
  }

  /// 记录一次经期。
  ///
  /// [ongoing] = true：今天开始、尚未结束，endDate 留空；
  /// [ongoing] = false：补录历史日期，[endDate] 缺省时记为一天的完整周期，
  /// 避免出现「开始于很久以前却仍在进行中」的畸形数据。
  ///
  /// 返回 null 表示成功；否则返回可直接展示给用户的中文提示。
  Future<String?> startPeriod({
    required DateTime startDate,
    required int overallFlow,
    required int overallCramp,
    bool ongoing = true,
    DateTime? endDate,
  }) async {
    if (ongoing && ongoingCycle != null) {
      return '已经有一次进行中的经期了，请先点「经期结束」。';
    }

    // 统一校验：不得与已有记录重叠（开始日选择器允许选历史日期，必须拦住）。
    final end = ongoing ? null : (endDate ?? startDate);
    final error = validateCycleRange(
      cycles: _cycles,
      start: startDate,
      end: end,
      today: _clock(),
      allowOngoing: ongoing,
    );
    if (error != null) return error;

    await _cycleRepo.insertCycle(Cycle(
      startDate: startDate,
      endDate: end,
      overallFlow: overallFlow,
      overallCramp: overallCramp,
    ));
    await _reloadCycles();
    await _rescheduleReminders();
    notifyListeners();
    return null;
  }

  /// 结束当前进行中的经期。
  Future<void> endPeriod(DateTime endDate) async {
    final ongoing = ongoingCycle;
    if (ongoing == null) return;
    final safeEnd = endDate.isBefore(ongoing.startDate) ? ongoing.startDate : endDate;
    await _cycleRepo.updateCycle(ongoing.copyWith(endDate: safeEnd));
    await _reloadCycles();
    await _rescheduleReminders();
    notifyListeners();
  }

  Future<void> updateCycle(Cycle cycle) async {
    await _cycleRepo.updateCycle(cycle);
    await _reloadCycles();
    await _rescheduleReminders();
    notifyListeners();
  }

  Future<void> deleteCycle(int id) async {
    await _cycleRepo.deleteCycle(id);
    await _reloadCycles();
    await _rescheduleReminders();
    notifyListeners();
  }

  /// 写入/清空某天的流量与痛经（选填）。
  Future<void> saveDay({
    required Cycle cycle,
    required DateTime date,
    int? flow,
    int? cramp,
  }) async {
    final cycleId = cycle.id;
    if (cycleId == null) return;

    if (flow == null && cramp == null) {
      final existing = (_days[cycleId] ?? const <CycleDay>[])
          .where((d) => _sameDay(d.date, date))
          .toList();
      for (final d in existing) {
        if (d.id != null) await _cycleRepo.deleteDay(d.id!);
      }
    } else {
      await _cycleRepo.upsertDay(CycleDay(
        cycleId: cycleId,
        date: date,
        dayIndex: CycleDay.indexOf(cycle.startDate, date),
        flowLevel: flow,
        crampLevel: cramp,
      ));
    }
    await _reloadCycles();
    notifyListeners();
  }

  Future<void> updateReminders(ReminderSettings value) async {
    _reminders = value;
    await _settingsRepo.setBool(SettingKeys.remindPrePeriod, value.prePeriod);
    await _settingsRepo.setInt(SettingKeys.remindPrePeriodDays, value.prePeriodDays);
    await _settingsRepo.setBool(SettingKeys.remindPeriodStart, value.periodStart);
    await _settingsRepo.setBool(SettingKeys.remindFertile, value.fertile);
    await _settingsRepo.setBool(SettingKeys.remindOvulation, value.ovulation);
    await _settingsRepo.setInt(SettingKeys.remindHour, value.hour);
    await _settingsRepo.setInt(SettingKeys.remindMinute, value.minute);
    await _settingsRepo.setBool(SettingKeys.dndEnabled, value.dndEnabled);
    await _settingsRepo.setInt(SettingKeys.dndStartHour, value.dndStartHour);
    await _settingsRepo.setInt(SettingKeys.dndEndHour, value.dndEndHour);
    await _rescheduleReminders();
    notifyListeners();
  }

  Future<void> setLockEnabled(bool value) async {
    _lockEnabled = value;
    await _settingsRepo.setBool(SettingKeys.lockEnabled, value);
    notifyListeners();
  }

  Future<void> setAutoLockSeconds(int value) async {
    _autoLockSeconds = value;
    await _settingsRepo.setInt(SettingKeys.autoLockSeconds, value);
    notifyListeners();
  }

  Future<void> setFontScale(double value) async {
    _fontScale = value;
    await _settingsRepo.setDouble(SettingKeys.fontScale, value);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeModeSetting value) async {
    _themeMode = value;
    await _settingsRepo.setRaw(SettingKeys.darkMode, value.name);
    notifyListeners();
  }

  /// 重排全部提醒。任何数据变化后都必须调用，保证提醒与预测一致。
  ///
  /// 具体"排哪些、什么时候排"由领域层的纯函数 [buildReminderPlan] 决定，
  /// 这里只负责取消旧的与下发新的。
  Future<void> _rescheduleReminders() async {
    await _notifications.cancelAll();

    final plan = buildReminderPlan(
      prediction: prediction,
      settings: _reminders,
      now: _clock(),
    );

    for (final item in plan) {
      await _notifications.schedule(
        id: NotificationService.idFor(item.kind),
        title: item.title,
        body: item.body,
        when: item.when,
      );
    }
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

enum ThemeModeSetting {
  system,
  light,
  dark;

  static ThemeModeSetting fromName(String? name) {
    switch (name) {
      case 'light':
        return ThemeModeSetting.light;
      case 'dark':
        return ThemeModeSetting.dark;
      default:
        return ThemeModeSetting.system;
    }
  }

  String get label => switch (this) {
        ThemeModeSetting.system => '跟随系统',
        ThemeModeSetting.light => '浅色',
        ThemeModeSetting.dark => '深色',
      };
}
