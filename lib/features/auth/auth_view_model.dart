// lib/features/auth/auth_view_model.dart

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/view_models.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/supabase_providers.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider)),
);

/// The live auth stream. Everything that cares whether someone is signed in
/// watches this rather than reading `currentSession` directly, so a token
/// refresh or a sign-out on another screen propagates on its own.
final authChangesProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(authRepositoryProvider).changes,
);

/// Null when signed out. Falls back to the restored session for the first
/// frame, before the stream has emitted.
final sessionProvider = Provider<Session?>((ref) {
  final event = ref.watch(authChangesProvider);
  return event.hasValue
      ? event.value!.session
      : ref.watch(authRepositoryProvider).currentSession;
});

final isSignedInProvider = Provider<bool>(
  (ref) => ref.watch(sessionProvider) != null,
);

/// Whether the password field is masked.
final passwordObscuredProvider =
    NotifierProvider.autoDispose<FlagViewModel, bool>(
  () => FlagViewModel(initial: true),
);

/// Sign-in vs. create-account on the one screen.
enum AuthMode { signIn, signUp }

final authModeProvider =
    NotifierProvider.autoDispose<ValueViewModel<AuthMode>, AuthMode>(
  () => ValueViewModel(AuthMode.signIn),
);

/// Drives the submit button: `isLoading` disables it, `error` renders under
/// the form. The value itself is meaningless — this models the *request*, not
/// the session. Session state lives in [sessionProvider].
class AuthController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Returns true when the credentials were accepted, so the caller knows
  /// whether to navigate. Errors are surfaced through [state], not thrown.
  Future<bool> submit({
    required AuthMode mode,
    required String email,
    required String password,
    String fullName = '',
  }) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty || password.isEmpty) {
      state = AsyncError(
        const AuthFailure('Enter your email and password.'),
        StackTrace.current,
      );
      return false;
    }

    state = const AsyncLoading();
    final repo = ref.read(authRepositoryProvider);

    try {
      if (mode == AuthMode.signIn) {
        await repo.signIn(email: trimmedEmail, password: password);
      } else {
        final response = await repo.signUp(
          email: trimmedEmail,
          password: password,
          fullName: fullName.trim(),
        );
        // With email confirmation switched on, sign-up returns a user but no
        // session. Say so rather than dropping the user on a shell they are
        // not actually authenticated for.
        if (response.session == null) {
          state = AsyncError(
            const AuthFailure(
              'Check your inbox to confirm your address, then sign in.',
            ),
            StackTrace.current,
          );
          return false;
        }
      }
      state = const AsyncData(null);
      return true;
    } on AuthException catch (error, stack) {
      state = AsyncError(AuthFailure(error.message), stack);
      return false;
    } catch (error, stack) {
      state = AsyncError(
        const AuthFailure("Couldn't reach the server. Check your connection."),
        stack,
      );
      // Keep the real error in the log; the user gets the readable version.
      Zone.current.handleUncaughtError(error, stack);
      return false;
    }
  }

  Future<void> signOut() => ref.read(authRepositoryProvider).signOut();
}

final authControllerProvider =
    AsyncNotifierProvider.autoDispose<AuthController, void>(
  AuthController.new,
);

/// A message already fit to show a user. Wrapping [AuthException] keeps
/// Supabase's wording out of the widget layer.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
