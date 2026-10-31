import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../data/app_controller.dart';
import '../domain/models.dart';
import 'glass.dart';
import 'liquid_orb.dart';
import 'strings.dart';

enum _Stage { home, categories, customize, generating, quote, library }

class QuoteApp extends StatefulWidget {
  const QuoteApp({
    super.key,
    required this.controller,
    required this.strings,
    this.animateOrb = true,
  });
  final AppController controller;
  final Strings strings;
  final bool animateOrb;
  @override
  State<QuoteApp> createState() => _QuoteAppState();
}

class _QuoteAppState extends State<QuoteApp> {
  _Stage _stage = _Stage.home;
  bool _favorites = true;
  final _prompt = TextEditingController();
  final _customPrompt = TextEditingController();
  AppController get app => widget.controller;
  Strings get s => widget.strings;
  bool get _rtl => Directionality.of(context) == TextDirection.rtl;
  IconData get _backIcon =>
      _rtl ? CupertinoIcons.chevron_forward : CupertinoIcons.chevron_back;
  IconData get _forwardIcon =>
      _rtl ? CupertinoIcons.chevron_back : CupertinoIcons.chevron_forward;
  static const _muted = Color(0xff99949f);
  static const _icons = [
    CupertinoIcons.heart,
    CupertinoIcons.sun_max,
    CupertinoIcons.chart_bar,
    CupertinoIcons.person_2,
    CupertinoIcons.rosette,
    CupertinoIcons.leaf_arrow_circlepath,
    CupertinoIcons.moon,
    CupertinoIcons.paintbrush,
    CupertinoIcons.shuffle,
  ];
  static const _tints = [
    Color(0xffdfb4c2),
    Color(0xffe0b078),
    Color(0xffc9a99f),
    Color(0xffe3c6b2),
    Color(0xffebce8e),
    Color(0xffafd1b6),
    Color(0xffc8bddc),
    Color(0xffdccca0),
    Color(0xffc3c8d8),
  ];
  void _haptic() {
    if (app.settings.haptics) HapticFeedback.selectionClick();
  }

  void _go(_Stage stage) {
    _haptic();
    FocusManager.instance.primaryFocus?.unfocus();
    if (_stage == _Stage.customize) {
      app.updateSettings(
        app.settings.copyWith(prompt: _customPrompt.text.trim()),
      );
    }
    if (stage == _Stage.customize) _customPrompt.text = app.settings.prompt;
    setState(() => _stage = stage);
  }

  void _back() {
    if (_stage == _Stage.generating) app.cancelGeneration();
    _go(switch (_stage) {
      _Stage.customize => _Stage.categories,
      _Stage.quote => _Stage.customize,
      _Stage.generating =>
        app.current == null ? _Stage.customize : _Stage.quote,
      _ => _Stage.home,
    });
  }

  Future<void> _generate() async {
    _go(_Stage.generating);
    final success = await app.generate();
    if (!mounted || _stage != _Stage.generating) return;
    if (success) {
      if (app.settings.haptics) HapticFeedback.lightImpact();
      setState(() => _stage = _Stage.quote);
    } else {
      setState(
        () => _stage = app.current == null ? _Stage.customize : _Stage.quote,
      );
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(s.t('error')),
          content: Text(app.error ?? s.t('tryAgain')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(s.t('cancel')),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _generate();
              },
              child: Text(s.t('tryAgain')),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _stage == _Stage.home,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _back();
    },
    child: Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 420),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeIn,
              child: KeyedSubtree(
                key: ValueKey(_stage),
                child: switch (_stage) {
                  _Stage.home => _home(),
                  _Stage.categories => _categories(),
                  _Stage.customize => _customize(),
                  _Stage.generating => _generating(),
                  _Stage.quote => _quote(),
                  _Stage.library => _library(),
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _bar({bool close = false, bool more = false}) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 12, 22, 4),
    child: Row(
      children: [
        if (_stage != _Stage.home)
          RoundButton(
            icon: close ? CupertinoIcons.xmark : _backIcon,
            label: s.t(close ? 'close' : 'back'),
            onTap: close ? () => _go(_Stage.home) : _back,
          ),
        const Spacer(),
        if (more)
          RoundButton(
            icon: CupertinoIcons.ellipsis,
            label: s.t('more'),
            onTap: _menu,
          ),
      ],
    ),
  );

  Widget _home() => Column(
    children: [
      _bar(more: true),
      Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: math.min(440, constraints.maxWidth + 20),
                    height: math.min(
                      400,
                      math.max(200, constraints.maxHeight * 0.67),
                    ),
                    child: LiquidOrb(animate: widget.animateOrb),
                  ),
                  Text(
                    s.t('invitation'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      height: 1.55,
                      fontWeight: FontWeight.w300,
                      color: Color(0xffd2c9df),
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
        child: GlassSurface(
          native: true,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 20, end: 4),
            child: Row(
              children: [
                const Icon(
                  CupertinoIcons.search,
                  size: 20,
                  color: Color(0xffd7d1df),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    key: const Key('home-prompt'),
                    controller: _prompt,
                    maxLength: 500,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: s.t('search'),
                      counterText: '',
                    ),
                    textInputAction: TextInputAction.go,
                    onSubmitted: (_) => _startFromPrompt(),
                  ),
                ),
                IconButton(
                  key: const Key('start'),
                  tooltip: s.t('generate'),
                  onPressed: _startFromPrompt,
                  icon: Icon(
                    _rtl
                        ? CupertinoIcons.arrow_left
                        : CupertinoIcons.arrow_right,
                    size: 21,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      TextButton(
        key: const Key('categories'),
        onPressed: () => _go(_Stage.categories),
        child: Text(
          s.t('explore'),
          style: const TextStyle(color: _muted, fontSize: 12),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          s.t(app.isPreview ? 'preview' : 'live'),
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 0.5,
            color: _muted.withValues(alpha: 0.7),
          ),
        ),
      ),
    ],
  );

  void _startFromPrompt() {
    app.updateSettings(app.settings.copyWith(prompt: _prompt.text.trim()));
    _go(_prompt.text.trim().isEmpty ? _Stage.categories : _Stage.customize);
  }

  Widget _heading(String title, {String? subtitle}) => Padding(
    padding: const EdgeInsets.fromLTRB(26, 20, 26, 22),
    child: Align(
      alignment: AlignmentDirectional.centerStart,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.8,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 9),
            Text(subtitle, style: const TextStyle(fontSize: 13, color: _muted)),
          ],
        ],
      ),
    ),
  );

  Widget _categories() => Column(
    children: [
      _bar(close: true),
      _heading(s.t('categories')),
      Expanded(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          itemCount: QuoteCategory.values.length,
          separatorBuilder: (_, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final category = QuoteCategory.values[index];
            return _row(
              label: s.label(category),
              icon: _icons[index],
              tint: _tints[index],
              onTap: () {
                app.updateSettings(app.settings.copyWith(category: category));
                _go(_Stage.customize);
              },
            );
          },
        ),
      ),
    ],
  );

  Widget _row({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    String? detail,
    Color tint = const Color(0xffe0d8e7),
    bool selected = false,
  }) => GlassSurface(
    radius: 24,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
          child: Row(
            children: [
              Icon(icon, color: tint, size: 23),
              const SizedBox(width: 18),
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: 14)),
              ),
              if (detail != null) ...[
                Flexible(
                  child: Text(
                    detail,
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontSize: 12, color: _muted),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Icon(
                selected ? CupertinoIcons.checkmark : _forwardIcon,
                size: 16,
                color: const Color(0xffb2adb8),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _customize() => Column(
    children: [
      _bar(),
      _heading(s.t('customize'), subtitle: s.label(app.settings.category)),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          children: [
            _caption(s.t('language')),
            _row(
              label: app.settings.language.nativeName,
              icon: CupertinoIcons.globe,
              onTap: _languages,
            ),
            const SizedBox(height: 26),
            _caption(s.t('length')),
            _row(
              label: s.label(app.settings.length),
              icon: CupertinoIcons.text_alignleft,
              onTap: _lengths,
            ),
            const SizedBox(height: 26),
            _caption(s.t('tone')),
            _row(
              label: s.label(app.settings.tone),
              icon: CupertinoIcons.sparkles,
              tint: const Color(0xffd5afd9),
              onTap: _tones,
            ),
            const SizedBox(height: 26),
            _caption(s.t('yourPrompt')),
            GlassSurface(
              radius: 22,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 4,
                ),
                child: TextField(
                  key: const Key('custom-prompt'),
                  controller: _customPrompt,
                  maxLength: 500,
                  minLines: 2,
                  maxLines: 4,
                  style: const TextStyle(fontSize: 14, height: 1.6),
                  decoration: InputDecoration(
                    hintText: s.t('optional'),
                    counterStyle: const TextStyle(color: _muted, fontSize: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        child: Column(
          children: [
            if (app.isPreview) ...[
              Text(
                s.t('previewDetail'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.6,
                  color: _muted,
                ),
              ),
              const SizedBox(height: 16),
            ],
            GlassButton(
              key: const Key('generate'),
              label: s.t('generate'),
              light: true,
              icon: CupertinoIcons.sparkles,
              onTap: _generate,
            ),
          ],
        ),
      ),
    ],
  );
  Widget _caption(String text) => Padding(
    padding: const EdgeInsetsDirectional.only(start: 4, bottom: 10),
    child: Text(text, style: const TextStyle(fontSize: 13, color: _muted)),
  );

  Widget _generating() => Column(
    children: [
      _bar(),
      Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: math.min(420, constraints.maxHeight * 0.68),
                width: constraints.maxWidth,
                child: LiquidOrb(energy: 1, animate: widget.animateOrb),
              ),
              Semantics(
                liveRegion: true,
                child: Text(
                  s.t('creating'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.7,
                    color: _muted,
                  ),
                ),
              ),
              const SizedBox(height: 70),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _quote() {
    final quote = app.current!;
    final language = quote.settings.language;
    return Column(
      children: [
        _bar(more: true),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: constraints.maxWidth + 70,
                  height: math.min(constraints.maxHeight + 80, 600),
                  child: Transform.scale(
                    scale: 1.2,
                    child: LiquidOrb(
                      hue: quote.settings.category.index * 0.2,
                      energy: 0.35,
                      animate: widget.animateOrb,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: math.max(80, constraints.maxHeight * 0.64),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SelectableText(
                            quote.text,
                            key: const Key('quote-text'),
                            textAlign: TextAlign.center,
                            textDirection: language.rtl
                                ? TextDirection.rtl
                                : TextDirection.ltr,
                            style: TextStyle(
                              fontFamily: language == QuoteLanguage.hebrew
                                  ? 'Hebrew'
                                  : language.rtl
                                  ? 'Naskh'
                                  : 'Cormorant',
                              fontSize: quote.text.length > 350 ? 24 : 29,
                              height: language.rtl ? 1.9 : 1.32,
                              color: const Color(0xfff4ecf4),
                              fontWeight: FontWeight.w400,
                              shadows: const [
                                Shadow(color: Colors.black, blurRadius: 12),
                              ],
                            ),
                          ),
                          const SizedBox(height: 26),
                          Container(
                            width: 30,
                            height: 0.7,
                            color: const Color(0xffb2a3b4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(38, 8, 38, 22),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              RoundButton(
                icon: CupertinoIcons.doc_on_doc,
                label: s.t('copy'),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: quote.text));
                  if (mounted) _toast(s.t('copied'));
                },
              ),
              RoundButton(
                key: const Key('favorite'),
                icon: app.isFavorite(quote)
                    ? CupertinoIcons.heart_fill
                    : CupertinoIcons.heart,
                label: s.t(app.isFavorite(quote) ? 'unfavorite' : 'favorite'),
                selected: app.isFavorite(quote),
                onTap: () {
                  _haptic();
                  app.toggleFavorite(quote);
                  _toast(s.t(app.isFavorite(quote) ? 'saved' : 'removed'));
                },
              ),
              Builder(
                builder: (shareContext) => RoundButton(
                  icon: CupertinoIcons.share,
                  label: s.t('share'),
                  onTap: () async {
                    final box = shareContext.findRenderObject()! as RenderBox;
                    try {
                      await SharePlus.instance.share(
                        ShareParams(
                          text: quote.text,
                          sharePositionOrigin:
                              box.localToGlobal(Offset.zero) & box.size,
                        ),
                      );
                    } on Object {
                      if (mounted) _toast(s.t('shareError'));
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: GlassButton(
            key: const Key('regenerate'),
            label: s.t('again'),
            icon: CupertinoIcons.refresh,
            onTap: _generate,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
          child: Text(
            quote.isPreview
                ? s.t('previewQuote')
                : '${language.nativeName} · ${s.label(quote.settings.category)} · ${s.label(quote.settings.tone)}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, color: _muted),
          ),
        ),
      ],
    );
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _sheet(Widget child) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.86,
        maxWidth: 540,
      ),
      decoration: BoxDecoration(
        color: const Color(0xff101113).withValues(alpha: 0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
          child: child,
        ),
      ),
    ),
  );

  Widget _sheetHeading(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Row(
      children: [
        RoundButton(
          icon: CupertinoIcons.xmark,
          label: s.t('close'),
          onTap: () => Navigator.pop(context),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
  );

  Future<void> _languages() async {
    var search = '';
    await _sheet(
      StatefulBuilder(
        builder: (context, setSheet) {
          final languages = QuoteLanguage.values
              .where(
                (l) => '${l.label} ${l.nativeName}'.toLowerCase().contains(
                  search.toLowerCase(),
                ),
              )
              .toList();
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _sheetHeading(s.t('language')),
              GlassSurface(
                radius: 16,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    autocorrect: false,
                    decoration: InputDecoration(
                      hintText: s.t('searchLanguage'),
                      prefixIcon: const Icon(CupertinoIcons.search, size: 17),
                    ),
                    onChanged: (value) => setSheet(() => search = value),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Flexible(
                child: languages.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(s.t('noLanguage')),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: languages.length,
                        separatorBuilder: (_, index) =>
                            const Divider(height: 1, color: Color(0xff242426)),
                        itemBuilder: (context, index) {
                          final language = languages[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 5,
                            ),
                            leading: Text(
                              language.flag,
                              style: const TextStyle(fontSize: 24),
                            ),
                            title: Text(
                              language.label,
                              style: const TextStyle(fontSize: 14),
                            ),
                            subtitle: language.label != language.nativeName
                                ? Text(
                                    language.nativeName,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: _muted,
                                    ),
                                  )
                                : null,
                            trailing: app.settings.language == language
                                ? const Icon(CupertinoIcons.checkmark, size: 18)
                                : null,
                            onTap: () {
                              _haptic();
                              Navigator.pop(context);
                              app.updateSettings(
                                app.settings.copyWith(language: language),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _lengths() => _sheet(
    Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _sheetHeading(s.t('length')),
        ...QuoteLength.values.map(
          (length) => Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: _row(
              label: s.label(length),
              detail: s.t('${length.name}Hint'),
              icon: CupertinoIcons.text_alignleft,
              selected: app.settings.length == length,
              onTap: () {
                _haptic();
                app.updateSettings(app.settings.copyWith(length: length));
                Navigator.pop(context);
              },
            ),
          ),
        ),
      ],
    ),
  );

  Future<void> _tones() => _sheet(
    Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _sheetHeading(s.t('tone')),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: QuoteTone.values
                .map(
                  (tone) => Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: _row(
                      label: s.label(tone),
                      icon: CupertinoIcons.sparkles,
                      selected: app.settings.tone == tone,
                      onTap: () {
                        _haptic();
                        app.updateSettings(app.settings.copyWith(tone: tone));
                        Navigator.pop(context);
                      },
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    ),
  );

  Future<void> _menu() => _sheet(
    Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _sheetHeading('Shakespeare'),
        _row(
          label: s.t('favorites'),
          icon: CupertinoIcons.heart,
          onTap: () {
            Navigator.pop(context);
            _favorites = true;
            _go(_Stage.library);
          },
        ),
        const SizedBox(height: 8),
        _row(
          label: s.t('history'),
          icon: CupertinoIcons.clock,
          onTap: () {
            Navigator.pop(context);
            _favorites = false;
            _go(_Stage.library);
          },
        ),
        const SizedBox(height: 12),
        StatefulBuilder(
          builder: (context, update) => SwitchListTile.adaptive(
            title: Text(s.t('haptics'), style: const TextStyle(fontSize: 14)),
            value: app.settings.haptics,
            onChanged: (value) {
              app.updateSettings(app.settings.copyWith(haptics: value));
              update(() {});
            },
          ),
        ),
        ListTile(
          leading: const Icon(CupertinoIcons.lock, size: 20),
          title: Text(s.t('privacy'), style: const TextStyle(fontSize: 14)),
          onTap: () {
            Navigator.pop(context);
            _info(s.t('privacy'), s.t('privacyBody'));
          },
        ),
        const Divider(color: Color(0xff28272c)),
        ListTile(
          leading: Icon(
            app.isPreview ? CupertinoIcons.moon_stars : CupertinoIcons.sparkles,
            size: 20,
          ),
          title: Text(
            s.t(app.isPreview ? 'preview' : 'connection'),
            style: const TextStyle(fontSize: 12, color: _muted),
          ),
          onTap: app.isPreview
              ? () {
                  Navigator.pop(context);
                  _info(s.t('preview'), s.t('previewDetail'));
                }
              : null,
        ),
        const Text('1.0.0', style: TextStyle(color: _muted, fontSize: 10)),
      ],
    ),
  );

  Future<void> _info(String title, String body) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Text(body, style: const TextStyle(height: 1.6)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.t('done')),
        ),
      ],
    ),
  );

  Widget _library() {
    final quotes = _favorites ? app.favorites : app.history;
    return Column(
      children: [
        _bar(close: true),
        _heading(s.t('library')),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SizedBox(
            width: double.infinity,
            child: CupertinoSlidingSegmentedControl<bool>(
              groupValue: _favorites,
              thumbColor: const Color(0xff3c3743),
              backgroundColor: const Color(0xff17171b),
              children: {
                true: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    s.t('favorites'),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                false: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    s.t('history'),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              },
              onValueChanged: (value) {
                if (value != null) setState(() => _favorites = value);
              },
            ),
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: quotes.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _favorites
                              ? CupertinoIcons.heart
                              : CupertinoIcons.clock,
                          color: const Color(0xff92819f),
                          size: 32,
                        ),
                        const SizedBox(height: 22),
                        Text(
                          s.t(_favorites ? 'emptyFavorites' : 'emptyHistory'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w300,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          s.t(_favorites ? 'savedHint' : 'historyHint'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 13,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  itemCount: quotes.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final quote = quotes[index];
                    return GlassSurface(
                      radius: 22,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            app.openQuote(quote);
                            _go(_Stage.quote);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(21),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  quote.text,
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                  textDirection: quote.settings.language.rtl
                                      ? TextDirection.rtl
                                      : TextDirection.ltr,
                                  style: TextStyle(
                                    fontFamily: quote.settings.language.rtl
                                        ? 'Naskh'
                                        : 'Cormorant',
                                    fontSize: 22,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${quote.settings.language.nativeName} · ${s.label(quote.settings.category)}',
                                        style: const TextStyle(
                                          color: _muted,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      app.isFavorite(quote)
                                          ? CupertinoIcons.heart_fill
                                          : _forwardIcon,
                                      size: 14,
                                      color: const Color(0xffc3a6cb),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (!_favorites && quotes.isNotEmpty)
          TextButton(
            onPressed: _clearHistory,
            child: Text(s.t('clear'), style: const TextStyle(color: _muted)),
          ),
        const SizedBox(height: 12),
      ],
    );
  }

  Future<void> _clearHistory() async {
    final clear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.t('clearQuestion')),
        content: Text(s.t('clearDetail')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.t('clear')),
          ),
        ],
      ),
    );
    if (clear == true) app.clearHistory();
  }

  @override
  void dispose() {
    _prompt.dispose();
    _customPrompt.dispose();
    super.dispose();
  }
}
