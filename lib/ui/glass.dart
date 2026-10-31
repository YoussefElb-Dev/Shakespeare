import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = 28,
    this.light = false,
    this.native = false,
  });
  final Widget child;
  final double radius;
  final bool light;
  final bool native;
  static bool nativeAvailable = false;
  static Future<void> initialize() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        nativeAvailable =
            await const MethodChannel(
              'app.shakespeare/glass',
            ).invokeMethod<bool>('isAvailable') ??
            false;
      } on PlatformException {
        nativeAvailable = false;
      } on MissingPluginException {
        nativeAvailable = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: Stack(
      fit: StackFit.passthrough,
      children: [
        if (native && nativeAvailable && !light)
          const Positioned.fill(
            child: IgnorePointer(
              child: UiKitView(
                viewType: 'app.shakespeare/glass-surface',
                creationParamsCodec: StandardMessageCodec(),
              ),
            ),
          )
        else
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: light
                        ? [const Color(0xfff1f0ee), const Color(0xffd8d6dd)]
                        : [
                            Colors.white.withValues(alpha: 0.105),
                            Colors.white.withValues(alpha: 0.045),
                          ],
                  ),
                ),
              ),
            ),
          ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: Colors.white.withValues(alpha: light ? 0.5 : 0.13),
                width: 0.7,
              ),
            ),
          ),
        ),
        child,
      ],
    ),
  );
}

class GlassButton extends StatelessWidget {
  const GlassButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.light = false,
  });
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool light;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    child: GlassSurface(
      light: light,
      native: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 58),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: 19,
                      color: light ? Colors.black : Colors.white,
                    ),
                    const SizedBox(width: 12),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: light ? Colors.black : Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class RoundButton extends StatelessWidget {
  const RoundButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 48,
    height: 48,
    child: Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: GlassSurface(
          radius: 30,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: Icon(
                icon,
                size: 21,
                color: selected
                    ? const Color(0xffe6b9ca)
                    : const Color(0xffece9f2),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
