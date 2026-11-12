import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'easter_shop.dart';

class DailyStreakState {
  const DailyStreakState({
    this.current = 0,
    this.best = 0,
    this.lastActiveDay,
    this.recoverableCount = 0,
    this.recoveryBaseDay,
    this.recoveryUntil,
  });

  final int current;
  final int best;
  final String? lastActiveDay;
  final int recoverableCount;
  final String? recoveryBaseDay;
  final DateTime? recoveryUntil;

  bool activeToday(DateTime now) => lastActiveDay == _dateKey(now);

  bool canRecover(DateTime now) =>
      recoverableCount > 0 &&
      recoveryBaseDay != null &&
      recoveryUntil != null &&
      now.isBefore(recoveryUntil!);

  Map<String, Object?> toJson() => {
    'current': current,
    'best': best,
    'lastActiveDay': lastActiveDay,
    'recoverableCount': recoverableCount,
    'recoveryBaseDay': recoveryBaseDay,
    'recoveryUntil': recoveryUntil?.toIso8601String(),
  };

  factory DailyStreakState.fromJson(Map<String, dynamic> json) {
    final current = json['current'] as int? ?? 0;
    final best = json['best'] as int? ?? 0;
    final recoverableCount = json['recoverableCount'] as int? ?? 0;
    final lastActiveDay = json['lastActiveDay'] as String?;
    final recoveryBaseDay = json['recoveryBaseDay'] as String?;
    final recoveryUntil = DateTime.tryParse(
      json['recoveryUntil'] as String? ?? '',
    );
    if (current < 0 ||
        best < current ||
        recoverableCount < 0 ||
        (lastActiveDay != null && DateTime.tryParse(lastActiveDay) == null) ||
        (recoveryBaseDay != null &&
            DateTime.tryParse(recoveryBaseDay) == null)) {
      throw const FormatException('Saved streak data is invalid.');
    }
    return DailyStreakState(
      current: current,
      best: best,
      lastActiveDay: lastActiveDay,
      recoverableCount: recoverableCount,
      recoveryBaseDay: recoveryBaseDay,
      recoveryUntil: recoveryUntil,
    );
  }
}

class QuestStreakStore {
  static const appKey = 'app_daily_streak_v1';
  static const questKey = 'quest_daily_streak_v1';

  static Future<DailyStreakState> load(String key) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(key);
    if (encoded == null) return const DailyStreakState();
    final decoded = jsonDecode(encoded);
    if (decoded is! Map) {
      throw const FormatException('Saved streak data must be an object.');
    }
    return DailyStreakState.fromJson(Map<String, dynamic>.from(decoded));
  }

  static Future<DailyStreakState> recordActivity(
    String key, {
    DateTime? now,
  }) async {
    final current = await load(key);
    final time = now ?? DateTime.now();
    final today = _dateKey(time);
    if (current.lastActiveDay == today) return current;

    final previousDay = current.lastActiveDay;
    final daysSinceLast = previousDay == null
        ? null
        : _dayDifference(previousDay, today);
    final activeRecovery = current.canRecover(time);
    final missedDay = daysSinceLast != null && daysSinceLast > 1;
    final recoveredCandidate = missedDay
        ? current.current
        : current.recoverableCount;
    final updated = DailyStreakState(
      current: previousDay == null
          ? 1
          : daysSinceLast == 1
          ? current.current + 1
          : 1,
      best: current.best,
      lastActiveDay: today,
      recoverableCount: missedDay && !activeRecovery
          ? current.current
          : recoveredCandidate,
      recoveryBaseDay: missedDay && !activeRecovery
          ? previousDay
          : current.recoveryBaseDay,
      recoveryUntil: missedDay && !activeRecovery
          ? time.add(const Duration(hours: 48))
          : current.recoveryUntil,
    );
    final withBest = DailyStreakState(
      current: updated.current,
      best: updated.current > updated.best ? updated.current : updated.best,
      lastActiveDay: updated.lastActiveDay,
      recoverableCount: updated.recoverableCount,
      recoveryBaseDay: updated.recoveryBaseDay,
      recoveryUntil: updated.recoveryUntil,
    );
    await _save(key, withBest);
    return withBest;
  }

  static Future<DailyStreakState> recoverWithPoints(
    String key, {
    required int cost,
    required EasterEconomyStore economy,
    DateTime? now,
  }) async {
    final time = now ?? DateTime.now();
    final current = await load(key);
    if (!current.canRecover(time)) {
      throw StateError(
        'There is no streak to recover within its 48-hour window.',
      );
    }
    if (current.lastActiveDay == null || current.recoveryBaseDay == null) {
      throw StateError('The saved streak is missing recovery details.');
    }
    final actionId =
        'streak-repair:$key:${current.recoveryUntil!.toIso8601String()}';
    await economy.spendPointsOnce(actionId: actionId, cost: cost);

    final recoveredLength =
        current.recoverableCount +
        _dayDifference(current.recoveryBaseDay!, current.lastActiveDay!);
    final updated = DailyStreakState(
      current: recoveredLength > current.current
          ? recoveredLength
          : current.current,
      best: recoveredLength > current.best ? recoveredLength : current.best,
      lastActiveDay: current.lastActiveDay,
    );
    await _save(key, updated);
    return updated;
  }

  static Future<void> _save(String key, DailyStreakState state) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(key, jsonEncode(state.toJson()));
    if (!saved) {
      throw StateError('The device declined to save streak progress.');
    }
  }
}

String _dateKey(DateTime time) =>
    DateTime(time.year, time.month, time.day).toIso8601String();

int _dayDifference(String earlier, String later) {
  final first = DateTime.parse(earlier);
  final second = DateTime.parse(later);
  return DateTime(
    second.year,
    second.month,
    second.day,
  ).difference(DateTime(first.year, first.month, first.day)).inDays;
}

class StreakDashboard extends StatefulWidget {
  const StreakDashboard({super.key, required this.economy});

  final EasterEconomyStore economy;

  @override
  State<StreakDashboard> createState() => _StreakDashboardState();
}

class _StreakDashboardState extends State<StreakDashboard> {
  DailyStreakState _app = const DailyStreakState();
  DailyStreakState _quests = const DailyStreakState();
  bool _isLoading = true;
  bool _isWorking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait([
        QuestStreakStore.load(QuestStreakStore.appKey),
        QuestStreakStore.load(QuestStreakStore.questKey),
      ]);
      if (!mounted) return;
      setState(() {
        _app = values[0];
        _quests = values[1];
        _isLoading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _recordQuest() async {
    await _perform(() async {
      final updated = await QuestStreakStore.recordActivity(
        QuestStreakStore.questKey,
      );
      if (!mounted) return;
      setState(() => _quests = updated);
    });
  }

  Future<void> _recoverAppStreak() async {
    await _perform(() async {
      final updated = await QuestStreakStore.recoverWithPoints(
        QuestStreakStore.appKey,
        cost: 50,
        economy: widget.economy,
      );
      if (!mounted) return;
      setState(() => _app = updated);
    });
  }

  Future<void> _recoverQuestStreak() async {
    await _perform(() async {
      final updated = await QuestStreakStore.recoverWithPoints(
        QuestStreakStore.questKey,
        cost: 50,
        economy: widget.economy,
      );
      if (!mounted) return;
      setState(() => _quests = updated);
    });
  }

  Future<void> _perform(Future<void> Function() action) async {
    if (_isWorking) return;
    setState(() {
      _isWorking = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Widget _streakRow({
    required String title,
    required DailyStreakState state,
    required VoidCallback? onRecover,
    required DateTime now,
  }) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('🔥 ${state.current} days · personal best ${state.best}'),
          if (state.canRecover(now)) ...[
            const SizedBox(height: 8),
            Text(
              'A previous ${state.recoverableCount}-day streak can be repaired '
              'for 50 Easter Points within 48 hours.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            TextButton(
              onPressed: _isWorking ? null : onRecover,
              child: const Text('Repair with 50 Easter Points'),
            ),
          ],
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            'Streaks · prototype',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        if (_isLoading)
          const LinearProgressIndicator()
        else if (_error != null)
          Card(
            child: ListTile(
              title: const Text('Could not update streaks'),
              subtitle: Text(_error!),
              trailing: IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
              ),
            ),
          )
        else ...[
          _streakRow(
            title: 'Daily app streak',
            state: _app,
            now: now,
            onRecover: _recoverAppStreak,
          ),
          _streakRow(
            title: 'Quest completion streak',
            state: _quests,
            now: now,
            onRecover: _recoverQuestStreak,
          ),
          FilledButton.tonalIcon(
            onPressed: _isWorking || _quests.activeToday(now)
                ? null
                : _recordQuest,
            icon: const Icon(Icons.check_circle_outline),
            label: Text(
              _quests.activeToday(now)
                  ? 'Today’s quest streak is counted'
                  : 'Complete a no-purchase daily quest',
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Streaks and points are stored on this device. Completing a '
              'daily quest is self-reported in this prototype.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }
}

class SponsorQuestDemoCard extends StatefulWidget {
  const SponsorQuestDemoCard({super.key});

  @override
  State<SponsorQuestDemoCard> createState() => _SponsorQuestDemoCardState();
}

class _SponsorQuestDemoCardState extends State<SponsorQuestDemoCard> {
  static const _pendingKey = 'sponsor_quest_demo_pending_v1';
  XFile? _photo;
  bool _pending = false;
  bool _isLoading = true;
  bool _isWorking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _pending = preferences.getBool(_pendingKey) ?? false;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _choosePhoto() async {
    setState(() {
      _isWorking = true;
      _error = null;
    });
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
      );
      if (!mounted) return;
      if (photo != null) setState(() => _photo = photo);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Could not select a photo: $error');
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _submitDemo() async {
    if (_photo == null) {
      setState(() => _error = 'Choose a photo first.');
      return;
    }
    setState(() {
      _isWorking = true;
      _error = null;
    });
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = await preferences.setBool(_pendingKey, true);
      if (!saved) {
        throw StateError('The device declined to save the demo entry.');
      }
      if (!mounted) return;
      setState(() {
        _pending = true;
        _photo = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Could not submit the demo entry: $error');
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.campaign_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Example brand quest · not affiliated',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const Chip(label: Text('DEMO')),
            ],
          ),
          const SizedBox(height: 6),
          const Text('Weekly coffee moment (Starbucks example)'),
          const SizedBox(height: 6),
          const Text(
            'A future sponsor could offer a weekly challenge and a reward. '
            'This is not a Starbucks campaign: do not make a purchase for this '
            'demo, and no reward or payment is issued.',
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose a photo to preview a submission flow. The image stays on '
            'your device and is not uploaded or verified.',
            style: TextStyle(fontSize: 12),
          ),
          if (_photo != null)
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.image_outlined),
              title: Text('Photo selected'),
              subtitle: Text('Stored only in memory for this demo.'),
            ),
          if (_pending)
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.hourglass_top),
              title: Text('Demo entry submitted'),
              subtitle: Text(
                'Pending is only a local prototype state; no one reviews it.',
              ),
            )
          else
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _isLoading || _isWorking ? null : _choosePhoto,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Choose photo'),
                ),
                FilledButton(
                  onPressed: _isLoading || _isWorking || _photo == null
                      ? null
                      : _submitDemo,
                  child: Text(_isWorking ? 'Working…' : 'Submit demo entry'),
                ),
              ],
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    ),
  );
}
