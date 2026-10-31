import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../data/asechka_service.dart';
import '../domain/models.dart';
import 'strings.dart';

class AsechkaButton extends StatefulWidget {
  const AsechkaButton({
    super.key,
    required this.quote,
    required this.strings,
    this.service,
  });

  final Quote? quote;
  final Strings strings;
  final AsechkaService? service;

  @override
  State<AsechkaButton> createState() => _AsechkaButtonState();
}

class _AsechkaButtonState extends State<AsechkaButton> {
  late final _service = widget.service ?? AsechkaService();
  bool _busy = false;
  bool _posted = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant AsechkaButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.quote?.id != oldWidget.quote?.id) {
      _posted = false;
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final quote = widget.quote;
    if (quote == null) return;
    try {
      final posted = await _service.isPosted(quote);
      if (mounted && widget.quote?.id == quote.id) {
        setState(() => _posted = posted);
      }
    } on Object {
      // A storage error must never make an unconfirmed post look successful.
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _add() async {
    final quote = widget.quote;
    if (_busy || _posted || quote == null) return;
    setState(() => _busy = true);
    try {
      try {
        await _service.publish(quote);
      } on AsechkaException catch (error) {
        if (!error.needsSignIn) rethrow;
        if (!mounted) return;
        final connected = await showDialog<bool>(
          context: context,
          builder: (context) =>
              _AsechkaSignIn(service: _service, strings: widget.strings),
        );
        if (connected != true) return;
        // Resume only the quote selected by the original explicit button tap.
        await _service.publish(quote);
      }
      if (!mounted) return;
      if (widget.quote?.id == quote.id) setState(() => _posted = true);
      _message(widget.strings.t('asechkaAddedDetail'));
    } on AsechkaException catch (error) {
      if (mounted) _message(error.message);
    } on Object {
      if (mounted) _message(widget.strings.t('asechkaError'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => TextButton.icon(
    key: const Key('add-to-asechka'),
    onPressed: _busy || _posted || widget.quote == null ? null : _add,
    style: TextButton.styleFrom(
      foregroundColor: const Color(0xffd4bddf),
      disabledForegroundColor: const Color(0xffb9b2bf),
      minimumSize: const Size(44, 44),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
    ),
    icon: _busy
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          )
        : Icon(
            _posted ? CupertinoIcons.checkmark_circle : CupertinoIcons.plus_app,
            size: 17,
          ),
    label: Text(
      widget.strings.t(
        _busy
            ? 'asechkaAdding'
            : _posted
            ? 'asechkaAdded'
            : 'asechkaAdd',
      ),
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 12),
    ),
  );

  @override
  void dispose() {
    if (widget.service == null) _service.dispose();
    super.dispose();
  }
}

class _AsechkaSignIn extends StatefulWidget {
  const _AsechkaSignIn({required this.service, required this.strings});
  final AsechkaService service;
  final Strings strings;

  @override
  State<_AsechkaSignIn> createState() => _AsechkaSignInState();
}

class _AsechkaSignInState extends State<_AsechkaSignIn> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _connect() async {
    if (_busy || _code.text.isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final code = _code.text;
      _code.clear();
      await widget.service.signIn(code);
      if (mounted) Navigator.pop(context, true);
    } on AsechkaException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Object {
      if (mounted) setState(() => _error = widget.strings.t('asechkaError'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.strings.t('asechkaConnect')),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.strings.t('asechkaConnectDetail'),
            style: const TextStyle(fontSize: 14, height: 1.6),
          ),
          const SizedBox(height: 20),
          TextField(
            key: const Key('asechka-code'),
            controller: _code,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            enabled: !_busy,
            maxLength: 256,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _connect(),
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            decoration: InputDecoration(
              labelText: widget.strings.t('asechkaCode'),
              counterText: '',
              errorText: _error,
              errorMaxLines: 3,
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: Text(widget.strings.t('cancel')),
      ),
      TextButton(
        key: const Key('asechka-connect'),
        onPressed: _busy ? null : _connect,
        child: Text(
          widget.strings.t(_busy ? 'asechkaConnecting' : 'asechkaConnectAdd'),
        ),
      ),
    ],
  );

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }
}
