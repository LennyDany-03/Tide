import 'package:supabase_flutter/supabase_flutter.dart';

import 'task.dart';
import 'task_rows.dart';

/// The server refused a task on its merits — bad data, a failed check, row
/// level security. Sending it again can only fail again.
class TaskRefused implements Exception {
  const TaskRefused(this.reason);

  final String reason;

  @override
  String toString() => 'TaskRefused: $reason';
}

/// The seam between the task list and the server.
///
/// Two calls, both whole-row: a push says what a task now *is*, so replaying
/// one is harmless, and a pull returns every row the server has written since
/// a cursor, deletions included. Anything that is not [TaskRefused] is worth
/// trying again later.
abstract class TaskRemote {
  Future<void> push(String accountId, Task task);

  /// Rows written at or after [since], oldest first, at most [limit].
  Future<List<RemoteTask>> pull(
    String accountId, {
    DateTime? since,
    int limit = 500,
  });
}

/// `public.tasks` in Supabase.
///
/// Last write wins on `updated_at`, and the server enforces it: a trigger
/// keeps the stored row when an incoming upsert is older, so a phone that has
/// been offline for a week cannot overwrite what another device did
/// yesterday. `synced_at` is stamped by the server, not the device, which is
/// what makes it safe to pull by — a device clock that is wrong cannot make
/// rows fall between two pulls.
class SupabaseTaskRemote implements TaskRemote {
  SupabaseTaskRemote(this._client);

  final SupabaseClient _client;

  @override
  Future<void> push(String accountId, Task task) async {
    try {
      await _client.from('tasks').upsert({
        ...TaskRows.row(task),
        'user_id': accountId,
      });
    } on PostgrestException catch (error) {
      final code = error.code ?? '';
      if (code.startsWith('22') || code.startsWith('23') || code == '42501') {
        throw TaskRefused('${error.code} ${error.message}');
      }
      rethrow;
    }
  }

  @override
  Future<List<RemoteTask>> pull(
    String accountId, {
    DateTime? since,
    int limit = 500,
  }) async {
    var query = _client.from('tasks').select().eq('user_id', accountId);
    if (since != null) {
      query = query.gte('synced_at', since.toUtc().toIso8601String());
    } else {
      // A first pull has nothing to remove, so deletions are not fetched.
      query = query.isFilter('deleted_at', null);
    }
    final rows = await query
        .order('synced_at', ascending: true)
        .order('id', ascending: true)
        .limit(limit);
    return [
      for (final row in rows) TaskRows.parseRemote(row),
    ].nonNulls.toList();
  }
}
