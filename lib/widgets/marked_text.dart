// lib/widgets/marked_text.dart
//
// Two small rich-text helpers the design leans on: `**emphasis**` rendered in
// the brand colour, and phrase highlighting inside Flow's answers.

import 'package:flutter/material.dart';

/// Renders `**spans like this**` in [accentColor] at weight 700.
class MarkedText extends StatelessWidget {
  const MarkedText(
    this.text, {
    super.key,
    required this.style,
    required this.accentColor,
  });

  final String text;
  final TextStyle style;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final parts = text.split('**');
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          for (var i = 0; i < parts.length; i++)
            TextSpan(
              text: parts[i],
              style: i.isOdd
                  ? TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.w700,
                    )
                  : null,
            ),
        ],
      ),
    );
  }
}

/// A phrase to tint inside a longer answer.
typedef Highlight = ({String phrase, Color color});

/// Renders [text], tinting each phrase in [highlights] with a soft wash of
/// its own colour. Phrases that do not occur are ignored.
class HighlightedText extends StatelessWidget {
  const HighlightedText(
    this.text, {
    super.key,
    required this.style,
    this.highlights = const [],
  });

  final String text;
  final TextStyle style;
  final List<Highlight> highlights;

  @override
  Widget build(BuildContext context) {
    if (highlights.isEmpty) return Text(text, style: style);

    // Locate each phrase, then walk the string once emitting plain and
    // highlighted runs in order.
    final marks = <({int start, int end, Color color})>[];
    for (final h in highlights) {
      final i = text.indexOf(h.phrase);
      if (i == -1) continue;
      marks.add((start: i, end: i + h.phrase.length, color: h.color));
    }
    marks.sort((a, b) => a.start.compareTo(b.start));

    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final m in marks) {
      if (m.start < cursor) continue; // overlapping match — skip
      if (m.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, m.start)));
      }
      spans.add(
        TextSpan(
          text: text.substring(m.start, m.end),
          style: TextStyle(
            color: m.color,
            fontWeight: FontWeight.w600,
            backgroundColor: m.color.withValues(alpha: 0.15),
          ),
        ),
      );
      cursor = m.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return Text.rich(TextSpan(style: style, children: spans));
  }
}
