import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Applies the same mobile viewport to every route in the application.
///
/// On a real phone the app uses the full device width. In a wide browser or
/// desktop window it is rendered as a centered 430 logical-pixel phone view,
/// so every screen uses the same mobile layout rather than only the home tab.
class MobileViewport extends StatelessWidget {
  final Widget child;

  const MobileViewport({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth > 520
            ? 430.0
            : constraints.maxWidth;

        return ColoredBox(
          color: AppColors.canvas,
          child: Center(
            child: SizedBox(
              width: viewportWidth,
              height: constraints.maxHeight,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
