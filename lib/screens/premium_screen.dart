// lib/screens/premium_screen.dart
//
// The paywall. No billing is wired up — the CTA just acknowledges the tap.

import 'package:flutter/material.dart';

import '../data/demo_content.dart';
import '../theme/theme.dart';
import '../widgets/widgets.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  bool _yearly = true;

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final scheme = context.scheme;

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Hero(onClose: () => Navigator.of(context).pop()),

          // Billing period
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: AppRadius.brMd,
              ),
              child: Row(
                children: [
                  for (final option in [false, true])
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _yearly = option),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _yearly == option
                                ? scheme.surface
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(11),
                            boxShadow: _yearly == option
                                ? AppShadows.resolve(AppShadows.sm,
                                    Theme.of(context).brightness)
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  option ? 'Yearly' : 'Monthly',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: AppTextStyles.fontUi,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        _yearly == option ? sf.ink : sf.ink3,
                                  ),
                                ),
                              ),
                              if (option) ...[
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: sf.emeraldSoft,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Save 40%',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: sf.emeraldInk,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Selected plan
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: AppRadius.brXl,
                border: Border.all(color: scheme.primary, width: 2),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _yearly ? 'YEARLY · BEST VALUE' : 'MONTHLY',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // scaleDown keeps the price and its unit on one line
                        // at large text scales.
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              _yearly ? '\$5.99' : '\$9.99',
                              style: AppTextStyles.displayXL.copyWith(
                                fontSize: 36,
                                letterSpacing: -1.5,
                                height: 1,
                                color: sf.ink,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '/mo',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: sf.ink3,
                              ),
                            ),
                          ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _yearly
                              ? 'Billed \$71.88 yearly · save \$48'
                              : 'Billed monthly · cancel anytime',
                          style: TextStyle(fontSize: 12, color: sf.ink3),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.surface,
                      border: Border.all(color: scheme.primary, width: 6),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Comparison
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SfEyebrow('What you get', color: sf.ink3),
                const SizedBox(height: 10),
                SfCard(
                  padding: EdgeInsets.zero,
                  clip: true,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            const Spacer(flex: 16),
                            Expanded(
                              flex: 10,
                              child: Center(
                                child: SfEyebrow('Free',
                                    tracking: 0.5, color: sf.ink3),
                              ),
                            ),
                            Expanded(
                              flex: 10,
                              child: Center(
                                child: SfEyebrow('Pro',
                                    tracking: 0.5, color: scheme.primary),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: scheme.outline),
                      for (var i = 0; i < demoPlanMatrix.length; i++) ...[
                        if (i > 0)
                          Divider(height: 1, color: scheme.outline),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 13),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 16,
                                child: Text(
                                  demoPlanMatrix[i].label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: sf.ink2,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 10,
                                child: Center(
                                  child: _MatrixCell(
                                    value: demoPlanMatrix[i].free,
                                    color: sf.ink3,
                                    absentColor: sf.ink4,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 10,
                                child: Center(
                                  child: _MatrixCell(
                                    value: demoPlanMatrix[i].pro,
                                    color: scheme.primary,
                                    absentColor: sf.ink4,
                                    bold: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Testimonial
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 6, 22, 16),
            child: SfCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      for (var i = 0; i < 5; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 2),
                          child: Icon(Icons.star_rounded,
                              size: 14, color: sf.amber),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '"Pulled my GPA from 3.1 to 3.7 in one semester. The '
                    'flashcards literally know what I\'ll forget."',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                      color: sf.ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SfAvatar(
                        initials: 'MK',
                        size: 28,
                        background: sf.lavenderSoft,
                        foreground: sf.violetInk,
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Maya K. · Pre-med, Year 2',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: sf.ink,
                            ),
                          ),
                          Text(
                            'Pro member · 8 months',
                            style: TextStyle(fontSize: 11, color: sf.ink3),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // CTA
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
            child: Column(
              children: [
                SfButton(
                  'Start 7-day free trial',
                  size: SfButtonSize.lg,
                  expand: true,
                  trailingIcon: Icons.arrow_forward_rounded,
                  onPressed: () =>
                      ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Billing is not connected in this build'),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'No charge today. Cancel anytime in Settings.',
                  style: TextStyle(fontSize: 11, color: sf.ink3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final topInset = MediaQuery.paddingOf(context).top;

    return ClipRect(
      child: Container(
        padding: EdgeInsets.fromLTRB(24, topInset + 20, 24, 30),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomRight,
            colors: sf.brandSweep,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -100,
              right: -80,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
            ),
            Positioned(
              bottom: -90,
              left: -60,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: sf.lavender.withValues(alpha: 0.25),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: AppRadius.brPill,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star_rounded, size: 13, color: sf.streak),
                          const SizedBox(width: 6),
                          const SfEyebrow('StudyFlow Pro',
                              tracking: 1, color: Colors.white),
                        ],
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: onClose,
                      child: Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(Icons.close_rounded,
                            size: 18, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Study smarter.\nPass faster.',
                  style: AppTextStyles.displayXL.copyWith(
                    fontSize: 36,
                    letterSpacing: -1.4,
                    height: 1.05,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: Text.rich(
                    TextSpan(
                      text: 'Unlock unlimited Flow, advanced decks, and '
                          'AI-built study plans. ',
                      children: [
                        TextSpan(
                          text: '7 days free',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: sf.streak,
                          ),
                        ),
                        const TextSpan(text: ', then cancel anytime.'),
                      ],
                    ),
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MatrixCell extends StatelessWidget {
  const _MatrixCell({
    required this.value,
    required this.color,
    required this.absentColor,
    this.bold = false,
  });

  final Object? value;
  final Color color;
  final Color absentColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    if (value == null) {
      return Icon(Icons.close_rounded, size: 15, color: absentColor);
    }
    if (value == true) {
      return Icon(Icons.check_rounded, size: 16, color: color);
    }
    return Text(
      value.toString(),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 12,
        fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
        color: color,
      ),
    );
  }
}
