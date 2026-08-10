// lib/data/models/summary_section.dart

class SummarySection {
  const SummarySection({
    required this.id,
    required this.title,
    required this.read,
    required this.bullets,
  });

  factory SummarySection.fromRow(Map<String, dynamic> row) => SummarySection(
        id: row['id'] as String,
        title: row['title'] as String,
        read: (row['read'] as bool?) ?? false,
        bullets: ((row['bullets'] as List?) ?? const [])
            .map((b) => b as String)
            .toList(),
      );

  final String id;
  final String title;
  final bool read;

  /// `**bold**` spans are rendered in the brand colour.
  final List<String> bullets;
}
