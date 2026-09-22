import 'package:flutter/material.dart';

import '../../../core/theme/insets.dart';
import 'auth_illustrations.dart';

/// Shared pieces for the onboarding screens (sign in, sign up, forgot
/// password, AI consent), matched to the approved mockups: leaf-mark brand
/// row, a headline with an illustration beside it, and a wave footer.

/// Circular back button. Inline with the page content, not in a title bar.
class AuthBackButton extends StatelessWidget {
  const AuthBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => Navigator.of(context).maybePop(),
        child: SizedBox(
          width: Insets.minTapTarget,
          height: Insets.minTapTarget,
          child: Icon(Icons.arrow_back, color: scheme.onSurface, size: 20),
        ),
      ),
    );
  }
}

/// Leaf mark + green "Spendify" wordmark. The tagline sits to the right on
/// the same row ([taglineBelow] false) or under the wordmark ([taglineBelow]
/// true), as in the different mockups.
class AuthBrandRow extends StatelessWidget {
  const AuthBrandRow({
    this.tagline,
    this.taglineBelow = false,
    this.alignEnd = false,
    super.key,
  });

  final String? tagline;
  final bool taglineBelow;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final mark = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const LeafMark(size: 34),
        const SizedBox(width: Insets.sm),
        Text(
          'Spendify',
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: scheme.primary,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
    final tag = tagline == null
        ? null
        : Text(
            tagline!,
            textAlign: alignEnd ? TextAlign.right : TextAlign.left,
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          );
    if (tag == null) return mark;
    if (taglineBelow || alignEnd) {
      return Column(
        crossAxisAlignment: alignEnd
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: <Widget>[
          mark,
          const SizedBox(height: Insets.xs),
          tag,
        ],
      );
    }
    return Row(
      children: <Widget>[
        mark,
        const SizedBox(width: Insets.sm),
        Expanded(child: tag),
      ],
    );
  }
}

/// Headline block with an illustration to its right. When the user has
/// scaled text up, the illustration is dropped so the words keep the whole
/// width (large-text accessibility).
class AuthHero extends StatelessWidget {
  const AuthHero({
    required this.text,
    required this.illustration,
    this.illustrationWidth = 140,
    super.key,
  });

  final Widget text;
  final Widget illustration;
  final double illustrationWidth;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
    if (scale >= 1.35) return text;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(child: text),
        const SizedBox(width: Insets.sm),
        SizedBox(
          width: illustrationWidth,
          height: illustrationWidth * 1.15,
          child: illustration,
        ),
      ],
    );
  }
}

class _WaveClipper extends CustomClipper<Path> {
  const _WaveClipper();

  @override
  Path getClip(Size s) {
    final p = Path()..moveTo(0, s.height * 0.32);
    p.cubicTo(
      s.width * 0.22,
      0,
      s.width * 0.42,
      s.height * 0.5,
      s.width * 0.68,
      s.height * 0.22,
    );
    p.cubicTo(
      s.width * 0.84,
      s.height * 0.05,
      s.width * 0.94,
      s.height * 0.12,
      s.width,
      s.height * 0.18,
    );
    p
      ..lineTo(s.width, s.height)
      ..lineTo(0, s.height)
      ..close();
    return p;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Soft wave at the bottom of the page with the leaf mark and a tagline.
class AuthFooterBand extends StatelessWidget {
  const AuthFooterBand({required this.tagline, super.key});

  final String tagline;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return ClipPath(
      clipper: const _WaveClipper(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(
          Insets.md,
          Insets.xl + Insets.md,
          Insets.md,
          Insets.lg,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              scheme.primaryContainer,
              scheme.primaryContainer.withValues(alpha: 0.5),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const LeafMark(size: 26),
            const SizedBox(height: Insets.xs),
            Text(
              tagline,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
