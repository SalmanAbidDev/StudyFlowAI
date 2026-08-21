// lib/core/startup_failure_app.dart
//
// What the app shows when it cannot start.
//
// Before this existed, a build with no `--dart-define-from-file` threw in
// `main()` before `runApp()`, so **not one Flutter frame was ever drawn** and
// Android went on showing its launch window — the app icon, forever. That is
// indistinguishable from a freeze, and it cost two separate debugging sessions
// on this project to identify, both times by extracting `libapp.so` from the
// APK and grepping it.
//
// Deliberately built from bare Material widgets and no `SfColors`, no
// `AppTheme`, no provider, no repository. Everything this screen touches is
// something that could itself be the reason the app failed to start.

import 'package:flutter/material.dart';

class StartupFailureApp extends StatelessWidget {
  const StartupFailureApp({
    super.key,
    required this.title,
    required this.detail,
    this.fix,
  });

  /// One line naming what went wrong.
  final String title;

  /// The underlying error, verbatim. Shown rather than summarised: whoever is
  /// looking at this screen is trying to fix it.
  final String detail;

  /// The command that fixes it, when there is one.
  final String? fix;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF14141B),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 40, color: Color(0xFFFF6B7A)),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    detail,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: Color(0xFFB6B6C4),
                    ),
                  ),
                  if (fix != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E2A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF2E2E3E)),
                      ),
                      child: SelectableText(
                        fix!,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          height: 1.5,
                          color: Color(0xFF9FE8C0),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
