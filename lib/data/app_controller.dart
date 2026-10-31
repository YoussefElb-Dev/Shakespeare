import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/models.dart';
import 'quote_service.dart';

class AppController extends ChangeNotifier {
  AppController(this._prefs, this.service) {
    try {
      settings = QuoteSettings.fromJson(
        jsonDecode(_prefs.getString('settings') ?? '{}')
            as Map<String, dynamic>,
      );
    } on Object {
      settings = const QuoteSettings();
    }
    history = Quote.decodeList(_prefs.getString('history'));
    favorites = Quote.decodeList(_prefs.getString('favorites'));
  }
  final SharedPreferences _prefs;
  final QuoteService service;
  late QuoteSettings settings;
  late List<Quote> history;
  late List<Quote> favorites;
  Quote? current;
  bool generating = false;
  String? error;
  bool _disposed = false;
  int _generation = 0;
  Future<void> _writes = Future<void>.value();
  bool get isPreview => service is PreviewQuoteService;

  void updateSettings(QuoteSettings value) {
    settings = value;
    _save('settings', jsonEncode(value.toJson()));
    notifyListeners();
  }

  Future<bool> generate() async {
    if (generating) return false;
    final generation = ++_generation;
    generating = true;
    error = null;
    notifyListeners();
    try {
      final quote = await service.generate(settings, previous: current?.text);
      if (_disposed || generation != _generation) return false;
      current = quote;
      history = [quote, ...history].take(200).toList();
      _save('history', jsonEncode(history.map((q) => q.toJson()).toList()));
      return true;
    } on QuoteException catch (e) {
      if (!_disposed && generation == _generation) error = e.message;
      return false;
    } on Object {
      if (!_disposed && generation == _generation) {
        error = 'Something interrupted the writing. Please try again.';
      }
      return false;
    } finally {
      if (!_disposed && generation == _generation) {
        generating = false;
        notifyListeners();
      }
    }
  }

  void cancelGeneration() {
    _generation++;
    generating = false;
    notifyListeners();
  }

  void openQuote(Quote quote) {
    current = quote;
    settings = quote.settings.copyWith(haptics: settings.haptics);
    _save('settings', jsonEncode(settings.toJson()));
    notifyListeners();
  }

  bool isFavorite(Quote quote) => favorites.any((q) => q.id == quote.id);

  void toggleFavorite(Quote quote) {
    if (isFavorite(quote)) {
      favorites.removeWhere((q) => q.id == quote.id);
    } else {
      favorites.insert(0, quote);
    }
    _save('favorites', jsonEncode(favorites.map((q) => q.toJson()).toList()));
    notifyListeners();
  }

  void clearHistory() {
    history.clear();
    _save('history', '[]');
    notifyListeners();
  }

  void _save(String key, String value) {
    _writes = _writes
        .then((_) async {
          final saved = await _prefs.setString(key, value);
          if (!saved) throw StateError('Storage unavailable');
        })
        .catchError((Object e) {
          if (!_disposed) {
            error =
                'Your device couldn’t save this change. Free some storage and try again.';
            notifyListeners();
          }
        });
  }

  @visibleForTesting
  Future<void> flush() => _writes;

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    service.dispose();
    super.dispose();
  }
}
