// lib/core/config/ai_config.dart
//
// Where the AI lives, and — deliberately — where its key does *not*.
//
// **There is no API key in this file, and none anywhere else in the app.**
// Everything goes through the `ai` Supabase Edge Function, which holds the
// Gemini key as a server-side secret. That is not caution for its own sake:
// earlier in this project we pulled the Supabase project URL straight out of a
// release APK with `grep` on `libapp.so`. A key compiled into the binary comes
// out the same way, and anyone holding it can spend against the account until
// it is rotated.
//
// ── Setting the key (once) ────────────────────────────────────────────────
// Supabase dashboard → Edge Functions → Secrets → add:
//
//     GEMINI_API_KEY = <your key>
//
// Nothing needs rebuilding afterwards; the function reads it per request.
//
// The function source is at `supabase/functions/ai/index.ts`, and the model
// and daily chat allowance are set there — changing either is a redeploy, not
// an app release.

class AiConfig {
  const AiConfig._();

  /// The Edge Function the app invokes. Not a URL: the Supabase client builds
  /// it from the project it is already configured with.
  static const functionName = 'ai';

  /// How many questions Flow answers per person per day.
  ///
  /// Mirrored from the function purely so the UI can show "2 of 5 left"
  /// without a round trip. **The function is what actually enforces it** —
  /// this number being wrong would misreport the count, not lift the cap.
  static const dailyChatLimit = 5;

  /// How many cards and questions one generation asks for.
  static const generatedItemCount = 4;
}
