// lib/data/demo_content.dart
//
// What is left here is genuinely static: marketing copy that belongs to the
// build, not to a user. Everything that describes a *person's* study
// materials, plan, decks, quizzes or chat now comes from Supabase — see
// lib/data/repositories.

/// The Free vs Pro comparison on the paywall. `null` means "not included";
/// `true` means a plain check; a string is shown verbatim.
const demoPlanMatrix = <({String label, Object? free, Object? pro})>[
  (label: 'Unlimited AI summaries', free: null, pro: true),
  (label: 'Unlimited Flow chats', free: null, pro: true),
  (label: 'Advanced flashcard decks', free: '3 decks', pro: 'Unlimited'),
  (label: 'Quiz explanations', free: 'Basic', pro: 'Detailed'),
  (label: 'Study plans', free: null, pro: true),
  (label: 'Analytics & focus score', free: null, pro: true),
  (label: 'Priority model', free: null, pro: true),
];
