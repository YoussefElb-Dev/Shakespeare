import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/app_controller.dart';
import 'data/quote_service.dart';
import 'ui/glass.dart';
import 'ui/quote_app.dart';
import 'ui/strings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xff08090b),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  await GlassSurface.initialize();
  const endpoint = String.fromEnvironment('QUOTE_API_URL');
  const preview = bool.fromEnvironment(
    'PREVIEW_MODE',
    defaultValue: endpoint == '',
  );
  final uri = Uri.tryParse(endpoint);
  if (!preview &&
      (uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty)) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Color(0xff08090b),
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'The writing service is not configured.\nBuild with a valid HTTPS QUOTE_API_URL.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ShakespeareApp(
      controller: AppController(
        prefs,
        preview ? PreviewQuoteService() : RemoteQuoteService(uri!),
      ),
    ),
  );
}

class ShakespeareApp extends StatelessWidget {
  const ShakespeareApp({
    super.key,
    required this.controller,
    this.animateOrb = true,
  });
  final AppController controller;
  final bool animateOrb;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final strings = Strings(controller.settings.language);
      return MaterialApp(
        title: 'Shakespeare',
        debugShowCheckedModeBanner: false,
        locale: strings.locale,
        supportedLocales: const [
          Locale('en'),
          Locale('ar'),
          Locale('he'),
          Locale('ur'),
        ],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xff08090b),
          fontFamily: 'Inter',
          fontFamilyFallback: const ['Naskh', 'Hebrew'],
          colorScheme: const ColorScheme.dark(
            primary: Color(0xffd4c5e9),
            surface: Color(0xff171719),
          ),
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.white10,
          textSelectionTheme: const TextSelectionThemeData(
            cursorColor: Color(0xffe1d5f1),
            selectionColor: Color(0xff4b3c61),
          ),
          bottomSheetTheme: const BottomSheetThemeData(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
          ),
          snackBarTheme: const SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xff29272e),
            contentTextStyle: TextStyle(color: Colors.white),
          ),
          inputDecorationTheme: const InputDecorationTheme(
            border: InputBorder.none,
            hintStyle: TextStyle(color: Color(0xff96929e)),
          ),
        ),
        home: QuoteApp(
          controller: controller,
          strings: strings,
          animateOrb: animateOrb,
        ),
      );
    },
  );
}
