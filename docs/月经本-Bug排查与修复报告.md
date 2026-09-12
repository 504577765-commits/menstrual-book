# 月经本 · Bug 排查与修复报告

> 执行方式：**检测 → 修正 → 复检** 循环，直到出现一轮完全无新发现的排查
> 终止条件：第 9 轮复检 `flutter analyze` 无任何告警、`flutter test` 全部通过，且该轮未发现新缺陷 → **循环终止**
> 检测手段：① 静态分析（flutter analyze）② 领域层与 UI 自动化测试（flutter test）③ 人工逐文件走查 ④ 依赖包真实 API 比对

---

## 一、总体结果

| 指标 | 起始 | 结束 |
|---|---|---|
| 静态分析 | 9 error / 1 warning / 14 info | **0 error / 0 warning / 0 info** |
| 自动化测试 | 15 个用例 | **70 个用例，全部通过** |
| 累计发现缺陷 | — | **30 个**（严重 8 / 中 15 / 低 7） |

按轮次分布：

| 轮次 | 发现数 | 是否有严重缺陷 |
|---|---|---|
| 第 1 轮 | 12 | 是（5 个） |
| 第 2 轮 | 5 | 是（1 个） |
| 第 3 轮 | 3 | 否 |
| 第 4 轮 | 1 | 否 |
| 第 5 轮 | 3 | 否 |
| 第 6 轮 | 2 | 否 |
| 第 7 轮 | 3 | 否 |
| 第 8 轮 | 1（+2 个自身引入、同轮修复） | 否 |
| **第 9 轮** | **0 → 循环终止** | — |

---

## 二、第 1 轮：基础正确性与"功能根本不可用"类缺陷

### B1 · 严重 · 定时提醒根本不会触发，重启后丢失
- **位置**：`app/android/app/src/main/AndroidManifest.xml`
- **成因**：`flutter_local_notifications` 22.x 的库清单（`android/src/main/AndroidManifest.xml`）**只声明了权限，未声明 receiver**。`ScheduledNotificationReceiver` / `ScheduledNotificationBootReceiver` 必须由 App 清单声明，否则 `zonedSchedule` 排定的通知不会被系统投递，开机后也无法重排。我在集成时漏掉了这一步。已通过读取插件清单源码确认。
- **修正**：在 App 清单补齐 3 个 receiver（含 `BOOT_COMPLETED` / `MY_PACKAGE_REPLACED` / `QUICKBOOT_POWERON` 意图过滤）。
- **验证**：构建后检查合并清单包含这三个 receiver（见第五节）。

### B2 · 严重 · 删除经期后残留孤儿数据
- **位置**：`lib/data/database/app_database.dart`
- **成因**：sqflite 默认 `PRAGMA foreign_keys = OFF`，导致 `cycle_day` 上的 `ON DELETE CASCADE` 不生效。
- **修正**：`openDatabase` 增加 `onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON')`。

### B3 · 严重 · 预测已推迟时，提醒与首页信息自相矛盾
- **位置**：`lib/presentation/state/app_state.dart` `_rescheduleReminders`
- **成因**：`nextStart` 会被滚动到"下一个未来周期"，但提醒仍按该日期排「经前 2 天提醒」。结果是：用户明明已经推迟 31 天，却收到"经期快到了"；首页同时显示"还有 25 天"与"已推迟 31 天"。
- **修正**：推迟状态下不再排经前/当天提醒，改排一条「上一次经期是不是已经开始了？」；首页卡片在推迟时以"已推迟 N 天"为主信息。
- **验证**：`reminder_plan_test.dart` 断言推迟时 `overduePrompt` 存在且 `prePeriod/periodStart` 不存在；`ui_smoke_test.dart` 断言卡片文案。

### B4 · 严重 · 应用锁反复触发验证（阈值 0 时必然发生）
- **位置**：`lib/presentation/pages/lock_gate.dart`
- **成因**：系统生物识别弹窗自身会引起 `paused → resumed`。原逻辑在 `resumed` 时用 `elapsed >= autoLockSeconds` 判断，未忽略"正在验证中"这一状态；当阈值为 0 时 `>= 0` 恒真，形成「验证→暂停→恢复→再验证」的循环。
- **修正**：验证进行中直接忽略生命周期事件；判定改为 `>`。

### B5 · 严重 · 启动异常导致永久卡在加载圈
- **位置**：`lib/presentation/state/app_state.dart` `load()`
- **成因**：库口令存放在 Keystore 中，一旦读取失败（典型场景：用户移除了手机锁屏凭据）会抛异常；`load()` 无捕获，`isReady` 永远为 false，UI 一直转圈，用户既看不到数据也得不到任何解释。
- **修正**：捕获异常并暴露 `loadError`；新增错误页 + 重试入口，文案说明 Keystore 失效这一具体原因。

### B6 · 中 · 打开每日详情后直接保存会写入伪数据
- **位置**：`lib/presentation/widgets/record_sheets.dart`（原在 `home_page.dart`）
- **成因**：弹层用「整次概览」作为选择器初值，用户只是查看、未做任何改动就点保存，会生成一条本不存在的当日记录，污染数据。
- **修正**：引入 `touched` 标记；未改动且原值为空 → 返回 `DayDetailResult.noop()`，调用方不落库。

### B7–B12 · 中/低
| 编号 | 问题 | 成因 | 修正 |
|---|---|---|---|
| B7 | 倒计时显示"0 天" | 未处理 `daysUntilNext == 0` | 改为「就是今天」 |
| B8 | 选择器在大字号下溢出 | `_ChoiceTile` 写死 `height: 64` | 改自适应高度 + `Flexible` + 省略号 |
| B9 | 趋势柱状图潜在 0 除 | 未校验 `maxValue` | 抽出 `_barHeight()` 并加早返回 |
| B10 | 每日详情写入语义混乱 | 用 `ConflictAlgorithm.replace`（先删后插、id 错位） | 改显式 update-or-insert |
| B11 | 14 条静态分析告警 | 无用 import、`const` 缺失、字符串插值多余花括号等 | 逐项清理至 0 |
| B12 | 时区硬编码 | 显式设 `Asia/Shanghai` | **复核为非缺陷**：`TZDateTime.from` 保持绝对时刻，触发时间不受影响；仍加 try/catch 防御 |

### 由测试发现（而非人工走查）的界面缺陷
- **进行中倒计时卡在 400px 宽度下 RenderFlex 右侧溢出 33px**（`_BigValue` 把"第 N 天"与"预计 X 月 X 日结束"放在同一行）。已把预计结束日移到下一行并加 `Flexible`。
- **价值说明**：该缺陷在代码层面完全"看起来正确"，只有真正跑布局才会暴露，这正是必须写 widget 测试的直接证据。

---

## 三、第 2 轮：状态机与完整性

### R2-1 · 中 · 置信度与倒计时自相矛盾
- **位置**：`lib/domain/prediction/prediction_engine.dart`
- **成因**：只有 1 条记录时 `cycleLengths` 为空 → `sampleCount = 0` → 被判为 `Confidence.none`。但此时**已经给出了预测**，卡片上却显示"暂无数据"，同时右侧还在倒计时。
- **修正**：重命名为 `_confidenceOf` 并让 `sampleCount == 0` 返回 `low`；`none` 仅保留给"完全没有锚点、无法预测"的情况。

### R2-2 · 中 · 冷启动误报"周期异常"
- **位置**：`lib/presentation/state/app_state.dart` `anomalies`
- **成因**：样本不足时 `avgCycleLen` 退化为用户设置值（默认 28），天生周期 35–40 天的正常用户在记录 2 次后就会收到"关注提示"。
- **修正**：完整周期 < 3 个时不做异常判定。

### R2-3 · 严重 · 在无凭据设备上开启应用锁会把自己永久锁在数据外
- **位置**：`lib/presentation/pages/settings_page.dart`
- **成因**：应用锁开关直接写库。若设备既无生物识别、也未设置锁屏凭据，`authenticate()` 永远失败，而数据是加密的——用户无法进入应用，且本应用**没有任何备份导出**。
- **修正**：开启前先执行一次真实身份验证，失败则拒绝开启并给出明确指引。

### R2-4 / R2-5 · 中 · 编辑记录缺少完整性校验
- **成因**：可把多条记录同时置为"进行中"（状态歧义）；也可把区间改到与已有记录重叠（污染周期计算）。
- **修正**：新增 `allowOngoing` 与重叠校验。

---

## 四、第 3–8 轮

### 第 3 轮
| 编号 | 级别 | 问题 | 成因 | 修正 |
|---|---|---|---|---|
| R3-1 | 中 | 「免打扰时段」是死配置 | `dndEnabled/dndStartHour/dndEndHour` 已建模、已持久化，但排提醒时完全未使用，设置页也没有入口 | 抽出纯函数 `domain/prediction/dnd.dart` 并接线；设置页补开关与起止小时选择 |
| R3-2 | 中 | 启动时不重排提醒 | 只在数据变更时重排；放置较久后预测已变为"已推迟"，提醒却仍是旧内容 | `load()` 末尾重排（失败单独兜底，不影响可用性） |
| R3-3 | 低 | 列表对可能为空的 id 使用 `!` | 未做空安全 | 改为空安全取值 |

### 第 4 轮
- **R4-1 · 中 · 「经期来了」弹层允许选择与已有记录重叠的日期** → 抽出纯函数 `domain/validation/cycle_validation.dart`，`AppState` 与编辑弹层**统一复用同一套规则**，避免两处规则漂移。

### 第 5 轮
| 编号 | 级别 | 问题 | 成因 | 修正 |
|---|---|---|---|---|
| R5-1 | 中 | "经前提醒提前量"只有展示没有编辑入口 | 需求要求可调，实际是死配置 | 补 1–7 天的加减控件 |
| R5-2 | 中 | 「经期还在继续吗」提醒永远不触发 | 目标时间恒取"明天"，用户每天打开应用都会把它再推后一天 | 抽 `nextDailyOccurrence()`：取"最近的一次未来时刻" |
| R5-3 | 低 | 免打扰起止相同却无提示 | UI 未校验 | 显示"起止时间相同，未生效" |

### 第 6 轮
- **R6-1 / R6-2 · 中 · 「经期来了」与「编辑记录」弹层在大字号下垂直溢出** → 统一改用可滚动外壳 `SheetScaffold`。
- 同时把三个记录弹层从页面私有类抽为**公共可测组件**（`presentation/widgets/record_sheets.dart`），使它们第一次进入自动化测试覆盖范围。

### 第 7 轮
| 编号 | 级别 | 问题 | 成因 | 修正 |
|---|---|---|---|---|
| R7-1 | 低 | 趋势图残留非空断言 | 逻辑正确但可读性/安全性差 | 抽出 `_barHeight()`，消除断言 |
| R7-2 | 低 | `lock_service` 4 处 `catch (_)` 静默吞异常 | 无日志，问题不可观测 | 改为记录日志 |
| R7-3 | 中 | 单行数据损坏会导致整个应用不可用 | `_cycleFromMap` 抛异常 → `load()` 失败 → 只能看到错误页；而本应用无备份，用户连其余数据都看不到 | 跳过损坏行并记录日志，保证其余数据可读 |

### 第 8 轮
- **R8-1 · 中 · 提醒排定计划无任何测试覆盖**：该逻辑是核心功能，且第 1、5 轮各暴露过一个缺陷，却埋在 `AppState` 私有方法里、强依赖通知插件，无法单测。
- **修正**：抽出纯函数 `buildReminderPlan(prediction, settings, now)`；顺带把 `ReminderSettings` 从数据层下沉到领域层（修正依赖方向 data → domain）；通知 id 由服务层通过 `ReminderKind` 映射。
- **同轮复检还抓出 2 个我自己在修复过程中引入的问题**：`settings_repository` 的多余 import（只 export 未 import）、测试中把运行时值当编译期常量使用。均在当轮修复 —— 说明"改完必须再跑一遍"不是形式。

### 第 9 轮
- **新发现缺陷：0**。`flutter analyze` 无任何告警，`flutter test` 70/70 通过 → **循环终止**。

---

## 五、环境类问题（非代码缺陷，但阻塞交付）

这三项耗时最多，且都不是代码问题，单独记录以便复用：

1. **`flutter test` 报 `Unable to connect to flutter_tester process: Invalid WebSocket upgrade request`**
   成因：环境设置了 `http_proxy/https_proxy`，回环地址未绕过代理，测试进程连不上本机 `flutter_tester`。
   处置：`NO_PROXY / no_proxy = localhost,127.0.0.1,::1`。

2. **Gradle 报 `settings.gradle.kts: Unresolved reference 'run' / 'plugins' / 'id'`**
   成因：默认的 `C:\Users\<user>\.gradle` 缓存被污染（残留 Gradle 8.7 时代的 `caches/jars-9`、`transforms-4`、`kotlin-dsl`），与 Gradle 9.3.1 的 Kotlin DSL 脚本编译不兼容，导致**脚本编译类路径为空**。用最小 Kotlin DSL 工程 30 秒即可复现，证明与项目代码无关。
   处置：`GRADLE_USER_HOME` 指向工作区内的干净目录 `D:\yuejingbenapp\.tooling\gradle_home`（同时也满足"不写其他文件夹"的约束）。

3. **Gradle 依赖解析长时间无响应**
   成因：默认仓库 `dl.google.com` / `repo.maven.apache.org` 在本机网络下不可靠；且 Gradle 默认无超时，表现为"卡死"而非报错。
   处置：`init.d/mirrors.gradle` 镜像 `pluginManagement` 仓库 + 显式设置 `connectionTimeout/socketTimeout`，让问题快速暴露。
   注意：**不能**用 `allprojects { repositories { ... } }` —— Flutter 模板启用了"settings 仓库优先"，由脚本向工程追加仓库会直接报错。

---

## 六、验证结果

```
flutter analyze  →  No issues found!
flutter test     →  70/70 全部通过
```

测试覆盖分布：

| 测试文件 | 覆盖内容 |
|---|---|
| `prediction_engine_test.dart` | 冷启动、置信度分级、进行中状态、推迟滚动、抗离群值、排卵推算、防御性输入（步长 ≤ 0 不死循环） |
| `anomaly_test.dart` | 阈值与"连续 2 次"规则、经期过长/过短、排序 |
| `cycle_stats_test.dart` | 平均值计算、近 6 月序列、进行中记录不计入均值 |
| `dnd_test.dart` | 免打扰区间（含跨天）、顺延语义、每日提醒时刻计算 |
| `cycle_validation_test.dart` | 重叠检测（含进行中记录）、区间合法性 |
| `reminder_plan_test.dart` | 提醒计划四条分支、开关生效、提前量、推迟改写、免打扰顺延、通知 id 稳定性 |
| `ui_smoke_test.dart` | 倒计时卡四种状态、月历渲染与交互、选择器交互、**1.4× 大字号不溢出** |
| `record_sheets_test.dart` | 三个记录弹层的返回值语义、校验错误、**1.4× 大字号不溢出** |

---

## 七、已知限制（诚实声明，未纳入本次修复）

1. **无任何备份/导出**（产品决策）：卸载、换机、丢机 = 数据永久丢失。架构已预留导出位置。
2. **移除手机锁屏凭据会导致已加密数据无法解密**：Keystore 的固有行为，已在设置页给出提示，无法从技术上规避。
3. **时区**：提醒时刻按绝对时间调度，硬编码时区不影响触发；若未来使用"按日历重复"的提醒则需改为读取设备时区。
4. **未覆盖的自动化测试**：`AppState` 中与数据库耦合的编排逻辑、`LockGate`、设置页（依赖 `ProviderContainer` 与真实数据库）尚无自动化测试；其可纯化的部分已全部抽出并覆盖。
5. **数据库无升级路径**：`schemaVersion = 1`，尚无 `onUpgrade`，V1.1 新增表时需补齐。
