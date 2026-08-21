// test/query_conventions_test.dart
//
// A source-level invariant, not a behaviour test.
//
// postgrest-dart declares `order(String column, {bool ascending = false, ...})`
// — the default is **descending**. So `.order('created_at')` reads like "oldest
// first" and does the opposite. It shipped that way in the chat: the transcript
// was correct while you typed, because each message was appended locally, and
// loaded back-to-front the moment the screen was reopened and the rows were
// re-read.
//
// The fakes cannot catch this. They return their backing list, so every test in
// the suite sees the order the repository *meant*, never the order PostgREST
// would actually return. The only place the mistake is visible is the source
// itself — so that is what is checked here.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Strips `//` comments so a line *describing* the trap does not trip it.
String _stripComments(String source) => source
    .split('\n')
    .map((line) {
      final i = line.indexOf('//');
      return i == -1 ? line : line.substring(0, i);
    })
    .join('\n');

void main() {
  test('every .order() states its direction', () {
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = _stripComments(entity.readAsStringSync());

      // `.order(` up to the closing paren of its argument list. The arguments
      // never contain a nested paren in this codebase, which keeps this a
      // regex rather than a parser.
      for (final match in RegExp(r'\.order\(([^)]*)\)').allMatches(source)) {
        final args = match.group(1)!;
        if (args.contains('ascending:')) continue;
        final line = '\n'.allMatches(source.substring(0, match.start)).length + 1;
        offenders.add('${entity.path.replaceAll(r'\', '/')}:$line'
            '  .order($args)');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'postgrest-dart defaults `ascending` to FALSE, so a bare '
          '.order(column) sorts descending — usually the opposite of what the '
          'call reads as. Pass ascending: explicitly:\n  '
          '${offenders.join('\n  ')}\n',
    );
  });
}
