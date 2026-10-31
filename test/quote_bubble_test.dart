import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shakespeare/domain/models.dart';
import 'package:shakespeare/ui/quote_bubble.dart';

Quote _quote(String id) => Quote(
  id: id,
  text: 'The words of $id.',
  settings: const QuoteSettings(),
  createdAt: DateTime(2026),
);

Future<void> _pumpBubble(
  WidgetTester tester, {
  Quote? quote,
  required bool generating,
  bool reduceMotion = false,
}) => tester.pumpWidget(
  MaterialApp(
    theme: ThemeData.dark(),
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Scaffold(
        body: Center(
          child: SizedBox(
            width: 390,
            height: 480,
            child: QuoteBubble(
              quote: quote,
              generating: generating,
              creatingLabel: 'Writing your quote…',
              animateOrb: false,
            ),
          ),
        ),
      ),
    ),
  ),
);

double _opacity(WidgetTester tester) =>
    tester.widget<Opacity>(find.byKey(const Key('quote-emergence'))).opacity;

bool _quoteIgnoresPointers(WidgetTester tester) => tester
    .widgetList<IgnorePointer>(
      find.ancestor(
        of: find.byKey(const Key('quote-text')),
        matching: find.byType(IgnorePointer),
      ),
    )
    .any((widget) => widget.ignoring);

void main() {
  testWidgets(
    'quote emerges gradually, becomes selectable, and stops animating',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await _pumpBubble(tester, generating: true);
        expect(find.text('Writing your quote…'), findsOneWidget);
        expect(find.byKey(const Key('quote-text')), findsNothing);

        await _pumpBubble(tester, generating: false, quote: _quote('first'));
        final initialOpacity = _opacity(tester);
        expect(initialOpacity, 0);
        expect(_quoteIgnoresPointers(tester), isTrue);
        expect(find.semantics.byValue('The words of first.'), findsNothing);
        expect(find.text('Writing your quote…'), findsNothing);

        // Sample during the emergence, without asserting its curve or total length.
        await tester.pump(const Duration(milliseconds: 500));
        final earlyOpacity = _opacity(tester);
        expect(earlyOpacity, greaterThan(initialOpacity));
        expect(earlyOpacity, lessThan(1));
        await tester.pump(const Duration(milliseconds: 200));
        expect(_opacity(tester), greaterThan(earlyOpacity));

        await tester.pumpAndSettle();
        expect(_opacity(tester), 1);
        expect(_quoteIgnoresPointers(tester), isFalse);
        expect(find.semantics.byValue('The words of first.'), findsOneWidget);
        expect(tester.binding.hasScheduledFrame, isFalse);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'regenerating during emergence hides old words and restarts reveal',
    (tester) async {
      final first = _quote('first');
      await _pumpBubble(tester, generating: true);
      await _pumpBubble(tester, generating: false, quote: first);
      await tester.pump(const Duration(milliseconds: 500));
      final interruptedOpacity = _opacity(tester);
      expect(interruptedOpacity, inExclusiveRange(0, 1));

      // The controller retains the last quote while the next request is pending.
      await _pumpBubble(tester, generating: true, quote: first);
      await tester.pump(const Duration(seconds: 2));
      expect(find.byKey(const Key('quote-text')), findsNothing);
      expect(find.byKey(const Key('quote-emergence')), findsNothing);

      await _pumpBubble(tester, generating: false, quote: _quote('second'));
      expect(find.text('The words of first.'), findsNothing);
      expect(find.text('The words of second.'), findsOneWidget);
      expect(_opacity(tester), lessThan(interruptedOpacity));
      expect(_quoteIgnoresPointers(tester), isTrue);
      await tester.pumpAndSettle();
      expect(_opacity(tester), 1);
      expect(_quoteIgnoresPointers(tester), isFalse);
    },
  );

  testWidgets('reduced motion shows each resolved quote immediately', (
    tester,
  ) async {
    final first = _quote('first');
    await _pumpBubble(tester, generating: true, reduceMotion: true);
    await _pumpBubble(
      tester,
      generating: false,
      quote: first,
      reduceMotion: true,
    );
    expect(_opacity(tester), 1);
    expect(_quoteIgnoresPointers(tester), isFalse);

    await _pumpBubble(
      tester,
      generating: true,
      quote: first,
      reduceMotion: true,
    );
    expect(find.byKey(const Key('quote-text')), findsNothing);
    await _pumpBubble(
      tester,
      generating: false,
      quote: _quote('second'),
      reduceMotion: true,
    );
    expect(find.text('The words of first.'), findsNothing);
    expect(find.text('The words of second.'), findsOneWidget);
    expect(_opacity(tester), 1);
    expect(_quoteIgnoresPointers(tester), isFalse);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('enabling reduced motion completes an in-progress reveal', (
    tester,
  ) async {
    final quote = _quote('first');
    await _pumpBubble(tester, generating: true);
    await _pumpBubble(tester, generating: false, quote: quote);
    await tester.pump(const Duration(milliseconds: 500));
    expect(_opacity(tester), inExclusiveRange(0, 1));

    await _pumpBubble(
      tester,
      generating: false,
      quote: quote,
      reduceMotion: true,
    );
    expect(_opacity(tester), 1);
    expect(_quoteIgnoresPointers(tester), isFalse);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
