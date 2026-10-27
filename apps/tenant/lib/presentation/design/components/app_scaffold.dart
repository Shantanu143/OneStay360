// lib/presentation/design/components/app_scaffold.dart
import 'package:flutter/material.dart';

import '../tokens.dart';
import 'app_header.dart';

/// Scaffold for pushed (non-tab) pages: pinned header on top, [body] filling
/// the rest and an optional sticky [bottomBar] (primary action) above the
/// home indicator.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.eyebrow,
    this.actions = const [],
    this.showBack,
    this.onBack,
    this.bottomBar,
    this.belowHeader,
    this.floatingActionButton,
    this.resizeToAvoidBottomInset = true,
  });

  final String title;
  final String? eyebrow;
  final List<Widget> actions;

  /// Null shows the back button whenever the route can be popped.
  final bool? showBack;
  final VoidCallback? onBack;
  final Widget body;
  final Widget? bottomBar;

  /// Pinned between the header and the body (step pills, search, tabs).
  final Widget? belowHeader;
  final Widget? floatingActionButton;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    final canPop = showBack ?? ModalRoute.of(context)?.canPop ?? false;

    return Scaffold(
      backgroundColor: AppColors.page,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      floatingActionButton: floatingActionButton,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: AppHeader(
                title: title,
                eyebrow: eyebrow,
                actions: actions,
                showBack: canPop,
                onBack: onBack,
              ),
            ),
          ),
          if (belowHeader != null) belowHeader!,
          Expanded(child: body),
          if (bottomBar != null) _BottomBar(child: bottomBar!),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewPaddingOf(context).bottom;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.page.withValues(alpha: 0), AppColors.page],
          stops: const [0, 0.35],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 12 + inset),
        child: child,
      ),
    );
  }
}

/// Scrolling page used by the tab roots (Home, Properties, Reports...): the
/// header scrolls away with the content and leaves room for the floating nav.
class AppScrollPage extends StatelessWidget {
  const AppScrollPage({
    super.key,
    required this.title,
    required this.slivers,
    this.eyebrow,
    this.actions = const [],
    this.bottomInset = 0,
    this.onRefresh,
    this.controller,
    this.topPadding = 4,
  });

  final String title;
  final String? eyebrow;
  final List<Widget> actions;
  final List<Widget> slivers;

  /// Extra space at the bottom (use [FloatingNavBar.heightFor] + margin).
  final double bottomInset;
  final Future<void> Function()? onRefresh;
  final ScrollController? controller;

  /// Space between the status bar and the header.
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    final scroll = CustomScrollView(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, topInset + topPadding, 16, 18),
          sliver: SliverToBoxAdapter(
            child: AppHeader(title: title, eyebrow: eyebrow, actions: actions),
          ),
        ),
        ...slivers,
        SliverToBoxAdapter(child: SizedBox(height: bottomInset)),
      ],
    );

    if (onRefresh == null) return scroll;
    return RefreshIndicator(
      color: AppColors.green,
      backgroundColor: Colors.white,
      edgeOffset: topInset + 8,
      onRefresh: onRefresh!,
      child: scroll,
    );
  }
}
