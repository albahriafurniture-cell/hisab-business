import 'package:flutter/material.dart';

import '../l10n/access_l10n.dart';
import '../l10n/strings.dart';
import '../routes.dart';
import '../theme.dart';
import '../widgets/hb_actions.dart';
import '../widgets/hb_chrome.dart';

/// First-run carousel: 3 pages with original CustomPainter illustrations.
/// Illustrations and copy are written fresh for Hisab Business — no copied
/// artwork or strings from any competitor.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  /// Route name for this screen.
  static const routeName = Routes.onboarding;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pager = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  void _skip() =>
      Navigator.of(context).pushReplacementNamed(Routes.businessSetup);

  void _next() {
    if (_page == 2) {
      Navigator.of(context).pushReplacementNamed(Routes.businessSetup);
    } else {
      _pager.nextPage(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppLocale.current,
      builder: (context, lang, child) => Scaffold(
        appBar: HBAppBar(
          title: accessTr('access.onboarding.title'),
          showBack: false,
          actions: [
            TextButton(
              onPressed: _skip,
              child: Text(accessTr('access.skip'),
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pager,
                  onPageChanged: (i) => setState(() => _page = i),
                  children: const [
                    _OnboardPage(
                      art: _LedgerArt(),
                      titleKey: 'access.onb1.title',
                      bodyKey: 'access.onb1.body',
                    ),
                    _OnboardPage(
                      art: _CashArt(),
                      titleKey: 'access.onb2.title',
                      bodyKey: 'access.onb2.body',
                    ),
                    _OnboardPage(
                      art: _ReminderArt(),
                      titleKey: 'access.onb3.title',
                      bodyKey: 'access.onb3.body',
                    ),
                  ],
                ),
              ),
              _Dots(index: _page, count: 3),
              const SizedBox(height: 20),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: HBPillButton(
                    label: _page == 2
                        ? accessTr('access.getStarted')
                        : accessTr('access.next'),
                    onPressed: _next,
                    color: HBColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardPage extends StatelessWidget {
  final CustomPainter art;
  final String titleKey;
  final String bodyKey;

  const _OnboardPage(
      {required this.art, required this.titleKey, required this.bodyKey});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
              width: 280,
              height: 240,
              child: CustomPaint(painter: art)),
          const SizedBox(height: 36),
          Text(accessTr(titleKey),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(accessTr(bodyKey),
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 15, color: HBColors.muted)),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final int index;
  final int count;

  const _Dots({required this.index, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == index ? 28 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == index ? HBColors.primary : const Color(0xFFE5E3DE),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Original illustrations (CustomPainter compositions). None of this artwork
// comes from any competitor — drawn fresh here.
// ---------------------------------------------------------------------------

/// Page 1: an open ledger card with entry rows and give/get amount pills,
/// plus a "+ person" badge for adding parties.
class _LedgerArt extends CustomPainter {
  const _LedgerArt();
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cardW = 200.0, cardH = 150.0;
    final card = RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx, 120), width: cardW, height: cardH),
        const Radius.circular(14));
    final paint = Paint();

    // card + soft shadow
    paint.color = Colors.black12;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            card.outerRect.translate(0, 6), const Radius.circular(14)),
        paint);
    paint.color = const Color(0xFFFFFFFF);
    canvas.drawRRect(card, paint);

    // header band
    paint.color = HBColors.primarySoft;
    canvas.drawRRect(
        RRect.fromRectAndCorners(card.outerRect,
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14)),
        paint);
    _text(canvas, 'کھاتہ', Offset(cx, 62), 16, HBColors.primaryDeep);

    // entry rows: avatar dot, name line, amount pill (red/green)
    final rows = [
      (70.0, true, '1,250'),
      (95.0, false, '800'),
      (120.0, true, '2,400'),
      (145.0, false, '350'),
    ];
    for (final (y, gave, amt) in rows) {
      paint.color = const Color(0xFFB9B6AE);
      canvas.drawCircle(Offset(cx - 72, y), 7, paint);
      paint.color = const Color(0xFFE5E3DE);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(cx - 58, y - 4, 62, 8),
              const Radius.circular(4)),
          paint);
      paint.color =
          gave ? HBColors.moneyOutSoft : HBColors.moneyInSoft;
      final pill = RRect.fromRectAndRadius(
          Rect.fromLTWH(cx + 16, y - 9, 56, 18),
          const Radius.circular(9));
      canvas.drawRRect(pill, paint);
      _text(canvas, amt, Offset(cx + 44, y),
          10, gave ? HBColors.moneyOutDeep : HBColors.moneyInDeep);
    }

    // "+ person" badge bottom-right
    paint.color = HBColors.moneyIn;
    canvas.drawCircle(Offset(cx + 96, 178), 26, paint);
    paint.color = Colors.white;
    paint.strokeWidth = 4;
    paint.strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx + 96, 168), Offset(cx + 96, 188), paint);
    canvas.drawLine(Offset(cx + 86, 178), Offset(cx + 106, 178), paint);
  }

  void _text(
      Canvas c, String s, Offset o, double fs, Color color) {
    final tp = TextPainter(
        text: TextSpan(
            text: s,
            style: TextStyle(
                fontSize: fs, fontWeight: FontWeight.bold, color: color)),
        textDirection: TextDirection.ltr)
      ..layout();
    tp.paint(c, o - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Page 2: a cash box with coins and in/out arrows, plus a stock crate.
class _CashArt extends CustomPainter {
  const _CashArt();
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final paint = Paint();

    // cash box
    final box = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx - 30, 140), width: 120, height: 84),
        const Radius.circular(12));
    paint.color = Colors.black12;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            box.outerRect.translate(0, 6), const Radius.circular(12)),
        paint);
    paint.color = HBColors.primary;
    canvas.drawRRect(box, paint);
    // slot
    paint.color = const Color(0xFFB23F0E);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(cx - 30, 112), width: 70, height: 10),
            const Radius.circular(5)),
        paint);
    // rupee emblem
    final tp = TextPainter(
        text: const TextSpan(
            text: 'Rs',
            style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        textDirection: TextDirection.ltr)
      ..layout();
    tp.paint(canvas, Offset(cx - 30, 132) - Offset(tp.width / 2, tp.height / 2));

    // coins
    paint.color = const Color(0xFFF5C445);
    for (final (dx, dy, r) in [
      (-2.0, 52.0, 16.0),
      (26.0, 42.0, 12.0),
      (-26.0, 40.0, 10.0),
    ]) {
      canvas.drawCircle(Offset(cx + dx, dy), r, paint);
      paint.color = const Color(0xFFD9A323);
      canvas.drawCircle(Offset(cx + dx, dy), r - 3, paint);
      paint.color = const Color(0xFFF5C445);
    }

    // in/out arrows
    _arrow(canvas, Offset(cx - 120, 200), true); // in (green, down into box)
    _arrow(canvas, Offset(cx + 60, 200), false); // out (red, up)

    // stock crate bottom-right
    paint.color = const Color(0xFFB07845);
    final crate = Rect.fromCenter(
        center: Offset(cx + 82, 150), width: 64, height: 64);
    canvas.drawRRect(
        RRect.fromRectAndRadius(crate, const Radius.circular(8)), paint);
    paint.color = const Color(0xFF8A5A2E);
    paint.strokeWidth = 5;
    canvas.drawLine(crate.topLeft, crate.bottomRight, paint);
    canvas.drawLine(crate.topRight, crate.bottomLeft, paint);
  }

  void _arrow(Canvas canvas, Offset o, bool incoming) {
    final paint = Paint()
      ..color = incoming ? HBColors.moneyIn : HBColors.moneyOut
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final dy = incoming ? 26.0 : -26.0;
    canvas.drawLine(o, o + Offset(0, dy), paint);
    final hx = incoming ? o + Offset(0, 26) : o;
    canvas.drawLine(
        hx, hx + (incoming ? const Offset(-9, -12) : const Offset(-9, 12)),
        paint);
    canvas.drawLine(
        hx, hx + (incoming ? const Offset(9, -12) : const Offset(9, 12)),
        paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Page 3: a reminder bell with sound arcs and a message bubble.
class _ReminderArt extends CustomPainter {
  const _ReminderArt();
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final paint = Paint()..style = PaintingStyle.fill;

    // bell body
    paint.color = HBColors.primary;
    final bell = Path()
      ..moveTo(cx - 42, 150)
      ..cubicTo(cx - 42, 96, cx - 22, 78, cx, 78)
      ..cubicTo(cx + 22, 78, cx + 42, 96, cx + 42, 150)
      ..close();
    canvas.drawPath(bell, paint);
    // bell top knob + clapper
    canvas.drawCircle(Offset(cx, 72), 9, paint);
    paint.color = HBColors.primaryDeep;
    canvas.drawCircle(Offset(cx, 160), 12, paint);

    // sound arcs
    paint
      ..color = HBColors.primarySoft
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    for (final r in [70.0, 92.0]) {
      canvas.drawArc(Rect.fromCircle(center: Offset(cx, 120), radius: r),
          -0.9, 1.8, false, paint);
    }

    // message bubble with "!"
    paint
      ..color = HBColors.moneyIn
      ..style = PaintingStyle.fill;
    final bubble = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx + 78, 62), width: 62, height: 62),
        const Radius.circular(16));
    canvas.drawRRect(bubble, paint);
    final tail = Path()
      ..moveTo(cx + 56, 84)
      ..lineTo(cx + 48, 108)
      ..lineTo(cx + 74, 88)
      ..close();
    canvas.drawPath(tail, paint);
    final tp = TextPainter(
        text: const TextSpan(
            text: '!',
            style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        textDirection: TextDirection.ltr)
      ..layout();
    tp.paint(canvas,
        Offset(cx + 78, 60) - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
