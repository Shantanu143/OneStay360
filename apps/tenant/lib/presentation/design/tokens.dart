// lib/presentation/design/tokens.dart
//
// Design tokens for the tenant app (same palette as the business app). Values were sampled from the approved
// mock-ups (Home, Properties, Add Tenant).
import 'package:flutter/material.dart';

abstract final class AppColors {
  static const page = Color(0xFFF2F2F7);
  static const surface = Colors.white;

  static const ink = Color(0xFF111916);
  static const inkSoft = Color(0xFF5F6A66);
  static const navLabel = Color(0xFF3C4743);
  static const chevron = Color(0xFFA3A3A8);
  static const hairline = Color(0xFFF1F1F4);
  static const track = Color(0xFFE6E9E8);

  static const green = Color(0xFF0E7C66);
  static const greenDeep = Color(0xFF0A6C58);
  static const greenTint = Color(0xFFDEEEE7);
  static const mint = Color(0xFF5DD6B3);

  /// Dark hero card and the things drawn on it.
  static const card = Color(0xFF12241F);
  static const cardTile = Color(0xFF23332F);
  static const cardPill = Color(0xFF253531);
  static const onCardMuted = Color(0xFFB9CCC5);
  static const onMint = Color(0xFF0B1F19);
  static const amber = Color(0xFFFDBA74);

  static const orange = Color(0xFFF28C28);
  static const blue = Color(0xFF2F6FE4);
  static const badge = Color(0xFFD7261E);
  static const navSelected = Color(0xFFE7E9EA);

  // Form + list surfaces
  static const searchField = Color(0xFFE5E5EA);
  static const photo = Color(0xFFDCE5E1);
  static const photoInk = Color(0xFF6B7773);
  static const fieldBorder = Color(0xFFE2E4E3);

  // Semantic tones (a pill/banner pairs a tint with its ink)
  static const draftInk = Color(0xFF7A3E06);
  static const warnTint = Color(0xFFFFF1E0);
  static const warnInk = Color(0xFF92400E);
  static const lastBed = Color(0xFFB4530A);
  static const dangerTint = Color(0xFFFDECEA);
  static const dangerInk = Color(0xFFB42318);
  static const infoTint = Color(0xFFE6EEFD);
  static const infoInk = Color(0xFF1F4FB5);

  // Beds
  static const bedOccupied = Color(0xFFF5F5F9);
  static const bedOccupiedInk = Color(0xFFB4B9B7);
  static const dotEmpty = Color(0xFFE5E5EA);
  static const dotEmptyOnDark = Color(0xFF3D4C47);
}

abstract final class AppRadius {
  static const double hero = 28;
  static const double card = 22;
  static const double control = 16;
  static const double field = 14;
}

/// Inter text styles. The font is a single variable file, so the weight is
/// set on the `wght` axis as well as `fontWeight` (which keeps semantics and
/// fallback fonts consistent). Line height is always explicit: the font's own
/// metrics are ~1.44x, which would make every row taller than designed.
abstract final class AppText {
  static const family = 'Inter';

  static const _tabular = [FontFeature.tabularFigures()];

  static TextStyle style(
    double size,
    int weight, {
    Color color = AppColors.ink,
    double letterSpacing = 0,
    double height = 1.25,
    bool tabular = false,
  }) {
    return TextStyle(
      fontFamily: family,
      fontSize: size,
      fontWeight: FontWeight.values[(weight ~/ 100) - 1],
      fontVariations: [FontVariation('wght', weight.toDouble())],
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      fontFeatures: tabular ? _tabular : null,
      decoration: TextDecoration.none,
    );
  }

  // Page chrome
  static final eyebrow = style(15, 500, color: AppColors.inkSoft);
  static final pageTitle = style(34, 700, letterSpacing: -0.95, height: 1.1);
  static final pushedTitle = style(26, 700, letterSpacing: -0.6, height: 1.15);
  static final sectionLabel = style(
    13,
    600,
    color: AppColors.inkSoft,
    letterSpacing: 0.9,
  );
  static final chip = style(15, 600);
  static final chipCount = style(14, 500, color: AppColors.inkSoft);
  static final cta = style(17, 700, color: Colors.white, letterSpacing: -0.1);
  static final body = style(15, 400);
  static final bodyStrong = style(15, 600);
  static final caption = style(12, 500, color: AppColors.inkSoft);
  static final fieldLabel = style(13, 600, color: AppColors.inkSoft);
  static final input = style(16, 500);
  static final cardTitle = style(17, 600, letterSpacing: -0.2);
  static final pill = style(13, 600);

  // Header
  static final business = style(15, 600, color: AppColors.green);
  static final greeting = style(34, 700, letterSpacing: -0.95, height: 1.1);
  static final avatarInitials = style(
    15,
    700,
    color: Colors.white,
    letterSpacing: 0.2,
  );
  static final badge = style(10, 700, color: Colors.white, height: 1.0);

  // Sections
  static final sectionTitle = style(22, 700, letterSpacing: -0.4, height: 1.2);
  static final link = style(14, 600, color: AppColors.green);

  // Collections card
  static final cardLabel = style(14, 600, color: AppColors.onCardMuted);
  static final cardPill = style(12, 600, color: AppColors.onCardMuted);
  static final ringValue = style(
    18,
    800,
    color: Colors.white,
    letterSpacing: -0.3,
    tabular: true,
  );
  static final ringCaption = style(
    10,
    600,
    color: Colors.white.withValues(alpha: 0.82),
  );
  static final heroAmount = style(
    28,
    800,
    color: Colors.white,
    letterSpacing: -0.5,
    height: 1.1,
  );
  static final heroCaption = style(
    13,
    500,
    color: AppColors.onCardMuted,
    letterSpacing: -0.1,
  );
  static final tileLabel = style(12, 500, color: AppColors.onCardMuted);
  static final tileValue = style(
    17.5,
    700,
    color: Colors.white,
    letterSpacing: -0.2,
  );
  static final button = style(
    16,
    700,
    color: AppColors.onMint,
    letterSpacing: -0.1,
  );

  // Lists
  static final rowTitle = style(16, 600);
  static final rowSubtitle = style(13, 400, color: AppColors.inkSoft);

  // Portfolio
  static final statCaption = style(13, 500, color: AppColors.inkSoft);
  static final bigNumber = style(28, 700, letterSpacing: -0.8, height: 1.1);
  static final delta = style(12, 700, color: AppColors.greenDeep);
  static final statValue = style(18, 700, letterSpacing: -0.3);

  // Navigation
  static final navLabelStyle = style(11, 600, color: AppColors.navLabel);
}
