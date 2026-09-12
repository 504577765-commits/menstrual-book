library;

/// 六类日常记录（爱爱/症状/心情/体重/白带/日记）的实体与可选项常量。
///
/// 全部按「天」归属（date 为日历日，格式 YYYY-MM-DD，由仓储层负责格式化）。

/// 症状预置（顺序即存储索引，勿随意调整）。
class SymptomKind {
  static const List<String> items = [
    '腹痛', '腰酸', '乏力', '头痛', '恶心',
    '乳房胀痛', '情绪波动', '失眠', '食欲变化',
    '腹泻', '便秘', '发热', '眩晕',
  ];
}

/// 心情情绪词（多选）。
class MoodEmotion {
  static const List<String> items = [
    '开心', '放松', '平静', '烦躁', '焦虑', '低落', '疲惫', '生气',
  ];
}

/// 白带状态（顺序即存储索引）。
class DischargeStatus {
  static const List<String> items = [
    // 正常类
    '透明拉丝', '白色糊状', '蛋清样',
    // 异常类
    '黄色', '绿色', '带血丝', '褐黑色',
    // 病态类
    '豆腐渣', '泡沫状', '脓性',
  ];
}

/// 白带量。
class DischargeAmount {
  static const List<String> items = ['少', '正常', '多'];
}

/// 白带气味 / 瘙痒（0 无、1 轻度、2 明显）。
class DischargeSense {
  static const List<String> items = ['无', '轻度', '明显'];
}

/// 症状严重程度（0 轻、1 中、2 重）。
class SymptomSeverity {
  static const List<String> items = ['轻', '中', '重'];
}

/// 爱爱记录（一天可多条）。
class IntimacyRecord {
  const IntimacyRecord({
    this.id,
    required this.date,
    this.protected = false,
  });

  final int? id;
  final DateTime date;
  final bool protected;

  IntimacyRecord copyWith({int? id, DateTime? date, bool? protected}) =>
      IntimacyRecord(
        id: id ?? this.id,
        date: date ?? this.date,
        protected: protected ?? this.protected,
      );
}

/// 症状记录（一天可多条）。
class SymptomRecord {
  const SymptomRecord({
    this.id,
    required this.date,
    required this.symptom,
    this.severity = 0,
    this.note,
  });

  final int? id;
  final DateTime date;

  /// SymptomKind.items 的索引。
  final int symptom;

  /// SymptomSeverity 索引（0 轻、1 中、2 重）。
  final int severity;
  final String? note;

  SymptomRecord copyWith({
    int? id,
    DateTime? date,
    int? symptom,
    int? severity,
    Object? note = _sentinel,
  }) =>
      SymptomRecord(
        id: id ?? this.id,
        date: date ?? this.date,
        symptom: symptom ?? this.symptom,
        severity: severity ?? this.severity,
        note: identical(note, _sentinel) ? this.note : note as String?,
      );
}

/// 心情记录（一天一条，记录即覆盖）。
class MoodRecord {
  const MoodRecord({
    this.id,
    required this.date,
    required this.score,
    this.emotions = const [],
    this.note,
  });

  final int? id;
  final DateTime date;

  /// 1–5 档（1 很差 … 5 很好）。
  final int score;

  /// MoodEmotion.items 的索引集合。
  final List<int> emotions;
  final String? note;

  MoodRecord copyWith({
    int? id,
    DateTime? date,
    int? score,
    List<int>? emotions,
    Object? note = _sentinel,
  }) =>
      MoodRecord(
        id: id ?? this.id,
        date: date ?? this.date,
        score: score ?? this.score,
        emotions: emotions ?? this.emotions,
        note: identical(note, _sentinel) ? this.note : note as String?,
      );
}

/// 体重记录（一天一条）。
class WeightRecord {
  const WeightRecord({this.id, required this.date, required this.kg});

  final int? id;
  final DateTime date;
  final double kg;

  WeightRecord copyWith({int? id, DateTime? date, double? kg}) => WeightRecord(
        id: id ?? this.id,
        date: date ?? this.date,
        kg: kg ?? this.kg,
      );
}

/// 白带记录（一天一条）。
class DischargeRecord {
  const DischargeRecord({
    this.id,
    required this.date,
    required this.status,
    this.amount = 1,
    this.smell = 0,
    this.itch = false,
    this.note,
  });

  final int? id;
  final DateTime date;

  /// DischargeStatus.items 的索引。
  final int status;

  /// DischargeAmount 索引。
  final int amount;

  /// DischargeSense 索引（气味）。
  final int smell;

  /// 是否伴随瘙痒。
  final bool itch;
  final String? note;

  DischargeRecord copyWith({
    int? id,
    DateTime? date,
    int? status,
    int? amount,
    int? smell,
    bool? itch,
    Object? note = _sentinel,
  }) =>
      DischargeRecord(
        id: id ?? this.id,
        date: date ?? this.date,
        status: status ?? this.status,
        amount: amount ?? this.amount,
        smell: smell ?? this.smell,
        itch: itch ?? this.itch,
        note: identical(note, _sentinel) ? this.note : note as String?,
      );
}

/// 日记（一天可多篇）。
class DiaryEntry {
  const DiaryEntry({
    this.id,
    required this.date,
    required this.content,
    this.images = const [],
  });

  final int? id;
  final DateTime date;
  final String content;

  /// 图片本地路径列表（存应用私有目录）。
  final List<String> images;

  DiaryEntry copyWith({
    int? id,
    DateTime? date,
    String? content,
    List<String>? images,
  }) =>
      DiaryEntry(
        id: id ?? this.id,
        date: date ?? this.date,
        content: content ?? this.content,
        images: images ?? this.images,
      );
}

const Object _sentinel = Object();

/// 某一天的六类记录聚合（无记录项为空/mull）。
class DailyRecords {
  const DailyRecords({
    this.intimacies = const [],
    this.symptoms = const [],
    this.mood,
    this.weight,
    this.discharge,
    this.diaries = const [],
  });

  final List<IntimacyRecord> intimacies;
  final List<SymptomRecord> symptoms;
  final MoodRecord? mood;
  final WeightRecord? weight;
  final DischargeRecord? discharge;
  final List<DiaryEntry> diaries;

  bool get isEmpty =>
      intimacies.isEmpty &&
      symptoms.isEmpty &&
      mood == null &&
      weight == null &&
      discharge == null &&
      diaries.isEmpty;

  static const empty = DailyRecords();
}