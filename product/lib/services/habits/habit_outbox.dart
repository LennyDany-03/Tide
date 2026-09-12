import 'dart:convert';

import 'package:flutter/foundation.dart';

/// What a [PendingWrite] does on the server.
enum PendingWriteKind {
  /// Upserts a `habits` row.
  habit,

  /// Upserts a `habit_entries` row.
  entry,

  /// Deletes a habit, and its entries with it by cascade.
  removal,
}

/// One write this device has made and the server has not yet confirmed.
@immutable
class PendingWrite {
  const PendingWrite._(this.kind, this.row);

  const PendingWrite.habit(Map<String, dynamic> row)
    : this._(PendingWriteKind.habit, row);

  const PendingWrite.entry(Map<String, dynamic> row)
    : this._(PendingWriteKind.entry, row);

  PendingWrite.removal(String habitId)
    : this._(PendingWriteKind.removal, {'id': habitId});

  final PendingWriteKind kind;

  /// The row exactly as it will be sent, less `user_id`.
  final Map<String, dynamic> row;

  String get habitId =>
      (kind == PendingWriteKind.entry ? row['habit_id'] : row['id']) as String;

  /// Writes that share a key describe the same row, so the later one makes the
  /// earlier one redundant. A removal shares its habit's key.
  String get key => keyFor(
    habitId,
    day: kind == PendingWriteKind.entry ? row['day'] as String : null,
  );

  static String keyFor(String habitId, {String? day}) =>
      day == null ? 'habit:$habitId' : 'entry:$habitId:$day';

  Map<String, dynamic> toJson() => {'kind': kind.name, 'row': row};

  static PendingWrite? fromJson(Object? json) {
    if (json is! Map) return null;
    final kind = PendingWriteKind.values.asNameMap()[json['kind']];
    final row = json['row'];
    if (kind == null || row is! Map) return null;
    // A row missing the ids its key is built from cannot be sent anywhere.
    final ids = kind == PendingWriteKind.entry
        ? [row['habit_id'], row['day']]
        : [row['id']];
    if (!ids.every((id) => id is String)) return null;
    return PendingWrite._(kind, Map<String, dynamic>.from(row));
  }
}

/// The writes this device owes the server, in the order they were made.
///
/// **Why whole rows.** Every write says what a row now *is* ("8 glasses on
/// the 11th"), never what happened to it ("+1 glass"). Sending one twice is
/// harmless, so a queue that was half sent when the app was killed can be
/// replayed from the top; and a later write to a row that is still waiting
/// makes the earlier one redundant, so an afternoon of offline taps is one
/// write per habit per day rather than one per tap.
///
/// **Why a replacement keeps its place.** A new habit's row is queued before
/// its first entry, and the entry's foreign key needs that order. Replacing a
/// waiting write where it stands, rather than moving it to the back, keeps
/// every habit ahead of its entries however often either is edited.
///
/// The write being sent is never replaced — its request has already left with
/// the old row — so a newer write to the same row queues behind it instead.
class HabitOutbox {
  HabitOutbox([Iterable<PendingWrite> writes = const []])
    : _writes = [...writes];

  final List<PendingWrite> _writes;
  PendingWrite? _sending;

  bool get isEmpty => _writes.isEmpty;

  int get length => _writes.length;

  List<PendingWrite> get writes => List.unmodifiable(_writes);

  /// Whether a write to the row [key] names is waiting or on its way.
  bool holds(String key) => _writes.any((write) => write.key == key);

  void add(PendingWrite write) {
    if (write.kind == PendingWriteKind.removal) {
      dropHabit(write.habitId);
      _writes.add(write);
      return;
    }
    final index = _writes.indexWhere(
      (waiting) => !identical(waiting, _sending) && waiting.key == write.key,
    );
    if (index < 0) {
      _writes.add(write);
    } else {
      _writes[index] = write;
    }
  }

  /// Forgets every waiting write for [habitId]. The habit is gone: an entry
  /// for it would be refused, and its row would bring it back.
  void dropHabit(String habitId) {
    _writes.removeWhere(
      (waiting) => !identical(waiting, _sending) && waiting.habitId == habitId,
    );
  }

  /// The oldest write, marked as being sent. Null while one is already out,
  /// or when nothing is owed: one request at a time keeps the order.
  PendingWrite? take() {
    if (_sending != null || _writes.isEmpty) return null;
    return _sending = _writes.first;
  }

  /// [write] is done with: the server took it, or refused it for good.
  void settle(PendingWrite write) {
    _writes.removeWhere((waiting) => identical(waiting, write));
    if (identical(_sending, write)) _sending = null;
  }

  /// [write] could not be sent just now. It stays first in line.
  void release(PendingWrite write) {
    if (identical(_sending, write)) _sending = null;
  }

  String encode() =>
      jsonEncode([for (final write in _writes) write.toJson()]);

  /// A queue saved by [encode]. Anything unreadable is dropped rather than
  /// left to block the writes behind it.
  static HabitOutbox decode(String? source) {
    if (source == null || source.isEmpty) return HabitOutbox();
    try {
      final list = jsonDecode(source);
      if (list is! List) return HabitOutbox();
      return HabitOutbox(list.map(PendingWrite.fromJson).nonNulls);
    } on FormatException {
      return HabitOutbox();
    }
  }
}
