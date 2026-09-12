import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// One Dart habit that does not survive the trip into TypeScript.
///
/// **Dart joins adjacent string literals; TypeScript does not.** Every long
/// message in `lib/` is written as
///
///     'the first half of a sentence '
///         'and the second half.'
///
/// and in a `.ts` file that is a parse error — `Expected ',', got 'string
/// literal'`. There is nothing to catch it locally: the Edge Functions are Deno
/// and this project has no Deno toolchain, so the first thing that ever reads
/// them is `supabase functions deploy`, which bundles server-side and fails
/// with a 400 several minutes and one context switch later.
///
/// So this reads the sources. A blunt instrument — string matching, not a
/// parser — and the right trade for the same reason `billing_sql_test.dart`
/// makes it: it has one job, and it catches the one mistake somebody writing
/// Dart all day will actually make.
///
/// It is not a substitute for `deno check supabase/functions/*/index.ts`, which
/// is still the real answer and is worth installing Deno for.
void main() {
  const quotes = ['"', "'", '`'];

  /// A line that ends by *joining* to the next one — a comma, a `+`, or an
  /// open bracket — is fine. Only a bare closing quote against a bare opening
  /// quote is the bug.
  final joins = RegExp(r'[,+([{]\s*$');

  List<File> sources() {
    final dir = Directory('supabase/functions');
    expect(
      dir.existsSync(),
      isTrue,
      reason: 'run from the repo root: flutter test',
    );
    return dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.ts'))
        .toList();
  }

  test('no Edge Function relies on Dart string concatenation', () {
    final found = <String>[];

    for (final file in sources()) {
      final lines = file.readAsStringSync().replaceAll('\r', '').split('\n');
      for (var i = 0; i < lines.length - 1; i++) {
        final above = lines[i].trimRight();
        final below = lines[i + 1].trim();
        if (above.isEmpty || below.isEmpty) continue;

        // Comments and doc blocks wrap freely; they are not code.
        final opened = above.trimLeft();
        if (opened.startsWith('//') || opened.startsWith('*')) continue;
        if (below.startsWith('//') || below.startsWith('*')) continue;

        if (!quotes.contains(above[above.length - 1])) continue;
        if (!quotes.contains(below[0])) continue;
        if (joins.hasMatch(above)) continue;

        found.add('${file.path}:${i + 1}\n    $above\n    $below');
      }
    }

    expect(
      found,
      isEmpty,
      reason:
          'these two string literals sit next to each other with nothing '
          'joining them. Dart would concatenate; TypeScript will not parse. '
          'Put a + at the end of the first line:\n\n${found.join('\n\n')}',
    );
  });

  test('there are sources to check, so this cannot pass vacuously', () {
    // The failure mode of every test that scans a directory: the directory
    // moves, nothing is read, and the assertion above passes for ever.
    final names = sources().map((file) => file.uri.pathSegments.last).toSet();
    expect(names, contains('index.ts'));
    expect(sources().length, greaterThanOrEqualTo(7));
  });
}
