// lib/widgets/sf_primitives.dart
//
// The StudyFlow component library: buttons, chips, cards, tiles, avatars,
// headers, and inputs. Every primitive reads its colours from the theme, so
// each one works unchanged in light and dark.

import 'package:flutter/material.dart';

import '../theme/theme.dart';

// ─── Tones ────────────────────────────────────────────────────────────────

/// The accent families a chip / tile / stat can be tinted with.
enum SfTone { indigo, lavender, emerald, coral, amber, neutral }

typedef ToneColors = ({Color bg, Color fg});

extension SfToneResolve on SfTone {
  /// Resolve to a (wash, ink) pair for the active brightness.
  ToneColors resolve(BuildContext context) {
    final sf = context.sf;
    return switch (this) {
      SfTone.indigo => (bg: sf.indigoSoft, fg: context.scheme.primary),
      SfTone.lavender => (bg: sf.lavenderSoft, fg: sf.violetInk),
      SfTone.emerald => (bg: sf.emeraldSoft, fg: sf.emeraldInk),
      SfTone.coral => (bg: sf.coralSoft, fg: sf.coralInk),
      SfTone.amber => (bg: sf.amberSoft, fg: sf.amberInk),
      SfTone.neutral => (
          bg: context.scheme.surfaceContainerHigh,
          fg: sf.ink2,
        ),
    };
  }
}

// ─── Button ───────────────────────────────────────────────────────────────

enum SfButtonVariant { primary, secondary, ghost, soft, coral, emerald }

enum SfButtonSize { sm, md, lg }

class SfButton extends StatelessWidget {
  const SfButton(
    this.label, {
    super.key,
    this.onPressed,
    this.variant = SfButtonVariant.primary,
    this.size = SfButtonSize.md,
    this.icon,
    this.leading,
    this.trailingIcon,
    this.expand = false,
    this.busy = false,
  });

  /// Icon-only square button. Takes either an [icon] glyph or a [leading]
  /// widget — the Flow orb is painted, not a font character.
  const SfButton.iconOnly({
    super.key,
    this.icon,
    this.leading,
    this.onPressed,
    this.variant = SfButtonVariant.secondary,
    this.size = SfButtonSize.md,
  })  : label = '',
        trailingIcon = null,
        expand = false,
        busy = false,
        assert(icon != null || leading != null, 'give it something to show');

  final String label;
  final VoidCallback? onPressed;
  final SfButtonVariant variant;
  final SfButtonSize size;
  final IconData? icon;

  /// A widget in the leading slot instead of an icon glyph — the Flow orb,
  /// which is a painted thing rather than a font character. Wins over [icon]
  /// when both are set.
  final Widget? leading;

  final IconData? trailingIcon;
  final bool expand;

  /// Swaps the label for a spinner and ignores taps. Keeps the button's own
  /// size so the layout doesn't jump while a request is in flight.
  final bool busy;

  ({double h, double px, double fs, double r, double gap}) get _spec =>
      switch (size) {
        SfButtonSize.sm => (h: 36, px: 14, fs: 13, r: 10, gap: 6),
        SfButtonSize.md => (h: 46, px: 18, fs: 15, r: 12, gap: 8),
        SfButtonSize.lg => (h: 56, px: 22, fs: 16, r: 14, gap: 10),
      };

  ({Color bg, Color fg, Color? border, List<BoxShadow>? shadow}) _style(
      BuildContext context) {
    final sf = context.sf;
    final scheme = context.scheme;
    final dark = context.isDark;

    switch (variant) {
      case SfButtonVariant.primary:
        // In dark mode the deep royal indigo disappears against the canvas,
        // so the button flips to the lifted indigo with dark ink.
        return (
          bg: dark ? scheme.primary : sf.brand,
          fg: dark ? AppColors.textPrimary : Colors.white,
          border: null,
          shadow: dark
              ? null
              : [
                  BoxShadow(
                    color: sf.brand.withValues(alpha: 0.45),
                    blurRadius: 14,
                    spreadRadius: -4,
                    offset: const Offset(0, 4),
                  ),
                ],
        );
      case SfButtonVariant.secondary:
        return (
          bg: scheme.surface,
          fg: scheme.onSurface,
          border: scheme.outline,
          shadow: AppShadows.resolve(AppShadows.sm, Theme.of(context).brightness),
        );
      case SfButtonVariant.ghost:
        return (
          bg: Colors.transparent,
          fg: scheme.onSurface,
          border: null,
          shadow: null
        );
      case SfButtonVariant.soft:
        return (
          bg: sf.indigoSoft,
          fg: scheme.primary,
          border: null,
          shadow: null
        );
      case SfButtonVariant.coral:
        return (
          bg: sf.coral,
          fg: Colors.white,
          border: null,
          shadow: AppShadows.resolve(
              AppShadows.errorGlow, Theme.of(context).brightness),
        );
      case SfButtonVariant.emerald:
        return (
          bg: sf.emerald,
          fg: dark ? AppColors.textPrimary : Colors.white,
          border: null,
          shadow: null
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final spec = _spec;
    final style = _style(context);
    final radius = BorderRadius.circular(spec.r);
    final iconOnly = label.isEmpty;

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leading != null)
          leading!
        else if (icon != null)
          Icon(icon, size: spec.fs + 3, color: style.fg),
        if ((leading != null || icon != null) && !iconOnly)
          SizedBox(width: spec.gap),
        if (!iconOnly)
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTextStyles.fontUi,
                fontSize: spec.fs,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
                color: style.fg,
              ),
            ),
          ),
        if (trailingIcon != null) SizedBox(width: spec.gap),
        if (trailingIcon != null)
          Icon(trailingIcon, size: spec.fs + 3, color: style.fg),
      ],
    );

    final disabled = busy || onPressed == null;

    return Opacity(
      // Dimming rather than recolouring keeps every variant's identity while
      // still reading as unavailable.
      opacity: disabled ? 0.6 : 1,
      child: SizedBox(
        height: spec.h,
        width: expand ? double.infinity : (iconOnly ? spec.h : null),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: style.bg,
            borderRadius: radius,
            border: style.border == null
                ? null
                : Border.all(color: style.border!),
            boxShadow: disabled ? null : style.shadow,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: radius,
            child: InkWell(
              onTap: busy ? null : onPressed,
              borderRadius: radius,
              child: Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: iconOnly ? 0 : spec.px),
                child: busy
                    ? Center(
                        child: SizedBox(
                          width: spec.fs + 3,
                          height: spec.fs + 3,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: style.fg,
                          ),
                        ),
                      )
                    : content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Chip ─────────────────────────────────────────────────────────────────

class SfChip extends StatelessWidget {
  const SfChip(
    this.label, {
    super.key,
    this.tone = SfTone.indigo,
    this.icon,
    this.small = false,
  });

  final String label;
  final SfTone tone;
  final IconData? icon;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final c = tone.resolve(context);
    final h = small ? 22.0 : 26.0;
    final px = small ? 8.0 : 10.0;
    final fs = small ? 11.0 : 12.0;

    return Container(
      height: h,
      padding: EdgeInsets.symmetric(horizontal: px),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: AppRadius.brPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fs + 2, color: c.fg),
            const SizedBox(width: 4),
          ],
          // Flexible so a long label truncates instead of bursting the pill
          // when the chip sits in a constrained row or the text is scaled up.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTextStyles.fontUi,
                fontSize: fs,
                fontWeight: FontWeight.w600,
                color: c.fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Card ─────────────────────────────────────────────────────────────────

class SfCard extends StatelessWidget {
  const SfCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.onLongPress,
    this.color,
    this.gradient,
    this.borderColor,
    this.radius = AppRadius.lg,
    this.clip = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Long-press for a row's secondary actions. The card becomes interactive if
  /// either callback is set, so a long-press-only card still gets its ripple.
  final VoidCallback? onLongPress;
  final Color? color;
  final Gradient? gradient;

  /// Overrides the hairline. For a card that is picked out from its
  /// neighbours — a selected row — rather than for decoration.
  final Color? borderColor;

  final double radius;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final br = BorderRadius.circular(radius);

    Widget body = Padding(padding: padding, child: child);
    if (onTap != null || onLongPress != null) {
      body = Material(
        color: Colors.transparent,
        borderRadius: br,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: br,
          child: body,
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? scheme.surface) : null,
        gradient: gradient,
        borderRadius: br,
        border: Border.all(color: borderColor ?? scheme.outline),
        boxShadow:
            AppShadows.resolve(AppShadows.sm, Theme.of(context).brightness),
      ),
      child: clip ? ClipRRect(borderRadius: br, child: body) : body,
    );
  }
}

// ─── Soft icon tile ───────────────────────────────────────────────────────

/// The tinted rounded square that sits in front of list rows and quick
/// actions throughout the app.
class SoftIconTile extends StatelessWidget {
  const SoftIconTile({
    super.key,
    required this.icon,
    required this.color,
    this.background,
    this.width = 36,
    this.height = 36,
    this.radius = 11,
    this.iconSize = 18,
  });

  final IconData icon;
  final Color color;
  final Color? background;
  final double width;
  final double height;
  final double radius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, size: iconSize, color: color),
    );
  }
}

// ─── Header icon button ───────────────────────────────────────────────────

/// The bordered square button used in screen headers (back, close, settings).
class SfIconButton extends StatelessWidget {
  const SfIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 38,
    this.iconSize = 18,
    this.filled = false,
    this.badge = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;

  /// Solid brand fill instead of the bordered surface treatment.
  final bool filled;

  /// Shows the unread dot in the top-right corner.
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final br = BorderRadius.circular(size * 0.31);

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: filled ? scheme.primary : scheme.surface,
          borderRadius: br,
          border: filled ? null : Border.all(color: scheme.outline),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: br,
          child: InkWell(
            onTap: onPressed,
            borderRadius: br,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  icon,
                  size: iconSize,
                  color: filled
                      ? (context.isDark
                          ? AppColors.textPrimary
                          : scheme.onPrimary)
                      : scheme.onSurface,
                ),
                if (badge)
                  Positioned(
                    top: size * 0.2,
                    right: size * 0.2,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: context.sf.coral,
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.surface, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Avatar ───────────────────────────────────────────────────────────────

class SfAvatar extends StatelessWidget {
  const SfAvatar({
    super.key,
    required this.initials,
    this.size = 38,
    this.background,
    this.foreground,
  });

  final String initials;
  final double size;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background ?? context.sf.indigoSoft,
        shape: BoxShape.circle,
      ),
      child: Text(
        initials,
        style: TextStyle(
          fontFamily: AppTextStyles.fontUi,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.38,
          letterSpacing: -0.2,
          color: foreground ?? context.scheme.primary,
        ),
      ),
    );
  }
}

// ─── Section header ───────────────────────────────────────────────────────

class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.subtitle,
    this.action,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.title.copyWith(color: sf.ink),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: TextStyle(fontSize: 12, color: sf.ink3),
                    ),
                  ),
              ],
            ),
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                action!,
                style: TextStyle(
                  fontFamily: AppTextStyles.fontUi,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.scheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Eyebrow ──────────────────────────────────────────────────────────────

/// The small uppercase mono label that opens most sections.
class SfEyebrow extends StatelessWidget {
  const SfEyebrow(
    this.text, {
    super.key,
    this.color,
    this.size = 11,
    this.tracking = 1.2,
  });

  final String text;
  final Color? color;
  final double size;
  final double tracking;

  @override
  Widget build(BuildContext context) {
    // Uppercasing plus the wide tracking makes this label measurably wider
    // than its source string suggests, and it usually sits next to an icon in
    // a fixed-width card. Scaling down within a bounded slot keeps the whole
    // word — ellipsing a two-word label to fit a fraction of a pixel reads
    // like a bug. Under unbounded width (the common case) this is a no-op.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Text(
        text.toUpperCase(),
        maxLines: 1,
        softWrap: false,
        style: TextStyle(
          fontFamily: AppTextStyles.fontMono,
          fontSize: size,
          fontWeight: FontWeight.w700,
          letterSpacing: tracking,
          color: color ?? context.sf.ink3,
        ),
      ),
    );
  }
}

/// Monospaced supporting text (timings, counts, page references).
class SfMono extends StatelessWidget {
  const SfMono(
    this.text, {
    super.key,
    this.color,
    this.size = 11,
    this.weight = FontWeight.w600,
  });

  final String text;
  final Color? color;
  final double size;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: AppTextStyles.fontMono,
        fontSize: size,
        fontWeight: weight,
        color: color ?? context.sf.ink3,
      ),
    );
  }
}

// ─── Field ────────────────────────────────────────────────────────────────

/// The 54pt rounded input used on the auth screen and in the library.
class SfField extends StatelessWidget {
  const SfField({
    super.key,
    this.controller,
    this.hint,
    this.icon,
    this.trailingIcon,
    this.onTrailingTap,
    this.trailing,
    this.onChanged,
    this.obscure = false,
    this.keyboardType,
  });

  final TextEditingController? controller;
  final String? hint;
  final IconData? icon;
  final IconData? trailingIcon;
  final VoidCallback? onTrailingTap;

  /// A widget in the trailing slot instead of a tappable icon — a spinner or
  /// a validation mark that belongs beside the text it judges. Wins over
  /// [trailingIcon] when both are set.
  final Widget? trailing;

  final ValueChanged<String>? onChanged;
  final bool obscure;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final scheme = context.scheme;

    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: AppRadius.brMd,
        border: Border.all(color: scheme.outline),
      ),
      child: Row(
        children: [
          if (icon != null) Icon(icon, size: 18, color: sf.ink3),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: controller,
                obscureText: obscure,
                keyboardType: keyboardType,
                onChanged: onChanged,
                style: TextStyle(
                  fontFamily: AppTextStyles.fontUi,
                  fontSize: 15,
                  letterSpacing: -0.1,
                  color: sf.ink,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  hintText: hint,
                  hintStyle: TextStyle(
                    fontFamily: AppTextStyles.fontUi,
                    fontSize: 15,
                    color: sf.ink4,
                  ),
                ),
              ),
            ),
          ),
          if (trailing != null)
            trailing!
          else if (trailingIcon != null)
            GestureDetector(
              onTap: onTrailingTap,
              child: Icon(trailingIcon, size: 18, color: sf.ink3),
            ),
        ],
      ),
    );
  }
}

/// Non-editable search affordance (taps would open a search route).
/// A real text field, not a tappable label. It was a styled `Text` from the
/// design import, which looked identical and did nothing.
class SfSearchBar extends StatelessWidget {
  const SfSearchBar({
    super.key,
    required this.hint,
    this.controller,
    this.onChanged,
    this.onClear,
  });

  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  /// Shows a clear button whenever the field is non-empty.
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;

    return Container(
      height: 44,
      padding: const EdgeInsets.only(left: 14, right: 6),
      decoration: BoxDecoration(
        color: context.scheme.surfaceContainerHigh,
        borderRadius: AppRadius.brMd,
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 18, color: sf.ink3),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: TextStyle(
                fontFamily: AppTextStyles.fontUi,
                fontSize: 14,
                color: sf.ink,
              ),
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                hintText: hint,
                hintStyle: TextStyle(fontSize: 14, color: sf.ink3),
              ),
            ),
          ),
          if (controller != null)
            // Rebuilds only the button as you type, rather than the screen.
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller!,
              builder: (context, value, _) => value.text.isEmpty
                  ? const SizedBox(width: 8)
                  : GestureDetector(
                      onTap: onClear,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(Icons.close_rounded,
                            size: 16, color: sf.ink3),
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}
