import 'dart:convert';

enum QuoteCategory {
  romance,
  life,
  motivation,
  friendship,
  success,
  nature,
  philosophy,
  art,
  random,
}

enum QuoteLength { veryShort, short, medium, long }

enum QuoteTone {
  poetic,
  romantic,
  deep,
  motivational,
  funny,
  philosophical,
  modern,
  classic,
}

enum QuoteLanguage {
  english('en', 'English', 'English', '🇬🇧'),
  arabic('ar', 'Arabic', 'العربية', '🇸🇦', rtl: true),
  egyptianArabic('arz', 'Egyptian Arabic', 'مصري', '🇪🇬', rtl: true),
  french('fr', 'French', 'Français', '🇫🇷'),
  russian('ru', 'Russian', 'Русский', '🇷🇺'),
  hebrew('he', 'Hebrew', 'עברית', '🇮🇱', rtl: true),
  spanish('es', 'Spanish', 'Español', '🇪🇸'),
  german('de', 'German', 'Deutsch', '🇩🇪'),
  italian('it', 'Italian', 'Italiano', '🇮🇹'),
  turkish('tr', 'Turkish', 'Türkçe', '🇹🇷'),
  urdu('ur', 'Urdu', 'اردو', '🇵🇰', rtl: true),
  chinese('zh', 'Chinese', '中文', '🇨🇳');

  const QuoteLanguage(
    this.code,
    this.label,
    this.nativeName,
    this.flag, {
    this.rtl = false,
  });
  final String code;
  final String label;
  final String nativeName;
  final String flag;
  final bool rtl;
}

T enumValue<T extends Enum>(List<T> values, Object? value, T fallback) =>
    values.firstWhere((e) => e.name == value, orElse: () => fallback);

class QuoteSettings {
  const QuoteSettings({
    this.language = QuoteLanguage.english,
    this.length = QuoteLength.short,
    this.tone = QuoteTone.poetic,
    this.category = QuoteCategory.romance,
    this.prompt = '',
    this.haptics = true,
  });
  final QuoteLanguage language;
  final QuoteLength length;
  final QuoteTone tone;
  final QuoteCategory category;
  final String prompt;
  final bool haptics;

  QuoteSettings copyWith({
    QuoteLanguage? language,
    QuoteLength? length,
    QuoteTone? tone,
    QuoteCategory? category,
    String? prompt,
    bool? haptics,
  }) => QuoteSettings(
    language: language ?? this.language,
    length: length ?? this.length,
    tone: tone ?? this.tone,
    category: category ?? this.category,
    prompt: prompt ?? this.prompt,
    haptics: haptics ?? this.haptics,
  );

  Map<String, Object> toJson() => {
    'language': language.name,
    'length': length.name,
    'tone': tone.name,
    'category': category.name,
    'prompt': prompt,
    'haptics': haptics,
  };

  factory QuoteSettings.fromJson(Map<String, dynamic> json) => QuoteSettings(
    language: enumValue(
      QuoteLanguage.values,
      json['language'],
      QuoteLanguage.english,
    ),
    length: enumValue(QuoteLength.values, json['length'], QuoteLength.short),
    tone: enumValue(QuoteTone.values, json['tone'], QuoteTone.poetic),
    category: enumValue(
      QuoteCategory.values,
      json['category'],
      QuoteCategory.romance,
    ),
    prompt: json['prompt'] is String
        ? (json['prompt'] as String).substring(
            0,
            (json['prompt'] as String).length.clamp(0, 500),
          )
        : '',
    haptics: json['haptics'] is bool ? json['haptics'] as bool : true,
  );
}

class Quote {
  const Quote({
    required this.id,
    required this.text,
    required this.settings,
    required this.createdAt,
    this.isPreview = false,
  });
  final String id;
  final String text;
  final QuoteSettings settings;
  final DateTime createdAt;
  final bool isPreview;

  Map<String, Object> toJson() => {
    'id': id,
    'text': text,
    'settings': settings.toJson(),
    'createdAt': createdAt.toIso8601String(),
    'isPreview': isPreview,
  };

  factory Quote.fromJson(Map<String, dynamic> json) => Quote(
    id: json['id'] as String,
    text: json['text'] as String,
    settings: QuoteSettings.fromJson(json['settings'] as Map<String, dynamic>),
    createdAt: DateTime.parse(json['createdAt'] as String),
    isPreview: json['isPreview'] == true,
  );

  static List<Quote> decodeList(String? source) {
    if (source == null) return [];
    try {
      final list = jsonDecode(source) as List<dynamic>;
      return list
          .map((e) => Quote.fromJson(e as Map<String, dynamic>))
          .toList();
    } on Object {
      return [];
    }
  }
}
