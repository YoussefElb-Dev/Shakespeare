import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shakespeare/data/asechka_service.dart';
import 'package:shakespeare/domain/models.dart';

const _session = '1794000000.test-signature';
const _origin = 'https://asechka-website.vercel.app';
final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

Quote _quote({
  String id = 'preview-saved-quote',
  String text = 'إنت راحة قلبي. 🌙',
  QuoteLanguage language = QuoteLanguage.egyptianArabic,
}) => Quote(
  id: id,
  text: text,
  settings: QuoteSettings(language: language, prompt: 'Never send this prompt'),
  createdAt: DateTime(2024, 2, 29, 23, 58),
  isPreview: true,
);

Map<String, dynamic> _payload(http.Request request) =>
    jsonDecode(request.body) as Map<String, dynamic>;

http.Response _confirmed(http.Request request) => http.Response(
  jsonEncode({'id': _payload(request)['operationId'], 'posted': true}),
  200,
);

Matcher get _needsSignIn => isA<AsechkaException>().having(
  (error) => error.needsSignIn,
  'needsSignIn',
  true,
);

class _SecureStore implements AsechkaSecureStore {
  String? session = _session;
  int reads = 0;
  int deletes = 0;
  final writes = <String>[];
  bool failRead = false;
  bool failWrite = false;
  bool failDelete = false;

  @override
  Future<String?> readSession() async {
    reads++;
    if (failRead) throw StateError('Secure store unavailable');
    return session;
  }

  @override
  Future<void> writeSession(String value) async {
    if (failWrite) throw StateError('Secure store unavailable');
    writes.add(value);
    session = value;
  }

  @override
  Future<void> deleteSession() async {
    deletes++;
    if (failDelete) throw StateError('Secure store unavailable');
    session = null;
  }
}

// Mirrors the legacy plugin's cache-first behavior, including failed writes.
class _ControlledPreferences extends Fake implements SharedPreferences {
  final values = <String, String>{};
  final writes = <String>[];
  bool failOperations = false;
  bool failMarkers = false;
  Completer<bool>? operationWrite;
  final operationWriteStarted = Completer<void>();

  @override
  String? getString(String key) => values[key];

  @override
  Future<bool> setString(String key, String value) async {
    values[key] = value;
    writes.add(key);
    if (key.startsWith('asechka.operation.')) {
      if (!operationWriteStarted.isCompleted) operationWriteStarted.complete();
      if (operationWrite != null) return operationWrite!.future;
      return !failOperations;
    }
    return !failMarkers;
  }

  @override
  Future<bool> remove(String key) async {
    values.remove(key);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late _SecureStore secureStore;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    secureStore = _SecureStore();
  });

  AsechkaService service(
    Future<http.Response> Function(http.Request) handler, {
    SharedPreferences? preferences,
  }) {
    final result = AsechkaService(
      client: MockClient(handler),
      secureStore: secureStore,
      preferences: Future.value(preferences ?? prefs),
    );
    addTearDown(result.dispose);
    return result;
  }

  test(
    'default service checks status without secure storage or writes',
    () async {
      final api = AsechkaService();
      addTearDown(api.dispose);
      expect(await api.isPosted(_quote()), false);
      expect(prefs.getKeys(), isEmpty);
    },
  );

  test(
    'local status lookup does not create a UUID or read a session',
    () async {
      final local = _ControlledPreferences();
      secureStore.failRead = true;
      final api = service(
        (_) async => throw StateError('No network'),
        preferences: local,
      );
      expect(await api.isPosted(_quote()), false);
      expect(local.values, isEmpty);
      expect(local.writes, isEmpty);
      expect(secureStore.reads, 0);
    },
  );

  test(
    'publishes only the four contract fields with original date and UTF-8',
    () async {
      late http.Request sent;
      final api = service((request) async {
        sent = request;
        return _confirmed(request);
      });
      final quote = _quote();
      await api.publish(quote);
      expect(sent.url.toString(), '$_origin/api/shakespeare');
      expect(sent.method, 'POST');
      expect(sent.followRedirects, false);
      expect(sent.headers['Accept'], 'application/json');
      expect(sent.headers['Origin'], _origin);
      expect(sent.headers['X-Asechka-Shakespeare'], '1');
      expect(sent.headers['Cookie'], 'asechka_session=$_session');
      final body = _payload(sent);
      expect(
        body.keys,
        unorderedEquals(['operationId', 'text', 'date', 'language']),
      );
      expect(body['operationId'], matches(_uuid));
      expect(body['text'], quote.text);
      expect(body['date'], '2024-02-29');
      expect(body['language'], 'arz');
      expect(await api.isPosted(quote), true);
      expect(
        prefs.getString('asechka.posted.${body['operationId']}'),
        body['operationId'],
      );
      expect(prefs.getKeys().any((key) => key.contains('session')), false);
    },
  );

  test(
    'failed request retries with the same payload after service restart',
    () async {
      final bodies = <String>[];
      final first = service((request) async {
        bodies.add(request.body);
        throw http.ClientException('Connection lost after sending');
      });
      await expectLater(
        first.publish(_quote()),
        throwsA(isA<AsechkaException>()),
      );
      expect(await first.isPosted(_quote()), false);
      first.dispose();
      await prefs.reload();
      final restarted = service((request) async {
        bodies.add(request.body);
        return _confirmed(request);
      });
      await restarted.publish(_quote());
      expect(bodies, hasLength(2));
      expect(bodies[1], bodies[0]);
      expect(await restarted.isPosted(_quote()), true);
    },
  );

  test(
    'confirmed status survives restart and does not resend or need a session',
    () async {
      final first = service((request) async => _confirmed(request));
      await first.publish(_quote());
      first.dispose();
      await prefs.reload();
      secureStore.failRead = true;
      final reads = secureStore.reads;
      final restarted = service(
        (_) async => throw StateError('Must not resend'),
      );
      expect(await restarted.isPosted(_quote()), true);
      await restarted.publish(_quote());
      expect(secureStore.reads, reads);
    },
  );

  test(
    'different quote IDs get distinct operation IDs, including previews',
    () async {
      final ids = <String>[];
      final api = service((request) async {
        ids.add(_payload(request)['operationId'] as String);
        return _confirmed(request);
      });
      await api.publish(_quote(id: 'preview-one'));
      await api.publish(_quote(id: 'preview-two'));
      expect(ids, hasLength(2));
      expect(ids.every(_uuid.hasMatch), true);
      expect(ids.toSet(), hasLength(2));
    },
  );

  test('waits for durable operation write before sending', () async {
    final local = _ControlledPreferences()..operationWrite = Completer<bool>();
    var sends = 0;
    final api = service((request) async {
      sends++;
      return _confirmed(request);
    }, preferences: local);
    final publishing = api.publish(_quote());
    await local.operationWriteStarted.future;
    expect(sends, 0);
    local.operationWrite!.complete(true);
    await publishing;
    expect(sends, 1);
  });

  test(
    'false operation writes fail closed even when the UUID remains cached',
    () async {
      final local = _ControlledPreferences()..failOperations = true;
      var sends = 0;
      final api = service((request) async {
        sends++;
        return _confirmed(request);
      }, preferences: local);
      await expectLater(
        api.publish(_quote()),
        throwsA(isA<AsechkaException>()),
      );
      final savedId = local.values['asechka.operation.${_quote().id}'];
      expect(savedId, matches(_uuid));
      await expectLater(
        api.publish(_quote()),
        throwsA(isA<AsechkaException>()),
      );
      expect(sends, 0);
      local.failOperations = false;
      await api.publish(_quote());
      expect(local.values['asechka.operation.${_quote().id}'], savedId);
      expect(sends, 1);
    },
  );

  test(
    'failed confirmation write stays unposted and retries the same backend ID',
    () async {
      final local = _ControlledPreferences()..failMarkers = true;
      final ids = <String>[];
      final api = service((request) async {
        ids.add(_payload(request)['operationId'] as String);
        return _confirmed(request);
      }, preferences: local);
      await expectLater(
        api.publish(_quote()),
        throwsA(isA<AsechkaException>()),
      );
      expect(await api.isPosted(_quote()), false);
      local.failMarkers = false;
      await api.publish(_quote());
      expect(ids, hasLength(2));
      expect(ids[0], ids[1]);
      expect(await api.isPosted(_quote()), true);
    },
  );

  test('concurrent clicks use one operation and one confirmed POST', () async {
    var sends = 0;
    final api = service((request) async {
      sends++;
      return _confirmed(request);
    });
    await Future.wait([api.publish(_quote()), api.publish(_quote())]);
    expect(sends, 1);
  });

  for (final status in [
    201,
    204,
    301,
    302,
    303,
    307,
    308,
    400,
    403,
    409,
    413,
    503,
  ]) {
    test(
      'HTTP $status never confirms publication, even with a success body',
      () async {
        late http.Request sent;
        final api = service((request) async {
          sent = request;
          return http.Response(
            jsonEncode({
              'id': _payload(request)['operationId'],
              'posted': true,
            }),
            status,
            headers: {'location': 'https://untrusted.example/collect'},
          );
        });
        await expectLater(
          api.publish(_quote()),
          throwsA(isA<AsechkaException>()),
        );
        expect(sent.followRedirects, false);
        expect(await api.isPosted(_quote()), false);
      },
    );
  }

  for (final entry in {
    'HTML': '<html>Saved</html>',
    'null': 'null',
    'array': '[]',
    'missing fields': '{}',
    'string posted': '{"id":"ID","posted":"true"}',
    'numeric posted': '{"id":"ID","posted":1}',
    'false posted': '{"id":"ID","posted":false}',
    'wrong ID': '{"id":"another-id","posted":true}',
    'numeric ID': '{"id":123,"posted":true}',
    'missing ID': '{"posted":true}',
    'missing posted': '{"id":"ID"}',
  }.entries) {
    test('rejects HTTP 200 with ${entry.key}', () async {
      final api = service(
        (request) async => http.Response(
          entry.value.replaceAll(
            'ID',
            _payload(request)['operationId'] as String,
          ),
          200,
        ),
      );
      await expectLater(
        api.publish(_quote()),
        throwsA(isA<AsechkaException>()),
      );
      expect(await api.isPosted(_quote()), false);
    });
  }

  test(
    '401 clears the secure cookie, requests sign-in, and keeps the UUID',
    () async {
      String? operationId;
      var attempts = 0;
      final api = service((request) async {
        attempts++;
        final id = _payload(request)['operationId'] as String;
        if (operationId == null) {
          operationId = id;
          return http.Response('{"error":"expired"}', 401);
        }
        expect(id, operationId);
        return _confirmed(request);
      });
      await expectLater(api.publish(_quote()), throwsA(_needsSignIn));
      expect(secureStore.session, isNull);
      expect(secureStore.deletes, 1);
      expect(await api.isPosted(_quote()), false);
      await expectLater(api.publish(_quote()), throwsA(_needsSignIn));
      expect(attempts, 1);
      // Recreate the service after an external sign-in to verify the saved UUID.
      secureStore.session = _session;
      final restarted = service((request) async {
        expect(_payload(request)['operationId'], operationId);
        return _confirmed(request);
      });
      await restarted.publish(_quote());
    },
  );

  test(
    'absent or malformed stored cookie cannot send a publish request',
    () async {
      for (final value in [
        null,
        '',
        'bad; injected=value',
        'bad\r\nHeader: value',
      ]) {
        secureStore.session = value;
        final api = service((_) async => throw StateError('Must not send'));
        await expectLater(api.publish(_quote()), throwsA(_needsSignIn));
      }
    },
  );

  test('sign-in URL-encodes the code and saves only the cookie value', () async {
    secureStore.session = null;
    late http.Request sent;
    final api = service((request) async {
      sent = request;
      return http.Response(
        '{"ok":true}',
        200,
        headers: {
          'set-cookie':
              'other=ignored; Path=/, asechka_session=$_session; '
              'Max-Age=604800; Expires=Sat, 07 Nov 2026 00:00:00 GMT; Secure; HttpOnly; SameSite=Lax',
        },
      );
    });
    const code = 'test code & + = العربية';
    await api.signIn(code);
    expect(sent.url.toString(), '$_origin/api/session');
    expect(sent.followRedirects, false);
    expect(sent.headers['Origin'], _origin);
    expect(sent.headers['Accept'], 'application/json');
    expect(
      sent.headers['content-type'],
      startsWith('application/x-www-form-urlencoded'),
    );
    expect(Uri.splitQueryString(sent.body), {'password': code});
    expect(sent.headers.containsKey('Cookie'), false);
    expect(secureStore.writes, [_session]);
    expect(secureStore.session, _session);
    expect(prefs.getKeys(), isEmpty);
  });

  test(
    'login never publishes; an explicit later publish uses the saved session',
    () async {
      secureStore.session = null;
      final paths = <String>[];
      final api = service((request) async {
        paths.add(request.url.path);
        if (request.url.path == '/api/session') {
          return http.Response(
            '{}',
            200,
            headers: {
              'set-cookie': 'asechka_session=$_session; Secure; HttpOnly',
            },
          );
        }
        return _confirmed(request);
      });
      await expectLater(api.publish(_quote()), throwsA(_needsSignIn));
      await api.signIn('test-only-code');
      expect(paths, ['/api/session']);
      expect(await api.isPosted(_quote()), false);
      await api.publish(_quote());
      expect(paths, ['/api/session', '/api/shakespeare']);
    },
  );

  for (final status in [302, 307, 401, 403, 503]) {
    test('login HTTP $status cannot store a returned cookie', () async {
      final api = service((request) async {
        expect(request.followRedirects, false);
        return http.Response(
          '{}',
          status,
          headers: {
            'set-cookie': 'asechka_session=new.invalid-session; Secure',
            'location': 'https://untrusted.example/sign-in',
          },
        );
      });
      await expectLater(
        api.signIn('test-only-code'),
        throwsA(status == 401 ? _needsSignIn : isA<AsechkaException>()),
      );
      expect(secureStore.writes, isEmpty);
      if (status == 401) {
        expect(secureStore.session, isNull);
        expect(secureStore.deletes, 1);
      }
    });
  }

  for (final cookie in [
    '',
    'other=value; Path=/',
    'asechka_session=; Max-Age=0',
    'asechka_session="quoted"; Secure',
    'asechka_session=one, asechka_session=two',
  ]) {
    test(
      'login rejects missing, empty, malformed or ambiguous cookie: $cookie',
      () async {
        final api = service(
          (_) async =>
              http.Response('{}', 200, headers: {'set-cookie': cookie}),
        );
        await expectLater(
          api.signIn('test-only-code'),
          throwsA(isA<AsechkaException>()),
        );
        expect(secureStore.writes, isEmpty);
      },
    );
  }

  test(
    'failed secure session write does not report successful sign-in',
    () async {
      secureStore
        ..session = null
        ..failWrite = true;
      final api = service(
        (_) async => http.Response(
          '{}',
          200,
          headers: {'set-cookie': 'asechka_session=$_session; Secure'},
        ),
      );
      await expectLater(
        api.signIn('test-only-code'),
        throwsA(isA<AsechkaException>()),
      );
      expect(secureStore.session, isNull);
    },
  );

  test(
    'sign-out clears only the session and preserves confirmed quotes',
    () async {
      final api = service((request) async => _confirmed(request));
      await api.publish(_quote());
      await api.signOut();
      expect(secureStore.session, isNull);
      expect(await api.isPosted(_quote()), true);
      await expectLater(
        api.publish(_quote(id: 'different')),
        throwsA(_needsSignIn),
      );
    },
  );

  test(
    'sign-out queued during login leaves no session after completion',
    () async {
      secureStore.session = null;
      final entered = Completer<void>();
      final response = Completer<http.Response>();
      final api = service((_) {
        entered.complete();
        return response.future;
      });
      final signingIn = api.signIn('test-only-code');
      await entered.future;
      final signingOut = api.signOut();
      response.complete(
        http.Response(
          '{}',
          200,
          headers: {'set-cookie': 'asechka_session=$_session; Secure'},
        ),
      );
      await signingIn;
      await signingOut;
      expect(secureStore.session, isNull);
      expect(prefs.getKeys(), isEmpty);
    },
  );

  test(
    'failed session deletion remains blocked and still requests sign-in',
    () async {
      secureStore.failDelete = true;
      var attempts = 0;
      final api = service((_) async {
        attempts++;
        return http.Response('{}', 401);
      });
      await expectLater(api.publish(_quote()), throwsA(_needsSignIn));
      await expectLater(api.publish(_quote()), throwsA(_needsSignIn));
      expect(attempts, 1);
    },
  );

  test(
    'enforces the UTF-16 limit before any request and accepts 2400 units',
    () async {
      var sends = 0;
      final api = service((request) async {
        sends++;
        return _confirmed(request);
      });
      for (final text in ['', '   ', List.filled(1201, '🌙').join()]) {
        await expectLater(
          api.publish(_quote(text: text)),
          throwsA(isA<AsechkaException>()),
        );
      }
      expect(sends, 0);
      expect(secureStore.reads, 0);
      await api.publish(_quote(text: List.filled(1200, '🌙').join()));
      expect(sends, 1);
    },
  );

  test('blank sign-in code makes no request or secure-store write', () async {
    final api = service((_) async => throw StateError('Must not send'));
    await expectLater(api.signIn('  '), throwsA(_needsSignIn));
    expect(secureStore.writes, isEmpty);
  });

  test('connection errors do not expose request credentials', () async {
    const secret = 'test-secret-must-not-appear';
    final api = service((_) async => throw http.ClientException(secret));
    await expectLater(
      api.signIn(secret),
      throwsA(
        isA<AsechkaException>().having(
          (error) => error.toString(),
          'safe message',
          isNot(contains(secret)),
        ),
      ),
    );
  });

  test('dispose closes client once and future calls fail cleanly', () async {
    final client = _ClosingClient();
    final api = AsechkaService(
      client: client,
      secureStore: secureStore,
      preferences: Future.value(prefs),
    );
    api.dispose();
    api.dispose();
    expect(client.closes, 1);
    await expectLater(api.isPosted(_quote()), throwsA(isA<AsechkaException>()));
    await expectLater(api.publish(_quote()), throwsA(isA<AsechkaException>()));
    await expectLater(
      api.signIn('test-only-code'),
      throwsA(isA<AsechkaException>()),
    );
    await expectLater(api.signOut(), throwsA(isA<AsechkaException>()));
  });
}

class _ClosingClient extends http.BaseClient {
  int closes = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      throw StateError('Closed client must not send');

  @override
  void close() => closes++;
}
