import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shakespeare/data/app_controller.dart';
import 'package:shakespeare/data/quote_service.dart';
import 'package:shakespeare/domain/models.dart';
import 'package:shakespeare/main.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('real renderer: creation, favorites, and RTL', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final app = AppController(
      await SharedPreferences.getInstance(),
      PreviewQuoteService(),
    );
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
    await tester.tap(find.byKey(const Key('categories')));
    await tester.pump(const Duration(seconds: 1));
    await screenshot('02-categories');
    await tester.tap(find.text('Romance'));
    await tester.pump(const Duration(seconds: 1));
    await screenshot('03-customize');
    await tester.tap(find.byKey(const Key('generate')));
    await tester.pump(const Duration(milliseconds: 600));
    await screenshot('04-generating', settle: 100);
    await tester.pump(const Duration(seconds: 3));
    expect(find.byKey(const Key('quote-text')), findsOneWidget);
    await screenshot('05-english');
    await tester.tap(find.byKey(const Key('favorite')));
    await tester.pump();
    expect(app.favorites, hasLength(1));
    for (final language in [QuoteLanguage.arabic, QuoteLanguage.hebrew]) {
      app.updateSettings(app.settings.copyWith(language: language));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byKey(const Key('regenerate')));
      await tester.pump(const Duration(seconds: 3));
      expect(find.byKey(const Key('quote-text')), findsOneWidget);
      await screenshot('06-${language.code}');
    }
    await app.flush();
    expect(tester.takeException(), isNull);
  });
}
