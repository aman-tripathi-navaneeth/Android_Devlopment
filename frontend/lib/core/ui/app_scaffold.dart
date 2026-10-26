import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// AppScaffold: canvas background, safe areas, optional sticky footer (PART 4.7).
/// The global [MobileViewport] in MaterialApp.builder applies the mobile frame
/// to every route, including screens that use their own Scaffold.
class AppScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? bottomSheet;
  final Widget? floatingActionButton;
  final Color? backgroundColor;

  const AppScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
    this.bottomSheet,
    this.floatingActionButton,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Scaffold(
          backgroundColor: backgroundColor ?? AppColors.canvas,
          appBar: appBar,
          body: body,
          bottomNavigationBar: bottomNavigationBar,
          bottomSheet: bottomSheet,
          floatingActionButton: floatingActionButton,
        );
      },
    );
  }
}
