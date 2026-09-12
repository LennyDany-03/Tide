import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards on `supabase/billing_setup.sql` that no Dart test can otherwise make.
///
/// The security model has one load-bearing claim: **the app cannot grant
/// itself anything.** `authenticated` gets SELECT on three tables, EXECUTE on
/// two read functions, and EXECUTE on exactly two writers that are incapable
/// of extending a period. Every part of that is a property of a text file that
/// no amount of Dart can check at run time, and all of it is one well-meaning
/// edit away from being untrue.
///
/// So this reads the SQL. It is a blunt instrument — string matching, not a
/// parser — and that is the right trade: it has one job, and a regular
/// expression that stops matching when somebody reformats the file is a much
/// better failure than a parser that quietly matches the wrong thing.
/// A newline and a carriage return as char codes rather than escapes.
///
/// Not fussiness: this file is mostly assertions *about* backslashes, and a
/// collapsed escape here would not fail loudly — it would make a regex match
/// nothing and the test pass for the wrong reason. Char codes cannot collapse.
final newline = String.fromCharCode(10);

void main() {
  late String sql;

  setUpAll(() {
    final file = File('supabase/billing_setup.sql');
    expect(
      file.existsSync(),
      isTrue,
      reason: 'run from the repo root: flutter test',
    );
    // Carriage returns stripped: the file is checked out with CRLF on
    // Windows, and several assertions below span a line break. Written as
    // a char code rather than an escape so the expression stays readable.
    sql = file.readAsStringSync().replaceAll(String.fromCharCode(13), '');
  });

  /// The body of a `create or replace function` block, from its signature to
  /// the `$fn$;` that closes it.
  String bodyOf(String name) {
    final start = sql.indexOf('create or replace function public.$name');
    expect(start, greaterThan(-1), reason: '$name is not in the file');
    final end = sql.indexOf(r'$fn$;', start);
    expect(end, greaterThan(start), reason: '$name is not closed');
    return sql.substring(start, end);
  }

  /// Everything a caller may execute.
  const appWritable = ['cancel_subscription', 'resume_subscription'];

  group('the two functions the app may write through', () {
    for (final name in appWritable) {
      group(name, () {
        test('takes no argument, so there is no user id to forge', () {
          expect(
            sql,
            contains('create or replace function public.$name()'),
            reason:
                'a p_user_id parameter is broken by the first caller who '
                'passes somebody else\'s uuid',
          );
        });

        test('acts only on the caller', () {
          final body = bodyOf(name);
          expect(body, contains('auth.uid()'));
          expect(body, contains('where user_id = v_user'));
        });

        test('cannot extend a period, change plan, or rewrite history', () {
          // The whole safety argument in one assertion: a column a function
          // never names is a column it cannot move.
          final body = bodyOf(name);
          for (final column in const [
            'current_period_end',
            'current_period_start',
            'plan_id',
            'source',
            'last_payment_id',
            'history',
          ]) {
            expect(
              body,
              isNot(contains('$column =')),
              reason: '$name must never assign $column',
            );
          }
        });

        test('only ever moves between the two states that mean the same', () {
          // 'active' and 'cancelled' are the same answer to entitlement_of:
          // both are Pro while the period runs. Any other target state would
          // be a change in access.
          final body = bodyOf(name);
          final assigned = RegExp(
            r"status\s*=\s*'([a-z]+)'",
          ).allMatches(body).map((m) => m.group(1)).toSet();
          expect(assigned, isNotEmpty);
          expect(assigned.difference({'active', 'cancelled'}), isEmpty);
        });

        test('is guarded on the period still running', () {
          expect(bodyOf(name), contains('current_period_end > now()'));
        });

        test('is revoked from everyone, then granted only to authenticated', () {
          expect(
            sql,
            contains(
              'revoke all on function public.$name()\n'
              '  from public, anon, authenticated;',
            ),
          );
          expect(
            RegExp(
              'grant execute on function public\\.$name\\(\\) to authenticated;',
            ).allMatches(sql).length,
            1,
            reason: 'exactly one grant, to exactly one role',
          );
        });

        test('is not marked stable, so PostgREST will not accept a GET', () {
          // A stable function is reachable by GET, which is a CSRF-shaped
          // surface for something that changes state.
          expect(bodyOf(name), isNot(contains('stable')));
        });
      });
    }
  });

  group('what the app still cannot reach', () {
    for (final name in const [
      'apply_payment',
      'revoke_payment',
      'entitlement_of',
      'expire_subscriptions',
    ]) {
      test('$name is revoked from authenticated', () {
        expect(
          RegExp(
            'revoke all on function public\\.$name\\([^)]*\\)\\s*\\n?\\s*'
            'from public, anon, authenticated;',
          ).hasMatch(sql),
          isTrue,
          reason: '$name must never be callable by the app',
        );
      });

      test('$name is not granted to authenticated', () {
        // Specifically to `authenticated` or `anon`, not to anybody at all.
        // All four of these *are* granted to `service_role` in section 10,
        // which is the point: the Edge Functions reach them and the app
        // cannot. A regex spanning that distinction is one stray escape away
        // from passing vacuously, so this scans the lines instead.
        final grants = sql
            .split(newline)
            .where((line) => line.trimLeft().startsWith('grant execute'))
            .where((line) => line.contains('public.$name('))
            .toList();

        for (final line in grants) {
          expect(
            line.contains('authenticated') || line.contains(' anon'),
            isFalse,
            reason:
                'this grant would hand the app a way to grant itself Pro:'
                ' ${line.trim()}',
          );
        }
      });

    }

    test('no table gives authenticated anything but select', () {
      for (final verb in const ['insert', 'update', 'delete']) {
        expect(
          sql.contains('grant $verb'),
          isFalse,
          reason: 'billing tables are read-only to the app',
        );
      }
    });
  });

  group('receipts', () {
    test('a dismissed payment sheet is kept out of the history', () {
      // The app records a closed sheet as a failed order so the order stops
      // being open. Surfacing it would put a permanent "Payment failed" line
      // in the history of anybody who looked at the price and changed their
      // mind.
      expect(
        sql,
        contains("failure ->> 'code' = 'cancelled'"),
        reason: 'billing_snapshot must filter dismissals out',
      );
    });
  });
}
