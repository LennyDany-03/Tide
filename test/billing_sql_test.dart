import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards on `supabase/billing_setup.sql` that no Dart test can otherwise make.
///
/// The security model has one load-bearing claim: **the app cannot grant
/// itself anything.** `authenticated` gets SELECT on four tables, EXECUTE on
/// two read functions, and EXECUTE on exactly two writers that are incapable
/// of extending a period. Every part of that is a property of a text file that
/// no amount of Dart can check at run time, and all of it is one well-meaning
/// edit away from being untrue.
///
/// Auto-pay added a second grant path and a third shape of writer, and the
/// claim has to hold across all of them: `apply_subscription_charge` grants and
/// so is service-role only; `sync_mandate_state` is reachable by every webhook
/// Razorpay sends and so must be unable to move a period; `extend_period` is
/// the only thing that computes one and is granted to nobody at all.
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
  ///
  /// The opening bracket in the match is load-bearing: `cancel_subscription` is
  /// a prefix of `cancel_subscription_for`, and without it this would hand back
  /// whichever of the two appears first in the file and assert the wrong
  /// function's properties — passing or failing for reasons that have nothing
  /// to do with the function named.
  String bodyOf(String name) {
    final start = sql.indexOf('create or replace function public.$name(');
    expect(start, greaterThan(-1), reason: '$name is not in the file');
    final end = sql.indexOf(r'$fn$;', start);
    expect(end, greaterThan(start), reason: '$name is not closed');
    return sql.substring(start, end);
  }

  /// Every `grant execute` line naming [name], exactly as written.
  List<String> grantsOf(String name) => sql
      .split(newline)
      .where((line) => line.trimLeft().startsWith('grant execute'))
      .where((line) => line.contains('public.$name('))
      .toList();

  /// The columns a function must never assign, whoever may call it. A column a
  /// function does not name is a column it cannot move, and that is the whole
  /// safety argument for every writer in this file except the two that grant.
  const untouchable = [
    'current_period_end',
    'current_period_start',
    'plan_id',
    'source',
    'last_payment_id',
    'history',
  ];

  /// The two that do the work, by user id, for a caller that has already done
  /// the part they cannot: cancelling the mandate at Razorpay.
  const implementations = ['cancel_subscription_for', 'resume_subscription_for'];

  /// The two the app itself may execute, pinned to the token's own account.
  const wrappers = ['cancel_subscription', 'resume_subscription'];

  group('the implementations, reachable only by the service role', () {
    for (final name in implementations) {
      group(name, () {
        test('acts only on the user it was given', () {
          final body = bodyOf(name);
          expect(body, contains('where user_id = p_user_id'));
        });

        test('cannot extend a period, change plan, or rewrite history', () {
          final body = bodyOf(name);
          for (final column in untouchable) {
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
          final assigned = RegExp(
            r"status\s*=\s*'([a-z_]+)'",
          ).allMatches(bodyOf(name)).map((m) => m.group(1)).toSet();
          expect(assigned, isNotEmpty);
          expect(assigned.difference({'active', 'cancelled'}), isEmpty);
        });

        test('is guarded on the period still running', () {
          expect(bodyOf(name), contains('current_period_end > now()'));
        });

        test('is revoked from the app and granted only to service_role', () {
          expect(
            sql,
            contains(
              'revoke all on function public.$name(uuid)\n'
              '  from public, anon, authenticated;',
            ),
          );
          final grants = grantsOf(name);
          expect(grants, hasLength(1), reason: 'exactly one grant');
          expect(
            grants.single.contains('authenticated') ||
                grants.single.contains(' anon'),
            isFalse,
            reason: 'the app must not reach an implementation directly: '
                '${grants.single.trim()}',
          );
          expect(grants.single, contains('service_role'));
        });
      });
    }
  });

  group('the two functions the app may write through', () {
    for (final name in wrappers) {
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
          expect(body, contains('(v_user)'));
        });

        test('refuses a plan with a mandate behind it', () {
          // The line that stops the app marking a row cancelled while the
          // standing instruction is still registered at Razorpay — which
          // would have the app saying nothing more will be taken while the
          // money keeps going out every month.
          final body = bodyOf(name);
          expect(body, contains('mandate_id is not null'));
          expect(body, contains('raise exception'));
        });

        test('cannot extend a period, change plan, or rewrite history', () {
          final body = bodyOf(name);
          for (final column in untouchable) {
            expect(
              body,
              isNot(contains('$column =')),
              reason: '$name must never assign $column',
            );
          }
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

  group('auto-pay cannot grant anything either', () {
    test('sync_mandate_state can never move a period', () {
      // Reachable by every subscription webhook Razorpay sends, which is the
      // widest surface in the file: a signature proves the delivery came from
      // them, not that its contents are what we would have chosen. So the
      // guarantee is structural — a failed debit, a halt and a cancellation
      // can each only change a status.
      final body = bodyOf('sync_mandate_state');
      for (final column in untouchable) {
        expect(
          body,
          isNot(contains('$column =')),
          reason: 'sync_mandate_state must never assign $column',
        );
      }
    });

    test('extend_period is granted to nobody, service_role included', () {
      // The only function in the file that computes a period end. Anything
      // that could call it directly could name one.
      expect(
        sql,
        contains(
          'from public, anon, authenticated, service_role;',
        ),
        reason: 'extend_period must be revoked from service_role too',
      );
      expect(grantsOf('extend_period'), isEmpty);
    });

    test('the mandate table is readable and nothing more', () {
      expect(
        sql,
        contains('grant select on table public.billing_mandates to authenticated;'),
      );
      expect(
        sql,
        contains(
          'revoke all on table public.billing_mandates '
          'from public, anon, authenticated;',
        ),
      );
    });
  });

  group('what the app still cannot reach', () {
    for (final name in const [
      'apply_payment',
      'apply_subscription_charge',
      'sync_mandate_state',
      'revoke_payment',
      'entitlement_of',
      'expire_subscriptions',
      'cancel_subscription_for',
      'resume_subscription_for',
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
        // Most of these *are* granted to `service_role` in section 10, which
        // is the point: the Edge Functions reach them and the app cannot. A
        // regex spanning that distinction is one stray escape away from
        // passing vacuously, so this scans the lines instead.
        for (final line in grantsOf(name)) {
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
