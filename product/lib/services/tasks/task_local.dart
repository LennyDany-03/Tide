import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'task.dart';
import 'task_rows.dart';

/// Where an account's tasks live on this device — the list the screen draws.
///
/// `shared_preferences`, like the habit cache and the habit outbox, rather
/// than a database. A to-do list is a few hundred rows at the very most, it
/// is always read whole, and its sync state travels on each row, so there is
/// nothing an index would be asked. A second storage engine — and a code
/// generator, and native libraries on every platform — would be carried for
/// a query this list never makes. It also keeps web builds working, which
/// the embedded databases do not.
abstract class TaskLocal {
  List<Task> load(String accountId);

  /// Replaces the account's copy. Called after every change, so a task added
  /// offline survives the app being killed a second later.
  void save(String accountId, List<Task> tasks);

  /// The server time of the newest row this device has pulled, or null
  /// before the first pull.
  DateTime? cursor(String accountId);

  void setCursor(String accountId, DateTime cursor);

  /// Drops everything kept for [accountId]. For a log out.
  void forget(String accountId);

  /// The list's one-time gesture tip has been dismissed. Per device, not per
  /// account: it teaches the phone's owner a gesture, not an account a fact.
  bool get swipeHintSeen;

  void markSwipeHintSeen();
}

class PrefsTaskLocal implements TaskLocal {
  PrefsTaskLocal(this._prefs);

  static Future<PrefsTaskLocal> open() async =>
      PrefsTaskLocal(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  static String _listKey(String accountId) => 'tide.tasks.$accountId';
  static String _cursorKey(String accountId) => 'tide.tasks_cursor.$accountId';

  @override
  List<Task> load(String accountId) {
    final source = _prefs.getString(_listKey(accountId));
    if (source == null) return const [];
    try {
      final rows = jsonDecode(source);
      if (rows is! List) return const [];
      return [
        for (final row in rows)
          if (row is Map) TaskRows.parseCached(Map<String, dynamic>.from(row)),
      ].nonNulls.toList();
    } on FormatException {
      return const [];
    }
  }

  @override
  void save(String accountId, List<Task> tasks) {
    unawaited(
      _prefs.setString(
        _listKey(accountId),
        jsonEncode([for (final task in tasks) TaskRows.cached(task)]),
      ),
    );
  }

  @override
  DateTime? cursor(String accountId) {
    final value = _prefs.getString(_cursorKey(accountId));
    return value == null ? null : DateTime.tryParse(value);
  }

  @override
  void setCursor(String accountId, DateTime cursor) {
    unawaited(
      _prefs.setString(_cursorKey(accountId), cursor.toUtc().toIso8601String()),
    );
  }

  @override
  void forget(String accountId) {
    unawaited(_prefs.remove(_listKey(accountId)));
    unawaited(_prefs.remove(_cursorKey(accountId)));
  }

  static const String _hintKey = 'tide.tasks_swipe_hint_seen';

  @override
  bool get swipeHintSeen => _prefs.getBool(_hintKey) ?? false;

  @override
  void markSwipeHintSeen() => unawaited(_prefs.setBool(_hintKey, true));
}

/// Tests and builds with no project: kept for the life of the process.
class MemoryTaskLocal implements TaskLocal {
  final Map<String, List<Task>> _tasks = {};
  final Map<String, DateTime> _cursors = {};

  @override
  List<Task> load(String accountId) => _tasks[accountId] ?? const [];

  @override
  void save(String accountId, List<Task> tasks) =>
      _tasks[accountId] = List.of(tasks);

  @override
  DateTime? cursor(String accountId) => _cursors[accountId];

  @override
  void setCursor(String accountId, DateTime cursor) =>
      _cursors[accountId] = cursor;

  @override
  void forget(String accountId) {
    _tasks.remove(accountId);
    _cursors.remove(accountId);
  }

  @override
  bool swipeHintSeen = false;

  @override
  void markSwipeHintSeen() => swipeHintSeen = true;
}
