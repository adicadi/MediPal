import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

Future<T?> showBlurDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  String? barrierLabel,
  bool useSafeArea = true,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  Duration transitionDuration = const Duration(milliseconds: 200),
  double? blurSigma,
}) {
  final resolvedLabel =
      barrierLabel ?? MaterialLocalizations.of(context).modalBarrierDismissLabel;
  final effectiveBlurSigma = blurSigma ??
      (kIsWeb
          ? 0
          : defaultTargetPlatform == TargetPlatform.android
              ? 6
              : 12);

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: resolvedLabel,
    barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.25),
    transitionDuration: transitionDuration,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    pageBuilder: (context, animation, secondaryAnimation) {
      Widget dialog = Builder(builder: builder);
      if (useSafeArea) {
        dialog = SafeArea(child: dialog);
      }

      return Center(child: dialog);
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );

      return Stack(
        children: [
          if (effectiveBlurSigma > 0)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: effectiveBlurSigma,
                  sigmaY: effectiveBlurSigma,
                  tileMode: TileMode.decal,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween(begin: 0.98, end: 1.0).animate(curved),
              child: child,
            ),
          ),
        ],
      );
    },
  );
}
