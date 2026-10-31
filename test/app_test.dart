import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shakespeare/data/app_controller.dart';
import 'package:shakespeare/data/quote_service.dart';
import 'package:shakespeare/domain/models.dart';
import 'package:shakespeare/main.dart';

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
      InstantService(),
    );
    await tester.pumpWidget(
      ShakespeareApp(controller: controller, animateOrb: false),
    );
    await tester.pumpAndSettle();
    return controller;
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
    await app.flush();
    await tester.pumpWidget(const SizedBox.shrink());
    app.dispose();
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
    await app.flush();
    await tester.pumpWidget(const SizedBox.shrink());
    app.dispose();
  });

  testWidgets('small screen and large text remain usable', (tester) async {
    final app = await launch(
      tester,
      size: const Size(320, 640),
      textScale: 1.5,
    );
    await tester.tap(find.byKey(const Key('categories')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Romance'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('generate')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quote-text')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await app.flush();
    await tester.pumpWidget(const SizedBox.shrink());
    app.dispose();
  });
}
