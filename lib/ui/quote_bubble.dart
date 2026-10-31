import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../domain/models.dart';
import 'liquid_orb.dart';

/// One continuous surface carries the writing pulse into the finished words.
class QuoteBubble extends StatefulWidget {
  const QuoteBubble({
    super.key,
    required this.quote,
    required this.generating,
    required this.creatingLabel,
    required this.animateOrb,
  });

  final Quote? quote;
  final bool generating;
  final String creatingLabel;
  final bool animateOrb;

  @override
  State<QuoteBubble> createState() => _QuoteBubbleState();
}

class _QuoteBubbleState extends State<QuoteBubble>
    with SingleTickerProviderStateMixin {
  late final _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.generating && widget.quote != null) _showQuote();
  }

  @override
  void didUpdateWidget(covariant QuoteBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.generating) {
      _reveal.reset();
    } else if (oldWidget.generating ||
        oldWidget.quote?.id != widget.quote?.id) {
      if (oldWidget.quote?.id != widget.quote?.id) _reveal.reset();
      _showQuote();
    }
  }

  void _showQuote() {
    if (_reduceMotion) {
      _reveal.value = 1;
    } else if (!_reveal.isAnimating && !_reveal.isCompleted) {
      _reveal.forward();
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => AnimatedBuilder(
      animation: _reveal,
      child: !widget.generating && widget.quote != null
          ? _words(widget.quote!)
          : null,
      builder: (context, words) {
        final quote = widget.generating ? null : widget.quote;
        final progress = _reduceMotion ? 1.0 : _reveal.value;
        final emerge = Curves.easeOutCubic.transform(
          ((progress - 0.10) / 0.80).clamp(0.0, 1.0),
        );
        final opacity = Curves.easeInOut.transform(
          ((progress - 0.16) / 0.44).clamp(0.0, 1.0),
        );
        return Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Center(
                child: SizedBox(
                  width: constraints.maxWidth,
                  height: math.min(constraints.maxHeight + 45, 600),
                  child: Transform.scale(
                    scale: 1.18,
                    child: LiquidOrb(
                      key: const Key('creation-orb'),
                      energy: widget.generating ? 1 : 0.12,
                      reveal: quote == null ? 0 : progress,
                      hue: (quote?.settings.category.index ?? 0) * 0.2,
                      animate: widget.animateOrb,
                    ),
                  ),
                ),
              ),
            ),
            if (widget.generating)
              Positioned(
                left: 24,
                right: 24,
                bottom: math.max(8, constraints.maxHeight * 0.04),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    widget.creatingLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.7,
                      color: Color(0xffb7acbf),
                      shadows: [Shadow(color: Colors.black, blurRadius: 12)],
                    ),
                  ),
                ),
              ),
            if (quote != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 44),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: math.max(60, constraints.maxHeight * 0.72),
                  ),
                  child: IgnorePointer(
                    ignoring: progress < 1,
                    child: ExcludeSemantics(
                      excluding: opacity < 1,
                      child: Opacity(
                        key: const Key('quote-emergence'),
                        opacity: opacity,
                        child: Transform.translate(
                          offset: Offset(0, 26 * (1 - emerge)),
                          child: Transform.scale(
                            scale: 0.58 + 0.42 * emerge,
                            child: ImageFiltered(
                              enabled: emerge < 0.99,
                              imageFilter: ui.ImageFilter.blur(
                                sigmaX: 9 * (1 - emerge),
                                sigmaY: 9 * (1 - emerge),
                              ),
                              child: ClipRect(
                                child: Align(
                                  heightFactor: 0.18 + 0.82 * emerge,
                                  child: SingleChildScrollView(child: words),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );

  Widget _words(Quote quote) {
    final language = quote.settings.language;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SelectableText(
          quote.text,
          key: const Key('quote-text'),
          textAlign: TextAlign.center,
          textDirection: language.rtl ? TextDirection.rtl : TextDirection.ltr,
          style: TextStyle(
            fontFamily: language == QuoteLanguage.hebrew
                ? 'Hebrew'
                : language.rtl
                ? 'Naskh'
                : 'Cormorant',
            fontSize: quote.text.length > 350 ? 24 : 29,
            height: language.rtl ? 1.9 : 1.32,
            color: const Color(0xfff4ecf4),
            fontWeight: FontWeight.w400,
            shadows: const [Shadow(color: Colors.black, blurRadius: 12)],
          ),
        ),
        const SizedBox(height: 26),
        Container(width: 30, height: 0.7, color: const Color(0xffb2a3b4)),
      ],
    );
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }
}
