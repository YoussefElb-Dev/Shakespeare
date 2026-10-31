import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class LiquidOrb extends StatefulWidget {
  const LiquidOrb({
    super.key,
    this.energy = 0,
    this.hue = 0,
    this.animate = true,
  });
  final double energy;
  final double hue;
  final bool animate;
  @override
  State<LiquidOrb> createState() => _LiquidOrbState();
}

class _LiquidOrbState extends State<LiquidOrb>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _clock = ValueNotifier<double>(0);
  double _elapsed = 0;
  late final Ticker _ticker;
  ui.FragmentShader? _shader;
  Offset _touch = Offset.zero;
  bool _foreground = true;
  bool _enabled = false;
  @override
  void initState() {
    super.initState();
    _ticker = createTicker((time) {
      _clock.value =
          _elapsed + time.inMicroseconds / Duration.microsecondsPerSecond;
    });
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Future<void> _load() async {
    try {
      final program = await ui.FragmentProgram.fromAsset(
        'shaders/liquid_orb.frag',
      );
      if (mounted) setState(() => _shader = program.fragmentShader());
    } on Object {
      // Software fallback also covers unsupported GPUs and widget test renderers.
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant LiquidOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  void _syncAnimation() {
    final enabled =
        widget.animate &&
        _foreground &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.of(context);
    if (enabled == _enabled) return;
    _enabled = enabled;
    if (enabled) {
      _elapsed = _clock.value;
      _ticker.start();
    } else {
      _ticker.stop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (mounted) _syncAnimation();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) => Listener(
          onPointerMove: (event) => setState(
            () => _touch = Offset(
              (event.localPosition.dx / constraints.maxWidth - 0.5) * 2,
              (event.localPosition.dy / constraints.maxHeight - 0.5) * 2,
            ),
          ),
          onPointerUp: (_) => setState(() => _touch = Offset.zero),
          child: CustomPaint(
            painter: _OrbPainter(
              _shader,
              _clock,
              widget.energy,
              widget.hue,
              _touch,
            ),
            size: Size.infinite,
          ),
        ),
      ),
    ),
  );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _clock.dispose();
    _shader?.dispose();
    super.dispose();
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter(this.shader, this.clock, this.energy, this.hue, this.touch)
    : super(repaint: clock);
  final ui.FragmentShader? shader;
  final ValueNotifier<double> clock;
  final double energy;
  final double hue;
  final Offset touch;
  @override
  void paint(Canvas canvas, Size size) {
    final effect = shader;
    if (effect != null) {
      effect.setFloat(0, size.width);
      effect.setFloat(1, size.height);
      effect.setFloat(2, clock.value);
      effect.setFloat(3, energy);
      effect.setFloat(4, touch.dx);
      effect.setFloat(5, touch.dy);
      effect.setFloat(6, hue);
      canvas.drawRect(Offset.zero & size, Paint()..shader = effect);
      return;
    }
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.34;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const RadialGradient(
          colors: [
            Color(0xff090a11),
            Color(0xff181728),
            Color(0xff57557f),
            Color(0xffb8a4d3),
          ],
          stops: [0.0, 0.7, 0.95, 1.0],
        ).createShader(rect),
    );
    for (var i = 0; i < 3; i++) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(clock.value * math.pi / 60 + i * 1.0);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: radius * 1.95,
          height: radius * (1.7 + i * 0.1),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..shader = SweepGradient(
            colors: [
              const Color(0xff7598e9).withValues(alpha: 0.1),
              const Color(0xffd3a49f),
              const Color(0xff8c70c8),
              const Color(0xff7598e9).withValues(alpha: 0.1),
            ],
          ).createShader(rect.shift(-center)),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _OrbPainter old) =>
      old.shader != shader ||
      old.energy != energy ||
      old.hue != hue ||
      old.touch != touch;
}
