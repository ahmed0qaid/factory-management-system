import 'package:flutter/material.dart';

class AppScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final Widget? bottomSheet;
  final Widget? drawer;
  final PreferredSizeWidget? bottom;
  final bool centerTitle;
  final bool showAppBar;
  final Color? backgroundColor;

  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.bottomSheet,
    this.drawer,
    this.bottom,
    this.centerTitle = false,
    this.showAppBar = true,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: backgroundColor ?? theme.scaffoldBackgroundColor,
      appBar: showAppBar
          ? AppBar(
              title: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.appBarTheme.titleTextStyle ??
                    theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.onSurface,
                    ),
              ),
              centerTitle: centerTitle,
              backgroundColor:
                  theme.appBarTheme.backgroundColor ?? colors.surface,
              foregroundColor:
                  theme.appBarTheme.foregroundColor ?? colors.onSurface,
              elevation: 0,
              scrolledUnderElevation: 1,
              shadowColor: colors.outlineVariant,
              iconTheme: theme.appBarTheme.iconTheme ??
                  IconThemeData(color: colors.onSurfaceVariant),
              actionsIconTheme: theme.appBarTheme.actionsIconTheme ??
                  IconThemeData(color: colors.onSurfaceVariant),
              actions: actions,
              bottom: bottom,
            )
          : null,
      body: body,
      drawer: drawer,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      bottomSheet: bottomSheet,
    );
  }
}
