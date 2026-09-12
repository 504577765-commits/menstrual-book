import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../domain/entities/daily_record.dart';
import '../database/app_database.dart';

/// 六类日常记录的仓储。全部按「日历日」存储与查询（YYYY-MM-DD）。
class DailyRecordRepository {
  DailyRecordRepository(this._db);

  final AppDatabase _db;

  static String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  // ---------- 爱爱 ----------
  Future<List<IntimacyRecord>> intimaciesOn(DateTime date) async {
    final db = await _db.database;
    final rows = await db.query(
      AppDatabase.tableIntimacy,
      where: 'date = ?',
      whereArgs: [_key(date)],
      orderBy: 'id ASC',
    );
    return rows.map((r) => _intimacyFromMap(r)).toList();
  }

  Future<List<IntimacyRecord>> allIntimacies() async {
    final db = await _db.database;
    final rows = await db.query(AppDatabase.tableIntimacy, orderBy: 'date ASC, id ASC');
    return rows.map((r) => _intimacyFromMap(r)).toList();
  }

  Future<int> insertIntimacy(IntimacyRecord r) async {
    final db = await _db.database;
    final now = DateTime.now().toIso8601String();
    return db.insert(AppDatabase.tableIntimacy, {
      'date': _key(r.date),
      'protected': r.protected ? 1 : 0,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<int> updateIntimacy(IntimacyRecord r) async {
    if (r.id == null) return 0;
    final db = await _db.database;
    return db.update(
      AppDatabase.tableIntimacy,
      {
        'protected': r.protected ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [r.id],
    );
  }

  Future<int> deleteIntimacy(int id) async {
    final db = await _db.database;
    return db.delete(AppDatabase.tableIntimacy, where: 'id = ?', whereArgs: [id]);
  }

  // ---------- 症状 ----------
  Future<List<SymptomRecord>> symptomsOn(DateTime date) async {
    final db = await _db.database;
    final rows = await db.query(
      AppDatabase.tableSymptom,
      where: 'date = ?',
      whereArgs: [_key(date)],
      orderBy: 'id ASC',
    );
    return rows.map((r) => _symptomFromMap(r)).toList();
  }

  Future<List<SymptomRecord>> allSymptoms() async {
    final db = await _db.database;
    final rows = await db.query(AppDatabase.tableSymptom, orderBy: 'date ASC, id ASC');
    return rows.map((r) => _symptomFromMap(r)).toList();
  }

  Future<int> insertSymptom(SymptomRecord r) async {
    final db = await _db.database;
    return db.insert(AppDatabase.tableSymptom, {
      'date': _key(r.date),
      'symptom': r.symptom,
      'severity': r.severity,
      'note': r.note,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> updateSymptom(SymptomRecord r) async {
    if (r.id == null) return 0;
    final db = await _db.database;
    return db.update(
      AppDatabase.tableSymptom,
      {
        'symptom': r.symptom,
        'severity': r.severity,
        'note': r.note,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [r.id],
    );
  }

  Future<int> deleteSymptom(int id) async {
    final db = await _db.database;
    return db.delete(AppDatabase.tableSymptom, where: 'id = ?', whereArgs: [id]);
  }

  // ---------- 心情 ----------
  Future<MoodRecord?> moodOn(DateTime date) async {
    final db = await _db.database;
    final rows = await db.query(
      AppDatabase.tableMood,
      where: 'date = ?',
      whereArgs: [_key(date)],
      limit: 1,
    );
    return rows.isEmpty ? null : _moodFromMap(rows.first);
  }

  Future<List<MoodRecord>> allMoods() async {
    final db = await _db.database;
    final rows = await db.query(AppDatabase.tableMood, orderBy: 'date ASC');
    return rows.map((r) => _moodFromMap(r)).toList();
  }

  /// 一天一条：有则更新，无则插入。
  Future<void> upsertMood(MoodRecord r) async {
    final db = await _db.database;
    final dateKey = _key(r.date);
    final existing = await db.query(
      AppDatabase.tableMood,
      columns: ['id'],
      where: 'date = ?',
      whereArgs: [dateKey],
      limit: 1,
    );
    final now = DateTime.now().toIso8601String();
    if (existing.isNotEmpty) {
      await db.update(
        AppDatabase.tableMood,
        {
          'score': r.score,
          'emotions': jsonEncode(r.emotions),
          'note': r.note,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    } else {
      await db.insert(AppDatabase.tableMood, {
        'date': dateKey,
        'score': r.score,
        'emotions': jsonEncode(r.emotions),
        'note': r.note,
        'updated_at': now,
      });
    }
  }

  // ---------- 心情（删除按天） ----------
  Future<int> deleteMoodByDate(DateTime date) async {
    final db = await _db.database;
    return db.delete(
      AppDatabase.tableMood,
      where: 'date = ?',
      whereArgs: [_key(date)],
    );
  }

  // ---------- 体重 ----------
  Future<WeightRecord?> weightOn(DateTime date) async {
    final db = await _db.database;
    final rows = await db.query(
      AppDatabase.tableWeight,
      where: 'date = ?',
      whereArgs: [_key(date)],
      limit: 1,
    );
    return rows.isEmpty ? null : _weightFromMap(rows.first);
  }

  Future<List<WeightRecord>> allWeights() async {
    final db = await _db.database;
    final rows = await db.query(AppDatabase.tableWeight, orderBy: 'date ASC');
    return rows.map((r) => _weightFromMap(r)).toList();
  }

  Future<void> upsertWeight(WeightRecord r) async {
    final db = await _db.database;
    final dateKey = _key(r.date);
    final existing = await db.query(
      AppDatabase.tableWeight,
      columns: ['id'],
      where: 'date = ?',
      whereArgs: [dateKey],
      limit: 1,
    );
    final now = DateTime.now().toIso8601String();
    if (existing.isNotEmpty) {
      await db.update(
        AppDatabase.tableWeight,
        {'kg': r.kg, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    } else {
      await db.insert(AppDatabase.tableWeight, {
        'date': dateKey,
        'kg': r.kg,
        'updated_at': now,
      });
    }
  }

  // ---------- 体重（删除按天） ----------
  Future<int> deleteWeightByDate(DateTime date) async {
    final db = await _db.database;
    return db.delete(
      AppDatabase.tableWeight,
      where: 'date = ?',
      whereArgs: [_key(date)],
    );
  }

  // ---------- 白带 ----------
  Future<DischargeRecord?> dischargeOn(DateTime date) async {
    final db = await _db.database;
    final rows = await db.query(
      AppDatabase.tableDischarge,
      where: 'date = ?',
      whereArgs: [_key(date)],
      limit: 1,
    );
    return rows.isEmpty ? null : _dischargeFromMap(rows.first);
  }

  Future<List<DischargeRecord>> allDischarges() async {
    final db = await _db.database;
    final rows = await db.query(AppDatabase.tableDischarge, orderBy: 'date ASC');
    return rows.map((r) => _dischargeFromMap(r)).toList();
  }

  Future<void> upsertDischarge(DischargeRecord r) async {
    final db = await _db.database;
    final dateKey = _key(r.date);
    final existing = await db.query(
      AppDatabase.tableDischarge,
      columns: ['id'],
      where: 'date = ?',
      whereArgs: [dateKey],
      limit: 1,
    );
    final now = DateTime.now().toIso8601String();
    if (existing.isNotEmpty) {
      await db.update(
        AppDatabase.tableDischarge,
        {
          'status': r.status,
          'amount': r.amount,
          'smell': r.smell,
          'itch': r.itch ? 1 : 0,
          'note': r.note,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    } else {
      await db.insert(AppDatabase.tableDischarge, {
        'date': dateKey,
        'status': r.status,
        'amount': r.amount,
        'smell': r.smell,
        'itch': r.itch ? 1 : 0,
        'note': r.note,
        'updated_at': now,
      });
    }
  }

  // ---------- 白带（删除按天） ----------
  Future<int> deleteDischargeByDate(DateTime date) async {
    final db = await _db.database;
    return db.delete(
      AppDatabase.tableDischarge,
      where: 'date = ?',
      whereArgs: [_key(date)],
    );
  }

  // ---------- 日记 ----------
  Future<List<DiaryEntry>> diariesOn(DateTime date) async {
    final db = await _db.database;
    final rows = await db.query(
      AppDatabase.tableDiary,
      where: 'date = ?',
      whereArgs: [_key(date)],
      orderBy: 'id ASC',
    );
    return rows.map((r) => _diaryFromMap(r)).toList();
  }

  Future<List<DiaryEntry>> allDiaries() async {
    final db = await _db.database;
    final rows = await db.query(AppDatabase.tableDiary, orderBy: 'date ASC, id ASC');
    return rows.map((r) => _diaryFromMap(r)).toList();
  }

  Future<int> insertDiary(DiaryEntry r) async {
    final db = await _db.database;
    return db.insert(AppDatabase.tableDiary, {
      'date': _key(r.date),
      'content': r.content,
      'images': jsonEncode(r.images),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> updateDiary(DiaryEntry r) async {
    if (r.id == null) return 0;
    final db = await _db.database;
    return db.update(
      AppDatabase.tableDiary,
      {
        'content': r.content,
        'images': jsonEncode(r.images),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [r.id],
    );
  }

  Future<int> deleteDiary(int id) async {
    final db = await _db.database;
    return db.delete(AppDatabase.tableDiary, where: 'id = ?', whereArgs: [id]);
  }

  // ---------- 行映射 ----------

  /// 索引越界防护：脏数据（越界枚举值）一律收敛到合法区间，避免显示/表单崩溃。
  static int _clampIndex(Object? raw, int min, int max) {
    final v = raw is num ? raw.toInt() : min;
    return v.clamp(min, max);
  }

  static IntimacyRecord _intimacyFromMap(Map<String, Object?> m) => IntimacyRecord(
        id: m['id'] as int?,
        date: DateTime.parse(m['date'] as String),
        protected: (m['protected'] as int? ?? 0) == 1,
      );

  static SymptomRecord _symptomFromMap(Map<String, Object?> m) => SymptomRecord(
        id: m['id'] as int?,
        date: DateTime.parse(m['date'] as String),
        symptom: _clampIndex(m['symptom'], 0, SymptomKind.items.length - 1),
        severity: _clampIndex(m['severity'], 0, SymptomSeverity.items.length - 1),
        note: m['note'] as String?,
      );

  static MoodRecord _moodFromMap(Map<String, Object?> m) {
    List<int> decodeEmotions(Object? raw) {
      if (raw == null) return const [];
      try {
        final list = (jsonDecode(raw as String) as List)
            .map((e) => _clampIndex(e, 0, MoodEmotion.items.length - 1))
            .toSet()
            .toList()
          ..sort();
        return list;
      } catch (e) {
        debugPrint('心情情绪解析失败：$e');
        return const [];
      }
    }

    return MoodRecord(
      id: m['id'] as int?,
      date: DateTime.parse(m['date'] as String),
      score: _clampIndex(m['score'], 1, 5),
      emotions: decodeEmotions(m['emotions']),
      note: m['note'] as String?,
    );
  }

  static WeightRecord _weightFromMap(Map<String, Object?> m) => WeightRecord(
        id: m['id'] as int?,
        date: DateTime.parse(m['date'] as String),
        kg: (m['kg'] as num?)?.toDouble() ?? 0,
      );

  static DischargeRecord _dischargeFromMap(Map<String, Object?> m) =>
      DischargeRecord(
        id: m['id'] as int?,
        date: DateTime.parse(m['date'] as String),
        status: _clampIndex(m['status'], 0, DischargeStatus.items.length - 1),
        amount: _clampIndex(m['amount'], 0, DischargeAmount.items.length - 1),
        smell: _clampIndex(m['smell'], 0, DischargeSense.items.length - 1),
        itch: (m['itch'] as int? ?? 0) == 1,
        note: m['note'] as String?,
      );

  static DiaryEntry _diaryFromMap(Map<String, Object?> m) {
    List<String> decodeImages(Object? raw) {
      if (raw == null) return const [];
      try {
        return (jsonDecode(raw as String) as List).cast<String>();
      } catch (e) {
        debugPrint('日记图片解析失败：$e');
        return const [];
      }
    }

    return DiaryEntry(
      id: m['id'] as int?,
      date: DateTime.parse(m['date'] as String),
      content: (m['content'] as String?) ?? '',
      images: decodeImages(m['images']),
    );
  }
}