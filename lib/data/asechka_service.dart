import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models.dart';

class AsechkaException implements Exception {
  const AsechkaException(this.message, {this.needsSignIn = false});

  final String message;
  final bool needsSignIn;

  @override
  String toString() => message;
}

/// Stores only the signed session cookie, never the entered site code.
abstract interface class AsechkaSecureStore {
  Future<String?> readSession();
  Future<void> writeSession(String value);
  Future<void> deleteSession();
}

class _PlatformSecureStore implements AsechkaSecureStore {
  const _PlatformSecureStore();

  static const _storage = FlutterSecureStorage();
  static const _key = 'asechka.session';

  @override
  Future<String?> readSession() => _storage.read(key: _key);

  @override
  Future<void> writeSession(String value) =>
      _storage.write(key: _key, value: value);

  @override
  Future<void> deleteSession() => _storage.delete(key: _key);
}

/// Publishing is explicit. Signing in never publishes or retries a quote.
/// The owner disposes this service, which also closes its HTTP client.
class AsechkaService {
  AsechkaService({
    http.Client? client,
    AsechkaSecureStore? secureStore,
    Future<SharedPreferences>? preferences,
  }) : _client = client ?? http.Client(),
       _secureStore = secureStore ?? const _PlatformSecureStore(),
       _preferences = preferences;

  static const _origin = 'https://asechka-website.vercel.app';
  static final _uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );
  // Accept cookie-safe signed values without assuming a particular HMAC format.
  static final _cookiePattern = RegExp(r'^[A-Za-z0-9._~+/=-]{1,4096}$');
  static final _sessionCookie = RegExp(r'(?:^|,)\s*asechka_session=([^;,\s]*)');

  final http.Client _client;
  final AsechkaSecureStore _secureStore;
  Future<SharedPreferences>? _preferences;
  Future<void> _mutations = Future<void>.value();
  bool _disposed = false;
  bool _sessionBlocked = false;

  Future<SharedPreferences> get _prefs =>
      _preferences ??= SharedPreferences.getInstance();

  static String _operationKey(Quote quote) => 'asechka.operation.${quote.id}';
  static String _postedKey(String operationId) => 'asechka.posted.$operationId';

  /// Local-only, read-only lookup: safe before the secure-storage plugin loads.
  Future<bool> isPosted(Quote quote) => _guard(() async {
    final prefs = await _prefs;
    final operationId = prefs.getString(_operationKey(quote));
    return operationId != null &&
        _uuidPattern.hasMatch(operationId) &&
        prefs.getString(_postedKey(operationId)) == operationId;
  }, 'Couldn’t read the saved publishing status. Please try again.');

  Future<void> publish(Quote quote) => _enqueue(() async {
    if (quote.id.isEmpty ||
        quote.text.trim().isEmpty ||
        quote.text.length > 2400) {
      throw const AsechkaException(
        'Choose a quote with between 1 and 2,400 characters.',
      );
    }
    if (await isPosted(quote)) return;
    if (_sessionBlocked) throw _signInRequired;
    final session = await _secureStore.readSession();
    if (session == null) throw _signInRequired;
    if (!_cookiePattern.hasMatch(session)) await _expireSession();

    final prefs = await _prefs;
    final key = _operationKey(quote);
    final operationId = prefs.getString(key) ?? _newUuid();
    if (!_uuidPattern.hasMatch(operationId)) {
      throw const AsechkaException(
        'The saved publishing reference is invalid. The quote was kept.',
      );
    }
    // SharedPreferences updates its cache even when a disk write fails. Await
    // a successful write on EVERY attempt, including cached/restarted retries.
    if (!await prefs.setString(key, operationId)) {
      throw const AsechkaException(
        'Couldn’t save the publishing reference. Nothing was sent; try again.',
      );
    }
    final request = _request('/api/shakespeare')
      ..headers.addAll({
        'Content-Type': 'application/json; charset=utf-8',
        'X-Asechka-Shakespeare': '1',
        'Cookie': 'asechka_session=$session',
      })
      ..body = jsonEncode({
        'operationId': operationId,
        'text': quote.text,
        'date': quote.createdAt.toIso8601String().split('T').first,
        'language': quote.settings.language.code,
      });
    final response = await _send(request);
    if (response.statusCode == 401) await _expireSession();
    if (response.statusCode != 200) {
      throw AsechkaException(switch (response.statusCode) {
        409 =>
          'Asechka couldn’t confirm this quote. Please retry the same quote.',
        413 => 'This quote is too long to add to Asechka.',
        _ =>
          'Asechka couldn’t confirm publishing. Your quote is kept; try again.',
      });
    }
    final Object? data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is! Map<String, dynamic> ||
        data['posted'] is! bool ||
        data['posted'] != true ||
        data['id'] is! String ||
        data['id'] != operationId) {
      throw const AsechkaException(
        'Asechka returned an incomplete confirmation. Please retry the same quote.',
      );
    }
    final postedKey = _postedKey(operationId);
    var saved = false;
    try {
      saved = await prefs.setString(postedKey, operationId);
    } finally {
      // Do not allow a failed marker write to appear confirmed from the cache.
      if (!saved) await prefs.remove(postedKey);
    }
    if (!saved) {
      throw const AsechkaException(
        'Couldn’t save the publishing confirmation. Retry to confirm this quote.',
      );
    }
  }, 'Couldn’t reach Asechka or save publishing. Your quote is kept; try again.');

  Future<void> signIn(String code) => _enqueue(() async {
    if (code.trim().isEmpty) {
      throw const AsechkaException(
        'Enter your existing Asechka code.',
        needsSignIn: true,
      );
    }
    // The code exists only in this request; no field or persistence retains it.
    final request = _request('/api/session')..bodyFields = {'password': code};
    final response = await _send(request);
    if (response.statusCode == 401) await _expireSession();
    if (response.statusCode != 200) {
      throw const AsechkaException(
        'Couldn’t sign in to Asechka. Please try again.',
      );
    }
    final cookies = _sessionCookie
        .allMatches(response.headers['set-cookie'] ?? '')
        .toList();
    final session = cookies.length == 1 ? cookies.single.group(1) : null;
    if (session == null || !_cookiePattern.hasMatch(session)) {
      throw const AsechkaException(
        'Asechka didn’t return a valid session. Please try again.',
      );
    }
    _ensureOpen();
    await _secureStore.writeSession(session);
    _sessionBlocked = false;
  }, 'Couldn’t sign in or securely save the Asechka session. Please try again.');

  /// Signs out locally without discarding confirmed quote markers.
  Future<void> signOut() => _enqueue(
    () async {
      _sessionBlocked = true;
      await _secureStore.deleteSession();
    },
    'Couldn’t remove the saved Asechka session. Please try signing out again.',
  );

  static const _signInRequired = AsechkaException(
    'Sign in with your existing Asechka code to add this quote.',
    needsSignIn: true,
  );

  Future<Never> _expireSession() async {
    _sessionBlocked = true;
    try {
      await _secureStore.deleteSession();
    } on Object {
      // Stay blocked even if the platform cannot remove its obsolete entry.
      throw const AsechkaException(
        'The session expired and couldn’t be cleared. Please sign in again.',
        needsSignIn: true,
      );
    }
    throw _signInRequired;
  }

  http.Request _request(String path) =>
      http.Request('POST', Uri.parse('$_origin$path'))
        ..followRedirects = false
        ..headers.addAll({'Accept': 'application/json', 'Origin': _origin});

  Future<http.Response> _send(http.Request request) async {
    _ensureOpen();
    final response = await _client
        .send(request)
        .then(http.Response.fromStream)
        .timeout(const Duration(seconds: 30));
    _ensureOpen();
    return response;
  }

  // Serialize mutations so concurrent clicks, login and sign-out cannot create
  // competing operation IDs or restore a session after signOut completes.
  Future<void> _enqueue(Future<void> Function() action, String failure) {
    final result = _mutations.then((_) => _guard(action, failure));
    _mutations = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace stack) {},
    );
    return result;
  }

  Future<T> _guard<T>(Future<T> Function() action, String failure) async {
    try {
      _ensureOpen();
      return await action();
    } on AsechkaException {
      rethrow;
    } on Object {
      // Never expose request bodies, session cookies, or backend error text.
      throw AsechkaException(failure);
    }
  }

  static String _newUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  void _ensureOpen() {
    if (_disposed) {
      throw const AsechkaException('The Asechka connection is closed.');
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _client.close();
  }
}
