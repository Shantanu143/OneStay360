import 'package:flutter/material.dart';

import '../tokens.dart';

/// The OneStay360 wordmark with the "TENANT" pill that tells this app
/// apart from the business one. [framed] puts the logo on its own light card,
/// for dark backgrounds.
class AppBrandLogo extends StatelessWidget {
  const AppBrandLogo({
    super.key,
    this.height = 56,
    this.framed = false,
    this.alignment = CrossAxisAlignment.start,
  });

  final double height;
  final bool framed;
  final CrossAxisAlignment alignment;

  static const asset = 'assets/brand/logo.png';

  @override
  Widget build(BuildContext context) {
    Widget logo = Image.asset(
      asset,
      height: height,
      fit: BoxFit.contain,
      semanticLabel: 'OneStay360',
      errorBuilder: (_, __, ___) => Text(
        'OneStay360',
        style: AppText.style(height * 0.42, 800, color: AppColors.ink, letterSpacing: -0.6),
      ),
    );
    if (framed) {
      logo = Container(
        padding: EdgeInsets.symmetric(horizontal: height * 0.32, vertical: height * 0.24),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAF7),
          borderRadius: BorderRadius.circular(height * 0.36),
        ),
        child: logo,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignment,
      children: [
        logo,
        SizedBox(height: height * 0.18),
        ExcludeSemantics(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: height * 0.2, vertical: height * 0.07),
            decoration: BoxDecoration(
              color: AppColors.green,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              'TENANT',
              style: AppText.style(
                (height * 0.2).clamp(10, 16).toDouble(),
                800,
                color: Colors.white,
                letterSpacing: 1.6,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
