import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Hand-painted illustrations for the onboarding screens (sign in, sign up,
/// forgot password, AI consent). Drawn in code so the app ships no image
/// assets and needs no SVG package; each scene paints into a fixed design box
/// and is scaled to fit by [FittedBox].
abstract final class _Ink {
  static const leafDark = Color(0xFF1F5F43);
  static const leafMid = Color(0xFF2F7D5A);
  static const leafLight = Color(0xFF5FA47F);
  static const leafPale = Color(0xFF9CCDB2);
  static const blob = Color(0xFFE1EEE6);
  static const ink = Color(0xFF16241D);
}

void _leaf(
  Canvas c,
  Offset base,
  double deg,
  double len,
  double wid,
  Color a,
  Color b,
) {
  final ang = deg * math.pi / 180;
  final dir = Offset(math.cos(ang), math.sin(ang));
  final nor = Offset(-dir.dy, dir.dx);
  final tip = base + dir * len;
  final mid = base + dir * (len * 0.5);
  final path = Path()
    ..moveTo(base.dx, base.dy)
    ..quadraticBezierTo(
      mid.dx + nor.dx * wid,
      mid.dy + nor.dy * wid,
      tip.dx,
      tip.dy,
    )
    ..quadraticBezierTo(
      mid.dx - nor.dx * wid,
      mid.dy - nor.dy * wid,
      base.dx,
      base.dy,
    );
  c.drawPath(
    path,
    Paint()
      ..shader = LinearGradient(
        colors: [a, b],
      ).createShader(Rect.fromPoints(base, tip).inflate(2)),
  );
  c.drawLine(
    base,
    base + dir * (len * 0.88),
    Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round,
  );
}

void _plant(Canvas c, Offset potBottom, {double s = 1}) {
  final top = potBottom + Offset(0, -34 * s);
  const leaves = <(double, double, double, int)>[
    (-158, 30, 9, 2),
    (-128, 46, 14, 1),
    (-100, 62, 17, 0),
    (-72, 66, 17, 1),
    (-44, 48, 14, 0),
    (-18, 32, 10, 2),
  ];
  for (final l in leaves) {
    final (a, b) = switch (l.$4) {
      0 => (_Ink.leafDark, _Ink.leafMid),
      1 => (_Ink.leafMid, _Ink.leafLight),
      _ => (_Ink.leafLight, _Ink.leafPale),
    };
    _leaf(c, top + Offset(0, 2 * s), l.$1, l.$2 * s, l.$3 * s, a, b);
  }
  final pot = Path()
    ..moveTo(potBottom.dx - 20 * s, top.dy)
    ..lineTo(potBottom.dx + 20 * s, top.dy)
    ..lineTo(potBottom.dx + 15 * s, potBottom.dy)
    ..quadraticBezierTo(
      potBottom.dx,
      potBottom.dy + 3 * s,
      potBottom.dx - 15 * s,
      potBottom.dy,
    )
    ..close();
  c.drawShadow(pot, Colors.black26, 3, false);
  c.drawPath(pot, Paint()..color = const Color(0xFFF6F8F7));
  c.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(potBottom.dx - 22 * s, top.dy - 3 * s, 44 * s, 8 * s),
      Radius.circular(3 * s),
    ),
    Paint()..color = Colors.white,
  );
}

void _blob(Canvas c, Rect r) {
  c.drawOval(r, Paint()..color = _Ink.blob.withValues(alpha: 0.75));
}

void _card(Canvas c, Rect r, {Color color = Colors.white, double rot = 0}) {
  c.save();
  c.translate(r.center.dx, r.center.dy);
  c.rotate(rot * math.pi / 180);
  final rr = RRect.fromRectAndRadius(
    Rect.fromCenter(center: Offset.zero, width: r.width, height: r.height),
    const Radius.circular(9),
  );
  c.drawShadow(Path()..addRRect(rr), Colors.black38, 5, false);
  c.drawRRect(rr, Paint()..color = color);
  c.restore();
}

void _text(
  Canvas c,
  String t,
  Offset o, {
  double size = 9,
  Color color = _Ink.ink,
  FontWeight weight = FontWeight.w500,
  double maxWidth = 100,
  TextAlign align = TextAlign.left,
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: t,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: size,
        color: color,
        fontWeight: weight,
        height: 1.25,
      ),
    ),
    textAlign: align,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: maxWidth);
  tp.paint(c, o);
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.paintScene, this.design);

  final void Function(Canvas) paintScene;
  final Size design;

  @override
  void paint(Canvas canvas, Size size) => paintScene(canvas);

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Widget _scene(Size design, void Function(Canvas) draw) => FittedBox(
  child: SizedBox(
    width: design.width,
    height: design.height,
    child: CustomPaint(painter: _ScenePainter(draw, design)),
  ),
);

/// Sign in: layered cards with a rising line, and a plant.
class SignInIllustration extends StatelessWidget {
  const SignInIllustration({super.key});

  @override
  Widget build(BuildContext context) => _scene(const Size(150, 170), (c) {
    _blob(c, const Rect.fromLTWH(8, 26, 138, 126));
    _card(c, const Rect.fromLTWH(34, 28, 74, 100), rot: 6);
    _card(c, const Rect.fromLTWH(30, 44, 74, 100), rot: -5);
    c.save();
    c.translate(67, 94);
    c.rotate(-5 * math.pi / 180);
    _text(c, 'Small steps,\nbigger goals.', const Offset(-26, -34), size: 8.5);
    final line = Path()
      ..moveTo(-28, 30)
      ..lineTo(-18, 18)
      ..lineTo(-10, 24)
      ..lineTo(0, 8)
      ..lineTo(9, 14)
      ..lineTo(22, -4);
    c.drawPath(
      line,
      Paint()
        ..color = _Ink.leafMid
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    c.restore();
    _plant(c, const Offset(116, 160));
  });
}

/// Sign up: a green card behind a white bar-chart card, and a plant.
class SignUpIllustration extends StatelessWidget {
  const SignUpIllustration({super.key});

  @override
  Widget build(BuildContext context) => _scene(const Size(150, 170), (c) {
    _blob(c, const Rect.fromLTWH(8, 26, 138, 126));
    _card(
      c,
      const Rect.fromLTWH(58, 22, 70, 108),
      color: const Color(0xFF4F8B6C),
      rot: 5,
    );
    _card(c, const Rect.fromLTWH(30, 52, 70, 92), rot: -5);
    c.save();
    c.translate(65, 98);
    c.rotate(-5 * math.pi / 180);
    for (var i = 0; i < 3; i++) {
      final h = 12.0 + i * 8;
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-22 + i * 12, -14 - h, 8, h),
          const Radius.circular(2),
        ),
        Paint()..color = _Ink.leafPale,
      );
    }
    _text(
      c,
      'Better habits.\nBrighter\ntomorrows.',
      const Offset(-26, -2),
      size: 8,
      maxWidth: 60,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-26, 30, 14, 3),
        const Radius.circular(2),
      ),
      Paint()..color = _Ink.leafMid,
    );
    c.restore();
    _plant(c, const Offset(118, 160));
  });
}

/// Forgot password: padlock and password card, and a plant.
class ForgotIllustration extends StatelessWidget {
  const ForgotIllustration({super.key});

  @override
  Widget build(BuildContext context) => _scene(const Size(150, 170), (c) {
    _blob(c, const Rect.fromLTWH(10, 24, 136, 128));
    _plant(c, const Offset(118, 138), s: 0.95);
    final shackle = Paint()
      ..color = const Color(0xFFC3CBC6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    c.drawArc(
      const Rect.fromLTWH(38, 52, 40, 52),
      math.pi,
      math.pi,
      false,
      shackle,
    );
    c.drawLine(const Offset(43, 78), const Offset(43, 96), shackle);
    c.drawLine(const Offset(73, 78), const Offset(73, 96), shackle);
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(28, 92, 60, 50),
      const Radius.circular(10),
    );
    c.drawShadow(Path()..addRRect(body), Colors.black38, 5, false);
    c.drawRRect(body, Paint()..color = const Color(0xFF4F8B6C));
    c.drawCircle(const Offset(58, 114), 5, Paint()..color = Colors.white);
    c.drawRect(
      const Rect.fromLTWH(56.5, 116, 3, 10),
      Paint()..color = Colors.white,
    );
    _card(c, const Rect.fromLTWH(74, 108, 60, 34), rot: -4);
    _text(
      c,
      '****',
      const Offset(88, 113),
      size: 16,
      color: _Ink.leafMid,
      weight: FontWeight.w800,
    );
    final burst = Paint()
      ..color = _Ink.leafMid
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    c.drawLine(const Offset(20, 74), const Offset(28, 80), burst);
    c.drawLine(const Offset(16, 88), const Offset(25, 90), burst);
    c.drawLine(const Offset(24, 60), const Offset(29, 68), burst);
  });
}

/// The assistant robot, drawn in the consent scene's 170x200 design space.
void _robot(Canvas c) {
  final body = RRect.fromRectAndRadius(
    const Rect.fromLTWH(62, 108, 48, 42),
    const Radius.circular(20),
  );
  c.drawShadow(Path()..addRRect(body), Colors.black26, 4, false);
  c.drawRRect(body, Paint()..color = Colors.white);
  final head = RRect.fromRectAndRadius(
    const Rect.fromLTWH(48, 52, 76, 62),
    const Radius.circular(26),
  );
  c.drawShadow(Path()..addRRect(head), Colors.black38, 6, false);
  c.drawRRect(head, Paint()..color = Colors.white);
  c.drawCircle(const Offset(46, 84), 6, Paint()..color = _Ink.leafMid);
  c.drawCircle(const Offset(126, 84), 6, Paint()..color = _Ink.leafMid);
  c.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(56, 60, 60, 42),
      const Radius.circular(18),
    ),
    Paint()..color = _Ink.ink,
  );
  final eye = Paint()
    ..color = const Color(0xFFB6E3CB)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.4
    ..strokeCap = StrokeCap.round;
  c.drawArc(const Rect.fromLTWH(68, 76, 14, 12), math.pi, math.pi, false, eye);
  c.drawArc(const Rect.fromLTWH(90, 76, 14, 12), math.pi, math.pi, false, eye);
  _leaf(c, const Offset(86, 54), -120, 20, 6, _Ink.leafMid, _Ink.leafLight);
  _leaf(c, const Offset(86, 54), -60, 20, 6, _Ink.leafDark, _Ink.leafMid);
  c.save();
  c.translate(70, 138);
  c.rotate(-12 * math.pi / 180);
  final tablet = RRect.fromRectAndRadius(
    const Rect.fromLTWH(-24, -26, 48, 52),
    const Radius.circular(6),
  );
  c.drawShadow(Path()..addRRect(tablet), Colors.black38, 4, false);
  c.drawRRect(tablet, Paint()..color = _Ink.leafMid);
  for (var i = 0; i < 3; i++) {
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-13 + i * 10, 10 - (i + 1) * 9.0, 6, (i + 1) * 9.0),
        const Radius.circular(2),
      ),
      Paint()..color = Colors.white,
    );
  }
  c.restore();
  c.drawCircle(const Offset(96, 132), 7, Paint()..color = Colors.white);
}

/// AI consent: a small friendly assistant holding a chart, with three chips
/// that name the two things the app really uses AI for.
class ConsentIllustration extends StatelessWidget {
  const ConsentIllustration({super.key});

  @override
  Widget build(BuildContext context) => _scene(const Size(170, 200), (c) {
    _blob(c, const Rect.fromLTWH(20, 30, 140, 140));
    void chip(String t, Rect r) {
      final rr = RRect.fromRectAndRadius(r, const Radius.circular(10));
      c.drawShadow(Path()..addRRect(rr), Colors.black26, 3, false);
      c.drawRRect(rr, Paint()..color = Colors.white);
      _text(
        c,
        t,
        Offset(r.left + 8, r.top + 5),
        size: 8.5,
        maxWidth: r.width - 12,
      );
    }

    _robot(c);
    chip('Read my\nreceipts', const Rect.fromLTWH(4, 6, 62, 30));
    chip('Analyze my\nspending', const Rect.fromLTWH(104, 30, 64, 30));
    chip('Suggest\nbudget tips', const Rect.fromLTWH(94, 158, 70, 30));
  });
}

/// The two-leaf brand mark.
class LeafMark extends StatelessWidget {
  const LeafMark({this.size = 32, super.key});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: _scene(const Size(32, 32), (c) {
      _leaf(c, const Offset(4, 28), -62, 28, 9, _Ink.leafLight, _Ink.leafPale);
      _leaf(c, const Offset(9, 29), -30, 24, 8, _Ink.leafDark, _Ink.leafMid);
    }),
  );
}

/// The assistant robot on its own (home AI card).
class AssistantMascot extends StatelessWidget {
  const AssistantMascot({super.key});

  @override
  Widget build(BuildContext context) => _scene(const Size(96, 122), (c) {
    c.translate(-40, -46);
    _robot(c);
  });
}
