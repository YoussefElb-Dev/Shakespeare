import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shakespeare/data/app_controller.dart';
import 'package:shakespeare/data/quote_service.dart';
import 'package:shakespeare/domain/models.dart';

class ControlledService implements QuoteService {
  final requests = <Completer<Quote>>[];
  @override
  Future<Quote> generate(QuoteSettings settings, {String? previous}) {
    final request = Completer<Quote>();
    requests.add(request);
    return request.future;
  }

  @override
  void dispose() {}
}

Quote quote(String id) => Quote(
  id: id,
  text: 'The quiet between stars.',
  settings: const QuoteSettings(),
  createdAt: DateTime(2026),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'settings, history, and favorites survive a controller restart',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final service = ControlledService();
      final app = AppController(prefs, service);
      app.updateSettings(
        const QuoteSettings(
          language: QuoteLanguage.hebrew,
          tone: QuoteTone.deep,
        ),
      );
      final generating = app.generate();
      service.requests.single.complete(quote('saved'));
      expect(await generating, true);
      app.toggleFavorite(app.current!);
      await app.flush();
      app.dispose();
      final restored = AppController(prefs, ControlledService());
      expect(restored.settings.language, QuoteLanguage.hebrew);
      expect(restored.settings.tone, QuoteTone.deep);
      expect(restored.favorites.single.id, 'saved');
      expect(restored.history.single.id, 'saved');
      restored.clearHistory();
      expect(restored.favorites, hasLength(1));
      await restored.flush();
      restored.dispose();
    },
  );

  test('cancelled response cannot overwrite a newer generation', () async {
    final service = ControlledService();
    final app = AppController(await SharedPreferences.getInstance(), service);
    final first = app.generate();
    app.cancelGeneration();
    final second = app.generate();
    service.requests[0].complete(quote('stale'));
    expect(await first, false);
    expect(app.generating, true);
    expect(app.current, isNull);
    service.requests[1].complete(quote('new'));
    expect(await second, true);
    expect(app.current!.id, 'new');
    expect(app.history.map((q) => q.id), ['new']);
    await app.flush();
    app.dispose();
  });

  test(
    'provider errors preserve the last quote and do not add history',
    () async {
      final service = ControlledService();
      final app = AppController(await SharedPreferences.getInstance(), service);
      app.openQuote(quote('existing'));
      final result = app.generate();
      service.requests.single.completeError(const QuoteException('Offline'));
      expect(await result, false);
      expect(app.current!.id, 'existing');
      expect(app.error, 'Offline');
      expect(app.history, isEmpty);
      expect(app.generating, false);
      app.dispose();
    },
  );

  test('history is bounded to 200 entries', () async {
    final stored = List.generate(200, (i) => quote('$i').toJson());
    SharedPreferences.setMockInitialValues({'history': jsonEncode(stored)});
    final service = ControlledService();
    final app = AppController(await SharedPreferences.getInstance(), service);
    final result = app.generate();
    service.requests.single.complete(quote('new'));
    await result;
    expect(app.history, hasLength(200));
    expect(app.history.first.id, 'new');
    expect(app.history.last.id, '198');
    await app.flush();
    app.dispose();
  });

  test('corrupted local state recovers to safe defaults', () async {
    SharedPreferences.setMockInitialValues({
      'settings': 'broken',
      'history': '[{}]',
      'favorites': 'null',
    });
    final app = AppController(
      await SharedPreferences.getInstance(),
      ControlledService(),
    );
    expect(app.settings.language, QuoteLanguage.english);
    expect(app.history, isEmpty);
    expect(app.favorites, isEmpty);
    app.dispose();
  });
}
