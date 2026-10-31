import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shakespeare/data/app_controller.dart';
import 'package:shakespeare/data/quote_service.dart';
import 'package:shakespeare/domain/models.dart';
import 'package:shakespeare/main.dart';
import 'package:shakespeare/ui/liquid_orb.dart';

class _PendingQuote {
  _PendingQuote(this.settings, this.previous);

  final QuoteSettings settings;
  final String? previous;
  final result = Completer<Quote>();

  void succeed(String id) => result.complete(
    Quote(
      id: id,
      text: 'Words from $id.',
      settings: settings,
      createdAt: DateTime(2026),
    ),
  );
}

class _ControlledService implements QuoteService {
  final requests = <_PendingQuote>[];

  @override
  Future<Quote> generate(QuoteSettings settings, {String? previous}) {
    final request = _PendingQuote(settings, previous);
    requests.add(request);
    return request.result.future;
  }

  @override
  void dispose() {}
}

class InstantService implements QuoteService {
  @override
  Future<Quote> generate(QuoteSettings settings, {String? previous}) async =>
      Quote(
        id: 'quote-1',
        text: settings.language == QuoteLanguage.hebrew
            ? 'כאן הלב שלי בבית.'
            : 'You are the calm my restless heart always returns to.',
        settings: settings,
        createdAt: DateTime(2026),
      );
  @override
  void dispose() {}
}

void main() {
  Future<AppController> launch(
    WidgetTester tester, {
    Size size = const Size(393, 852),
    double textScale = 1,
    QuoteService? service,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    SharedPreferences.setMockInitialValues({});
    final controller = AppController(
      await SharedPreferences.getInstance(),
      service ?? InstantService(),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ShakespeareApp(controller: controller, animateOrb: false),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  Future<void> customize(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('categories')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Romance'));
    await tester.pumpAndSettle();
  }

  Future<void> generate(WidgetTester tester) async {
    await customize(tester);
    await tester.tap(find.byKey(const Key('generate')));
    await tester.pumpAndSettle();
  }

  EditableText editable(WidgetTester tester, Finder field) =>
      tester.widget<EditableText>(
        find.descendant(of: field, matching: find.byType(EditableText)),
      );

  Future<void> focusAndTapInside(
    WidgetTester tester,
    Finder field, {
    String text = 'A quiet morning',
  }) async {
    await tester.ensureVisible(field);
    await tester.enterText(field, text);
    await tester.pump();
    final focus = editable(tester, field).focusNode;
    expect(focus.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.tap(field);
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
  }

  testWidgets('create, favorite, copy, and reopen a quote from the library', (
    tester,
  ) async {
    final app = await launch(tester);
    String? copied;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        });
    expect(find.text('Shakespeare'), findsNothing);
    await tester.tap(find.byKey(const Key('categories')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Romance'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('generate')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quote-text')), findsOneWidget);
    await tester.tap(find.byKey(const Key('favorite')));
    await tester.pumpAndSettle();
    expect(app.favorites, hasLength(1));
    await tester.tap(find.byTooltip('Copy quote'));
    await tester.pumpAndSettle();
    expect(copied, app.current!.text);
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Favorites'));
    await tester.pumpAndSettle();
    expect(find.text(app.current!.text), findsOneWidget);
    await tester.tap(find.text(app.current!.text));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('regenerate')), findsOneWidget);
  });

  testWidgets('Hebrew selection mirrors the UI and the generated quote', (
    tester,
  ) async {
    final app = await launch(tester);
    await tester.tap(find.byKey(const Key('categories')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Romance'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Hebrew');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hebrew', findRichText: false).last);
    await tester.pumpAndSettle();
    expect(app.settings.language, QuoteLanguage.hebrew);
    expect(find.text('יצירת ציטוט'), findsOneWidget);
    final generateContext = tester.element(find.byKey(const Key('generate')));
    expect(Directionality.of(generateContext), TextDirection.rtl);
    await tester.tap(find.byKey(const Key('generate')));
    await tester.pumpAndSettle();
    final quote = tester.widget<SelectableText>(
      find.byKey(const Key('quote-text')),
    );
    expect(quote.textDirection, TextDirection.rtl);
    expect(tester.takeException(), isNull);
  });

  testWidgets('small screen and large text remain usable', (tester) async {
    await launch(tester, size: const Size(320, 640), textScale: 1.5);
    await tester.tap(find.byKey(const Key('categories')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Romance'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('generate')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quote-text')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending, resolved, and regenerated quotes keep the same orb', (
    tester,
  ) async {
    final service = _ControlledService();
    final app = await launch(tester, service: service);
    await generate(tester);

    final orb = find.byKey(const Key('creation-orb'));
    final originalState = tester.state(orb);
    final pendingEnergy = tester.widget<LiquidOrb>(orb).energy;
    expect(service.requests, hasLength(1));
    expect(app.generating, isTrue);
    expect(pendingEnergy, greaterThan(0.5));
    expect(find.byKey(const Key('quote-text')), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    expect(app.generating, isTrue);
    expect(tester.widget<LiquidOrb>(orb).energy, pendingEnergy);

    service.requests.single.succeed('first');
    await tester.pump();
    await tester.pump();
    expect(tester.state(orb), same(originalState));
    expect(tester.widget<LiquidOrb>(orb).energy, lessThan(pendingEnergy));
    expect(find.text('Words from first.'), findsOneWidget);
    expect(
      tester.widget<Opacity>(find.byKey(const Key('quote-emergence'))).opacity,
      lessThan(1),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<Opacity>(find.byKey(const Key('quote-emergence'))).opacity,
      1,
    );

    await tester.tap(find.byKey(const Key('regenerate')));
    await tester.pumpAndSettle();
    expect(service.requests, hasLength(2));
    expect(service.requests.last.previous, 'Words from first.');
    expect(tester.state(orb), same(originalState));
    expect(tester.widget<LiquidOrb>(orb).energy, pendingEnergy);
    expect(find.byKey(const Key('quote-text')), findsNothing);
    expect(find.byKey(const Key('quote-emergence')), findsNothing);

    service.requests.last.succeed('second');
    await tester.pump();
    await tester.pump();
    expect(tester.state(orb), same(originalState));
    expect(find.text('Words from first.'), findsNothing);
    expect(find.text('Words from second.'), findsOneWidget);
    expect(
      tester.widget<Opacity>(find.byKey(const Key('quote-emergence'))).opacity,
      lessThan(1),
    );
    await tester.pumpAndSettle();
    expect(tester.state(orb), same(originalState));
    expect(app.history.map((quote) => quote.id), ['second', 'first']);
  });

  testWidgets('a cancelled response cannot interrupt the next pending quote', (
    tester,
  ) async {
    final service = _ControlledService();
    final app = await launch(tester, service: service);
    await generate(tester);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(app.generating, isFalse);
    expect(find.byKey(const Key('generate')), findsOneWidget);
    expect(find.byKey(const Key('quote-emergence')), findsNothing);

    await tester.tap(find.byKey(const Key('generate')));
    await tester.pumpAndSettle();
    service.requests.first.succeed('cancelled');
    await tester.pumpAndSettle();
    expect(app.generating, isTrue);
    expect(app.current, isNull);
    expect(app.history, isEmpty);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byKey(const Key('creation-orb')), findsOneWidget);
    expect(find.byKey(const Key('quote-text')), findsNothing);
    expect(find.byKey(const Key('quote-emergence')), findsNothing);

    service.requests.last.succeed('current');
    await tester.pumpAndSettle();
    expect(find.text('Words from current.'), findsOneWidget);
    expect(find.text('Words from cancelled.'), findsNothing);
    expect(app.history.map((quote) => quote.id), ['current']);
  });

  testWidgets(
    'generation error leaves no reveal and retry reveals only success',
    (tester) async {
      final service = _ControlledService();
      final app = await launch(tester, service: service);
      await generate(tester);
      service.requests.single.result.completeError(
        const QuoteException('The writing service is offline.'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('The writing service is offline.'), findsOneWidget);
      expect(app.current, isNull);
      expect(app.history, isEmpty);
      expect(find.byKey(const Key('quote-text')), findsNothing);
      expect(find.byKey(const Key('quote-emergence')), findsNothing);

      await tester.tap(find.widgetWithText(TextButton, 'Try again'));
      await tester.pumpAndSettle();
      expect(service.requests, hasLength(2));
      expect(app.generating, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byKey(const Key('quote-text')), findsNothing);
      expect(find.byKey(const Key('quote-emergence')), findsNothing);
      service.requests.last.succeed('recovered');
      await tester.pump();
      await tester.pump();
      expect(
        tester
            .widget<Opacity>(find.byKey(const Key('quote-emergence')))
            .opacity,
        lessThan(1),
      );
      await tester.pumpAndSettle();
      expect(find.text('Words from recovered.'), findsOneWidget);
      expect(app.history.map((quote) => quote.id), ['recovered']);
    },
  );

  testWidgets(
    'failed regeneration restores the last quote without saving it twice',
    (tester) async {
      final service = _ControlledService();
      final app = await launch(tester, service: service);
      await generate(tester);
      service.requests.single.succeed('saved');
      await tester.pumpAndSettle();
      final orb = find.byKey(const Key('creation-orb'));
      final originalState = tester.state(orb);

      await tester.tap(find.byKey(const Key('regenerate')));
      await tester.pumpAndSettle();
      expect(find.text('Words from saved.'), findsNothing);
      service.requests.last.result.completeError(
        const QuoteException('Offline'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(tester.state(orb), same(originalState));
      expect(find.text('Words from saved.'), findsOneWidget);
      expect(
        tester
            .widget<Opacity>(find.byKey(const Key('quote-emergence')))
            .opacity,
        1,
      );
      expect(app.current!.id, 'saved');
      expect(app.history.map((quote) => quote.id), ['saved']);
    },
  );

  testWidgets(
    'home prompt retains focus inside and dismisses outside without blocking start',
    (tester) async {
      final app = await launch(tester);
      final field = find.byKey(const Key('home-prompt'));
      await focusAndTapInside(tester, field);
      final focus = editable(tester, field).focusNode;

      await tester.tap(find.byType(LiquidOrb));
      await tester.pump();
      expect(focus.hasFocus, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);

      await tester.tap(field);
      await tester.pump();
      expect(focus.hasFocus, isTrue);
      await tester.tap(find.byKey(const Key('start')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('custom-prompt')), findsOneWidget);
      expect(app.settings.prompt, 'A quiet morning');
      expect(tester.testTextInput.isVisible, isFalse);
    },
  );

  testWidgets(
    'custom prompt dismisses outside and Generate still submits its text',
    (tester) async {
      final service = _ControlledService();
      await launch(tester, service: service);
      await customize(tester);
      final field = find.byKey(const Key('custom-prompt'));
      await focusAndTapInside(tester, field);
      final focus = editable(tester, field).focusNode;

      await tester.tap(find.text('Make it yours'));
      await tester.pump();
      expect(focus.hasFocus, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);

      await tester.tap(field);
      await tester.pump();
      expect(focus.hasFocus, isTrue);
      await tester.tap(find.byKey(const Key('generate')));
      await tester.pumpAndSettle();
      expect(service.requests, hasLength(1));
      expect(service.requests.single.settings.prompt, 'A quiet morning');
      expect(tester.testTextInput.isVisible, isFalse);
      service.requests.single.succeed('custom');
      await tester.pumpAndSettle();
      expect(find.text('Words from custom.'), findsOneWidget);
    },
  );

  testWidgets(
    'language search keeps inside focus and outside taps still select a language',
    (tester) async {
      final app = await launch(tester);
      await customize(tester);
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      final field = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(TextField),
      );
      await focusAndTapInside(tester, field, text: 'French');
      await tester.pumpAndSettle();
      final focus = editable(tester, field).focusNode;
      final french = find.widgetWithText(ListTile, 'French');
      expect(french, findsOneWidget);
      expect(find.text('German'), findsNothing);

      await tester.tap(find.text('Language').last);
      await tester.pump();
      expect(focus.hasFocus, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);

      await tester.tap(field);
      await tester.pump();
      expect(focus.hasFocus, isTrue);
      await tester.tap(french);
      await tester.pumpAndSettle();
      expect(app.settings.language, QuoteLanguage.french);
      expect(find.text('Français'), findsOneWidget);
      expect(field, findsNothing);
      expect(tester.testTextInput.isVisible, isFalse);
    },
  );
}
