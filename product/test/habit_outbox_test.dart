import 'package:flutter_test/flutter_test.dart';
import 'package:tide/services/habits/habit_outbox.dart';

PendingWrite _habit(String id, {String name = 'Walk'}) =>
    PendingWrite.habit({'id': id, 'name': name});

PendingWrite _entry(String habitId, String day, {num? amount}) =>
    PendingWrite.entry({
      'habit_id': habitId,
      'day': day,
      'amount': amount,
      'frozen': false,
    });

void main() {
  test('a later write to a waiting row replaces it where it stands', () {
    final outbox = HabitOutbox()
      ..add(_habit('a'))
      ..add(_entry('a', '2026-09-11', amount: 1))
      ..add(_entry('a', '2026-09-11', amount: 2))
      ..add(_habit('a', name: 'Long walk'));

    expect(outbox.length, 2, reason: 'one write per row');
    expect(
      outbox.writes.first.kind,
      PendingWriteKind.habit,
      reason: 'the habit still goes ahead of its entry',
    );
    expect(outbox.writes.first.row['name'], 'Long walk');
    expect(outbox.writes.last.row['amount'], 2);
  });

  test('the write being sent is never replaced; a newer one waits behind', () {
    final outbox = HabitOutbox()..add(_entry('a', '2026-09-11', amount: 1));
    final sending = outbox.take()!;

    outbox.add(_entry('a', '2026-09-11', amount: 2));

    expect(outbox.length, 2);
    expect(outbox.take(), isNull, reason: 'one request at a time');
    outbox.settle(sending);
    expect(outbox.take()!.row['amount'], 2);
  });

  test('a write that could not be sent stays first in line', () {
    final outbox = HabitOutbox()
      ..add(_habit('a'))
      ..add(_habit('b'));

    final first = outbox.take()!;
    outbox.release(first);

    expect(outbox.take(), same(first));
  });

  test('removing a habit drops what was still waiting for it', () {
    final outbox = HabitOutbox()
      ..add(_habit('a'))
      ..add(_entry('a', '2026-09-10', amount: 1))
      ..add(_entry('b', '2026-09-10', amount: 1))
      ..add(PendingWrite.removal('a'));

    expect(outbox.writes.map((write) => write.key), [
      'entry:b:2026-09-10',
      'habit:a',
    ]);
    expect(outbox.writes.last.kind, PendingWriteKind.removal);
    expect(outbox.holds('entry:a:2026-09-10'), isFalse);
  });

  test('the queue survives being saved and loaded', () {
    final outbox = HabitOutbox()
      ..add(_habit('a'))
      ..add(_entry('a', '2026-09-11', amount: 3))
      ..add(PendingWrite.removal('b'));

    final loaded = HabitOutbox.decode(outbox.encode());

    expect(
      loaded.writes.map((write) => write.key),
      outbox.writes.map((write) => write.key),
    );
    expect(loaded.writes[1].row['amount'], 3);
  });

  test('a damaged queue is dropped rather than left blocking', () {
    expect(HabitOutbox.decode('{not json').isEmpty, isTrue);
    expect(
      HabitOutbox.decode('[{"kind":"teleport","row":{"id":"a"}},'
              '{"kind":"entry","row":{"day":"2026-09-11"}},'
              '{"kind":"habit","row":{"id":"c"}}]')
          .writes
          .map((write) => write.key),
      ['habit:c'],
    );
  });
}
