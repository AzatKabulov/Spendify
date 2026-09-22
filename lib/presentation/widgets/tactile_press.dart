import 'package:flutter/material.dart';

import '../../core/theme/insets.dart';

/// The signature motion of "The Instrument" (Phase 12 redesign): a control
/// depresses slightly on touch and releases with a decisive, weighted snap —
/// like a real key, not a flat ripple.
///
/// Wraps [child] purely for the visual press feedback via [Listener], which
/// observes pointer events without joining the gesture arena — [child] keeps
/// handling its own tap exactly as before (its `onPressed`/`onTap` is
/// untouched), so wrapping a button in this does not change what receives
/// the tap, only how it looks while pressed.
///
/// Used on the app's two highest-frequency touches — the home FAB and the
/// primary Save/Add button on every form — so the single most-repeated
/// interaction gets the authored motion, rather than scattering a press
/// effect over everything.
class TactilePress extends StatefulWidget {
  const TactilePress({required this.child, super.key});

  final Widget child;

  @override
  State<TactilePress> createState() => _TactilePressState();
}

class _TactilePressState extends State<TactilePress> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: _pressed ? AppMotion.quick : AppMotion.standard,
        curve: _pressed ? Curves.easeOut : AppMotion.pressRelease,
        child: widget.child,
      ),
    );
  }
}
