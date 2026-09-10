import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

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
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor ?? AppColors.background,
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: centerTitle,
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: AppColors.border,
        iconTheme: const IconThemeData(color: AppColors.secondary),
        actions: actions,
        bottom: bottom,
      ),
      body: body,
      drawer: drawer,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      bottomSheet: bottomSheet,
    );
  }
}
