import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shakespeare/data/app_controller.dart';
import 'package:shakespeare/data/quote_service.dart';
import 'package:shakespeare/domain/models.dart';
import 'package:shakespeare/main.dart';

class RendererService extends PreviewQuoteService {
  Completer<Quote>? pending;
  QuoteSettings? settings;
  int sequence = 0;

  @override
  Future<Quote> generate(QuoteSettings settings, {String? previous}) {
    this.settings = settings;
    pending = Completer<Quote>();
    return pending!.future;
  }

  void finish() {
    pending!.complete(
      Quote(
        id: 'renderer-${sequence++}',
        text: switch (settings!.language) {
          QuoteLanguage.arabic => 'أنت المكان الذي يهدأ فيه كل ما بداخلي.',
          QuoteLanguage.hebrew => 'את המקום שבו הלב שלי תמיד מרגיש בבית.',
          _ => 'You are the calm my restless heart always returns to.',
        },
        settings: settings!,
        createdAt: DateTime(2026),
        isPreview: true,
      ),
    );
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('real renderer: creation, favorites, and RTL', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = RendererService();
    final app = AppController(await SharedPreferences.getInstance(), service);
    await tester.pumpWidget(ShakespeareApp(controller: app));
    await tester.pump(const Duration(seconds: 2));
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    Future<void> screenshot(String name, {int settle = 700}) async {
      // Let both the framework transition and Android's image surface present.
      await tester.pump(Duration(milliseconds: settle));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await binding.takeScreenshot(name);
    }

    await screenshot('01-home');
    await screenshot('01-home-motion', settle: 1500);
    await tester.tap(find.byKey(const Key('home-prompt')));
    await tester.pump(const Duration(milliseconds: 700));
    await screenshot('01-keyboard');
    await tester.tapAt(const Offset(28, 150));
    await tester.pump(const Duration(milliseconds: 700));
    await screenshot('01-keyboard-dismissed');
    await tester.tap(find.byKey(const Key('categories')));
    await tester.pump(const Duration(seconds: 1));
    await screenshot('02-categories');
    await tester.tap(find.text('Romance'));
    await tester.pump(const Duration(seconds: 1));
    await screenshot('03-customize');
    await tester.tap(find.byKey(const Key('generate')));
    await tester.pump(const Duration(milliseconds: 600));
    await screenshot('04-generating', settle: 100);
    await screenshot('04-generating-motion', settle: 1000);
    service.finish();
    await tester.pump();
    await screenshot('04-emerging', settle: 450);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const Key('quote-text')), findsOneWidget);
    await screenshot('05-english');
    await tester.tap(find.byKey(const Key('favorite')));
    await tester.pump();
    expect(app.favorites, hasLength(1));
    for (final language in [QuoteLanguage.arabic, QuoteLanguage.hebrew]) {
      app.updateSettings(app.settings.copyWith(language: language));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byKey(const Key('regenerate')));
      await tester.pump(const Duration(milliseconds: 800));
      service.finish();
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(find.byKey(const Key('quote-text')), findsOneWidget);
      await screenshot('06-${language.code}');
    }
    await app.flush();
    expect(tester.takeException(), isNull);
  });
}
