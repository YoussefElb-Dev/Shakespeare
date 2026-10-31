import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../domain/models.dart';

class QuoteException implements Exception {
  const QuoteException(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract interface class QuoteService {
  Future<Quote> generate(QuoteSettings settings, {String? previous});
  void dispose();
}

class RemoteQuoteService implements QuoteService {
  RemoteQuoteService(this.endpoint, {http.Client? client})
    : _client = client ?? http.Client();
  final Uri endpoint;
  final http.Client _client;

  @override
  Future<Quote> generate(QuoteSettings settings, {String? previous}) async {
    try {
      final response = await _client
          .post(
            endpoint,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'language': settings.language.code,
              'length': settings.length.name,
              'tone': settings.tone.name,
              'category': settings.category.name,
              'prompt': settings.prompt,
              'previous': ?previous,
            }),
          )
          .timeout(const Duration(seconds: 40));
      if (response.statusCode == 429) {
        throw const QuoteException(
          'You’ve reached the creation limit. Please try again in a little while.',
        );
      }
      if (response.statusCode != 200) {
        throw const QuoteException(
          'The writing studio is unavailable. Please try again shortly.',
        );
      }
      final json =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final text = json['text'];
      if (text is! String ||
          text.trim().isEmpty ||
          text.length > 2400 ||
          json['language'] != settings.language.code) {
        throw const QuoteException(
          'The studio returned an incomplete quote. Please try again.',
        );
      }
      return Quote(
        id: json['id'] as String,
        text: text.trim(),
        settings: settings,
        createdAt: DateTime.now(),
      );
    } on QuoteException {
      rethrow;
    } on Object {
      throw const QuoteException(
        'Couldn’t reach the writing studio. Check your connection and try again.',
      );
    }
  }

  @override
  void dispose() => _client.close();
}

/// A deliberately labelled, offline UI preview. Never presented as AI generation.
class PreviewQuoteService implements QuoteService {
  int _index = Random().nextInt(3);
  static const _samples = {
    QuoteLanguage.english: [
      'You are the calm my restless heart always returns to.',
      'Somewhere between the ordinary moments, you became my favorite part of being alive.',
      'If the world grew quiet, I would still hear home in your voice.',
    ],
    QuoteLanguage.arabic: [
      'أنت المكان الذي يهدأ فيه كل ما بداخلي.',
      'معك، تصبح التفاصيل الصغيرة أسبابًا كبيرة للسعادة.',
      'في صوتك شيء يشبه العودة إلى البيت.',
    ],
    QuoteLanguage.egyptianArabic: [
      'إنت كل الحاجات الحلوة اللي بحاول ألاقيها في الدنيا.',
      'معاك، حتى الأيام العادية ليها طعم تاني.',
      'صوتك هو المكان اللي قلبي بيرتاح فيه.',
    ],
    QuoteLanguage.french: [
      'Tu es la plus belle raison pour laquelle tout semble plus doux.',
      'Dans ta voix, mon cœur retrouve le chemin de la maison.',
      'Avec toi, les jours ordinaires deviennent précieux.',
    ],
    QuoteLanguage.russian: [
      'Ты — та тишина, к которой моё сердце всегда возвращается.',
      'В твоём голосе есть что-то похожее на дом.',
      'Рядом с тобой даже обычный день становится дорогим.',
    ],
    QuoteLanguage.hebrew: [
      'את המקום שבו הלב שלי תמיד מרגיש בבית.',
      'בקול שלך יש שקט שלא מצאתי בשום מקום אחר.',
      'איתך גם יום רגיל הופך לזיכרון יקר.',
    ],
    QuoteLanguage.spanish: [
      'Eres la calma a la que mi corazón siempre vuelve.',
      'En tu voz encontré el camino a casa.',
      'Contigo, los días más sencillos se vuelven inolvidables.',
    ],
    QuoteLanguage.german: [
      'Du bist die Ruhe, zu der mein Herz immer zurückkehrt.',
      'In deiner Stimme habe ich ein Zuhause gefunden.',
      'Mit dir werden gewöhnliche Tage kostbar.',
    ],
    QuoteLanguage.italian: [
      'Sei la calma a cui il mio cuore ritorna sempre.',
      'Nella tua voce ho trovato la strada di casa.',
      'Con te, anche i giorni più semplici diventano preziosi.',
    ],
    QuoteLanguage.turkish: [
      'Sen, kalbimin hep geri döndüğü huzursun.',
      'Sesinin içinde evime giden yolu buldum.',
      'Seninle sıradan günler bile kıymetli oluyor.',
    ],
    QuoteLanguage.urdu: [
      'تم وہ سکون ہو جہاں میرا دل ہمیشہ لوٹ آتا ہے۔',
      'تمہاری آواز میں مجھے اپنا گھر ملتا ہے۔',
      'تمہارے ساتھ عام دن بھی یادگار بن جاتے ہیں۔',
    ],
    QuoteLanguage.chinese: [
      '你是我不安的心，总想回到的宁静。',
      '在你的声音里，我找到了回家的路。',
      '有你在，平凡的日子也变得珍贵。',
    ],
  };
  @override
  Future<Quote> generate(QuoteSettings settings, {String? previous}) async {
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    final now = DateTime.now();
    return Quote(
      id: 'preview-${now.microsecondsSinceEpoch}',
      text: _samples[settings.language]![_index++ % 3],
      settings: settings,
      createdAt: now,
      isPreview: true,
    );
  }

  @override
  void dispose() {}
}
