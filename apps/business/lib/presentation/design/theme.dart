// lib/presentation/design/theme.dart
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'tokens.dart';

/// App-wide [ThemeData]. Screens are built from the `components/` widgets, but
/// anything Material draws for us (dialogs, pickers, snackbars, text fields in
/// legacy screens, switches, tab bars) picks the look up from here.
abstract final class BizTheme {
  static ThemeData light() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: BizColors.green,
          brightness: Brightness.light,
        ).copyWith(
          primary: BizColors.green,
          onPrimary: Colors.white,
          secondary: BizColors.mint,
          onSecondary: BizColors.onMint,
          error: BizColors.badge,
          surface: Colors.white,
          onSurface: BizColors.ink,
          surfaceContainerHighest: BizColors.page,
        );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: BizText.family,
      scaffoldBackgroundColor: BizColors.page,
      canvasColor: BizColors.page,
      splashFactory: NoSplash.splashFactory,
      highlightColor: BizColors.ink.withValues(alpha: 0.05),
      visualDensity: VisualDensity.standard,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );

    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(BizRadius.field),
          borderSide: BorderSide(color: color, width: width),
        );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        fontFamily: BizText.family,
        bodyColor: BizColors.ink,
        displayColor: BizColors.ink,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: BizColors.page,
        surfaceTintColor: Colors.transparent,
        foregroundColor: BizColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: BizText.pushedTitle,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BizRadius.card),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: BizColors.hairline,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: BizText.input.copyWith(
          color: BizColors.inkSoft.withValues(alpha: 0.7),
          fontWeight: FontWeight.w400,
        ),
        labelStyle: BizText.fieldLabel,
        floatingLabelStyle: BizText.fieldLabel.copyWith(color: BizColors.green),
        errorStyle: BizText.caption.copyWith(color: BizColors.dangerInk),
        border: border(BizColors.fieldBorder),
        enabledBorder: border(BizColors.fieldBorder),
        focusedBorder: border(BizColors.green, 1.6),
        errorBorder: border(BizColors.badge),
        focusedErrorBorder: border(BizColors.badge, 1.6),
        disabledBorder: border(BizColors.fieldBorder),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: BizColors.green,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: BizText.cta,
          shape: const StadiumBorder(),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: BizColors.green,
          foregroundColor: Colors.white,
          textStyle: BizText.cta,
          shape: const StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: BizColors.ink,
          side: const BorderSide(color: BizColors.fieldBorder),
          textStyle: BizText.bodyStrong,
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: BizColors.green,
          textStyle: BizText.bodyStrong,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: BizColors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: StadiumBorder(),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: BizColors.card,
        contentTextStyle: BizText.style(14, 500, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BizRadius.hero),
        ),
        titleTextStyle: BizText.style(20, 700, letterSpacing: -0.3),
        contentTextStyle: BizText.body.copyWith(color: BizColors.inkSoft),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: BizColors.ink,
        unselectedLabelColor: BizColors.inkSoft,
        labelStyle: BizText.style(15, 600),
        unselectedLabelStyle: BizText.style(15, 500),
        indicatorColor: BizColors.green,
        dividerColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? BizColors.green
              : BizColors.fieldBorder,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? BizColors.green
              : Colors.transparent,
        ),
        side: const BorderSide(color: BizColors.inkSoft, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? BizColors.green
              : BizColors.inkSoft,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: BizColors.card,
        labelStyle: BizText.chip,
        side: BorderSide.none,
        shape: const StadiumBorder(),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: BizColors.green,
        circularTrackColor: BizColors.track,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: BizColors.inkSoft,
        titleTextStyle: BizText.cardTitle,
        subtitleTextStyle: BizText.rowSubtitle,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BizRadius.hero),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: BizColors.green,
        selectionColor: BizColors.green.withValues(alpha: 0.25),
        selectionHandleColor: BizColors.green,
      ),
    );
  }
}
