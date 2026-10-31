import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shakespeare/data/quote_service.dart';
import 'package:shakespeare/domain/models.dart';

void main() {
  final endpoint = Uri.parse('https://example.com/v1/quotes');
  test('sends options and previous quote; preserves UTF-8 Arabic', () async {
    final service = RemoteQuoteService(
      endpoint,
      client: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['language'], 'arz');
        expect(body['length'], 'veryShort');
        expect(body['previous'], 'An earlier quote');
        expect(body.containsKey('apiKey'), false);
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'id': '1',
              'text': 'إنت راحة قلبي.',
              'language': 'arz',
            }),
          ),
          200,
        );
      }),
    );
    final result = await service.generate(
      const QuoteSettings(
        language: QuoteLanguage.egyptianArabic,
        length: QuoteLength.veryShort,
      ),
      previous: 'An earlier quote',
    );
    expect(result.text, 'إنت راحة قلبي.');
    expect(result.isPreview, false);
    service.dispose();
  });

  for (final status in [429, 500]) {
    test('HTTP $status produces a useful error', () async {
      final service = RemoteQuoteService(
        endpoint,
        client: MockClient((_) async => http.Response('{}', status)),
      );
      await expectLater(
        service.generate(const QuoteSettings()),
        throwsA(isA<QuoteException>()),
      );
      service.dispose();
    });
  }
  test('rejects malformed or wrong-language provider data', () async {
    for (final body in [
      'not json',
      '{"text":"","id":"1","language":"en"}',
      '{"text":"Hello","id":"1","language":"he"}',
    ]) {
      final service = RemoteQuoteService(
        endpoint,
        client: MockClient((_) async => http.Response(body, 200)),
      );
      await expectLater(
        service.generate(const QuoteSettings()),
        throwsA(isA<QuoteException>()),
      );
      service.dispose();
    }
  });
}
