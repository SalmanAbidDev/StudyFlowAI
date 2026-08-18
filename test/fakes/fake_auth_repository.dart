// test/fakes/fake_auth_repository.dart
//
// Stands in for the real repository so widget tests never touch the network.
// Overriding at the repository seam rather than initializing the Supabase
// singleton keeps the tests hermetic — no URL, no key, no HTTP.

import 'dart:async';

import 'package:ai_study_helper/data/repositories/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

User fakeUser() => User(
      id: '00000000-0000-4000-8000-000000000000',
      appMetadata: const {},
      userMetadata: const {'full_name': 'Alex Morgan'},
      aud: 'authenticated',
      email: 'alex.morgan@uni.edu',
      createdAt: DateTime.utc(2026).toIso8601String(),
    );

Session fakeSession() => Session(
      accessToken: 'fake-access-token',
      tokenType: 'bearer',
      user: fakeUser(),
    );

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({bool signedIn = false})
      : _session = signedIn ? fakeSession() : null;

  Session? _session;
  final _controller = StreamController<AuthState>.broadcast();

  @override
  Session? get currentSession => _session;

  @override
  User? get currentUser => _session?.user;

  @override
  Stream<AuthState> get changes async* {
    // Mirrors the real client, which replays the restored session on
    // subscribe before emitting any later changes.
    yield AuthState(
      _session == null
          ? AuthChangeEvent.signedOut
          : AuthChangeEvent.initialSession,
      _session,
    );
    yield* _controller.stream;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    _session = fakeSession();
    _controller.add(AuthState(AuthChangeEvent.signedIn, _session));
  }

  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    _session = fakeSession();
    _controller.add(AuthState(AuthChangeEvent.signedIn, _session));
    return AuthResponse(session: _session, user: _session!.user);
  }

  @override
  Future<void> sendPasswordReset(String email) async {}

  /// The last password accepted, so a test can prove the change reached the
  /// repository rather than only that the sheet closed.
  String? changedPassword;

  @override
  Future<void> updatePassword(String password) async {
    changedPassword = password;
  }

  @override
  Future<void> signOut() async {
    _session = null;
    _controller.add(const AuthState(AuthChangeEvent.signedOut, null));
  }
}
