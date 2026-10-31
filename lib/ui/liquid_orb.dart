import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class LiquidOrb extends StatefulWidget {
  const LiquidOrb({
    super.key,
    this.energy = 0,
    this.hue = 0,
    this.reveal = 0,
    this.animate = true,
  });

  /// Generation intensity, from a flowing idle (0) to an active churn (1).
  final double energy;
  final double hue;

  /// Parent-driven quote emergence: 0 at rest, 0..1 for a bloom and ripple.
  /// The effect fades completely at 1; this widget does not animate the text.
  final double reveal;
  final bool animate;
  @override
  State<LiquidOrb> createState() => _LiquidOrbState();
}

class _LiquidOrbState extends State<LiquidOrb>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final ValueNotifier<_OrbFrame> _frame;
  late final Ticker _ticker;
  Duration? _lastTick;
  ui.FragmentShader? _shader;
  Offset _targetTouch = Offset.zero;
  double _targetPressure = 0;
  int? _activePointer;
  bool _foreground = true;
  bool _enabled = false;
  @override
  void initState() {
    super.initState();
    _frame = ValueNotifier(_OrbFrame(energy: _unit(widget.energy)));
    _ticker = createTicker(_tick);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  void _tick(Duration elapsed) {
    final previous = _lastTick;
    _lastTick = elapsed;
    if (previous == null) return;
    // Ignore time spent paused, and avoid a jump after a delayed frame.
    final dt =
        ((elapsed - previous).inMicroseconds / Duration.microsecondsPerSecond)
            .clamp(0.0, 0.05);
    final frame = _frame.value;
    final energy = ui.lerpDouble(
      frame.energy,
      _unit(widget.energy),
      1 - math.exp(-dt * 4.5),
    )!;
    _frame.value = _OrbFrame(
      // Integrate speed instead of multiplying elapsed time by energy: changing
      // generation intensity must not jump the phase of the liquid.
      time: frame.time + dt * (0.78 + (frame.energy + energy) * 1.35),
      energy: energy,
      touch: Offset.lerp(frame.touch, _targetTouch, 1 - math.exp(-dt * 10))!,
      pressure: ui.lerpDouble(
        frame.pressure,
        _targetPressure,
        1 - math.exp(-dt * 8),
      )!,
    );
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
    if (enabled) {
      if (!_enabled) {
        _enabled = true;
        _lastTick = null;
        _ticker.start();
      }
      return;
    }
    if (_enabled) {
      _enabled = false;
      _ticker.stop();
      _lastTick = null;
      _activePointer = null;
      _targetTouch = Offset.zero;
      _targetPressure = 0;
    }
    _updateStillFrame();
  }

  void _updateStillFrame() {
    if (_enabled) return;
    final frame = _frame.value;
    final energy = _unit(widget.energy);
    if (frame.energy == energy &&
        frame.touch == _targetTouch &&
        frame.pressure == _targetPressure) {
      return;
    }
    // Static/reduced-motion updates never start a ticker, including on touch.
    _frame.value = _OrbFrame(
      time: frame.time,
      energy: energy,
      touch: _targetTouch,
      pressure: _targetPressure,
    );
  }

  void _moveTouch(Offset position, Size size) {
    if (!size.isFinite || size.isEmpty) return;
    _targetTouch = Offset(
      (position.dx / size.width * 2 - 1).clamp(-1.0, 1.0),
      (position.dy / size.height * 2 - 1).clamp(-1.0, 1.0),
    );
    _targetPressure = 1;
    _updateStillFrame();
  }

  void _releaseTouch(int pointer) {
    if (pointer != _activePointer) return;
    _activePointer = null;
    _targetTouch = Offset.zero;
    _targetPressure = 0;
    _updateStillFrame();
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
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) {
            if (_activePointer != null) return;
            _activePointer = event.pointer;
            _moveTouch(event.localPosition, constraints.biggest);
          },
          onPointerMove: (event) {
            if (_activePointer != event.pointer) return;
            _moveTouch(event.localPosition, constraints.biggest);
          },
          onPointerUp: (event) => _releaseTouch(event.pointer),
          onPointerCancel: (event) => _releaseTouch(event.pointer),
          child: CustomPaint(
            painter: _OrbPainter(
              _shader,
              _frame,
              widget.hue.isFinite ? widget.hue : 0,
              _unit(widget.reveal),
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
    _frame.dispose();
    _shader?.dispose();
    super.dispose();
  }
}

double _unit(double value) => value.isFinite ? value.clamp(0.0, 1.0) : 0;

class _OrbFrame {
  const _OrbFrame({
    this.time = 0,
    required this.energy,
    this.touch = Offset.zero,
    this.pressure = 0,
  });

  final double time;
  final double energy;
  final Offset touch;
  final double pressure;
}

class _OrbPainter extends CustomPainter {
  _OrbPainter(this.shader, this.frame, this.hue, this.reveal)
    : super(repaint: frame);
  final ui.FragmentShader? shader;
  final ValueNotifier<_OrbFrame> frame;
  final double hue;
  final double reveal;
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || !size.isFinite) return;
    final motion = frame.value;
    final effect = shader;
    if (effect != null) {
      // Float slots must match the declaration order in liquid_orb.frag:
      // size(0..1), time(2), energy(3), touch(4..5), hue(6), reveal(7), pressure(8).
      effect.setFloat(0, size.width);
      effect.setFloat(1, size.height);
      effect.setFloat(2, motion.time);
      effect.setFloat(3, motion.energy);
      effect.setFloat(4, motion.touch.dx);
      effect.setFloat(5, motion.touch.dy);
      effect.setFloat(6, hue);
      effect.setFloat(7, reveal);
      effect.setFloat(8, motion.pressure);
      canvas.drawRect(Offset.zero & size, Paint()..shader = effect);
      return;
    }
    _paintFallback(canvas, size, motion);
  }

  void _paintFallback(Canvas canvas, Size size, _OrbFrame motion) {
    final t = motion.time;
    final energy = motion.energy;
    // Concentrate the release in the first ~600 ms of a 1600 ms reveal.
    final emergence = (reveal / 0.58).clamp(0.0, 1.0);
    final rest = 1 - emergence;
    final bloom = 9.48148 * emergence * rest * rest * rest;
    final scale = size.shortestSide / 2.6;
    final center =
        size.center(Offset.zero) +
        Offset(math.sin(t * 0.47), math.cos(t * 0.39)) * (scale * 0.012) +
        motion.touch * (motion.pressure * scale * 0.055);
    final radius = 0.86 - energy * 0.055 + bloom * 0.028;
    final rect = Rect.fromCircle(center: center, radius: scale * radius);

    Path contour(double Function(double angle) radiusAt) {
      final path = Path();
      for (var i = 0; i < 96; i++) {
        final a = i * math.pi * 2 / 96;
        final r = radiusAt(a) * scale;
        final point = center + Offset(math.cos(a), math.sin(a)) * r;
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      return path..close();
    }

    double surface(double a) =>
        radius +
        (0.015 + energy * 0.008) * math.sin(t * 1.45) +
        (0.048 + energy * 0.026) *
            math.sin(a * 3 + t * 0.86 + 0.45 * math.sin(a * 2 - t * 0.42)) +
        (0.027 + energy * 0.020) * math.sin(a * 5 - t * 0.73) +
        (0.020 + energy * 0.012) * math.cos(a * 2 + t * 0.51) +
        (0.008 + energy * 0.012) * math.sin(a * 7 + t * 1.16) +
        motion.pressure *
            0.025 *
            (math.cos(a) * motion.touch.dx + math.sin(a) * motion.touch.dy);

    final shell = contour(surface);
    final rim = SweepGradient(
      transform: GradientRotation(t * 0.19 + hue),
      colors: const [
        Color(0xff7899ef),
        Color(0xffaf87d8),
        Color(0xffefb39f),
        Color(0xff9d7edb),
        Color(0xff7899ef),
      ],
    ).createShader(rect);
    canvas.drawPath(
      shell,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = scale * (0.035 + energy * 0.020 + bloom * 0.04)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, scale * 0.055)
        ..color = Color.fromRGBO(
          159,
          149,
          235,
          0.36 + energy * 0.18 + bloom * 0.2,
        ),
    );
    canvas.drawPath(
      shell,
      Paint()
        ..shader = const RadialGradient(
          colors: [
            Color(0xff080a11),
            Color(0xff0c101c),
            Color(0xff292a49),
            Color(0xff77729d),
          ],
          stops: [0.0, 0.6, 0.86, 1.0],
        ).createShader(rect),
    );
    canvas.save();
    canvas.clipPath(shell);
    for (var i = 0; i < 3; i++) {
      final fold = contour(
        (a) =>
            surface(a) *
            (0.70 +
                i * 0.085 +
                0.065 * math.sin(a * 2 + t * (0.60 + i * 0.08) + i * 1.8) +
                0.03 * math.sin(a * 3 - t * 0.7 + i)),
      );
      canvas.drawPath(
        fold,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = scale * (0.014 + i * 0.005 + energy * 0.004)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, scale * 0.009)
          ..shader = SweepGradient(
            transform: GradientRotation(-t * 0.35 + i * 1.8 + hue),
            colors: [
              const Color(0xff7598e9).withValues(alpha: 0.02),
              const Color(0xffd3a49f).withValues(alpha: 0.5 + energy * 0.2),
              const Color(0xff8c70c8).withValues(alpha: 0.3),
              const Color(0xff7598e9).withValues(alpha: 0.02),
            ],
          ).createShader(rect),
      );
    }
    canvas.restore();
    canvas.drawPath(
      shell,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = scale * (0.012 + energy * 0.006 + bloom * 0.008)
        ..shader = rim,
    );
    if (bloom > 0) {
      canvas.drawCircle(
        center,
        scale * (0.54 + emergence * 0.58),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = scale * 0.024
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, scale * 0.025)
          ..color = Color.fromRGBO(202, 190, 250, bloom * 0.5),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OrbPainter old) =>
      old.shader != shader ||
      old.frame != frame ||
      old.hue != hue ||
      old.reveal != reveal;
}
