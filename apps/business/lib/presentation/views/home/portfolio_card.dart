// lib/presentation/views/home/portfolio_card.dart
import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../design/motion.dart';
import 'collections_card.dart' show AnimatedNumber;
import 'home_format.dart';

/// Occupancy at a glance plus the headline counts.
class PortfolioCard extends StatelessWidget {
  const PortfolioCard({
    super.key,
    required this.loading,
    required this.occupancy,
    required this.occupiedBeds,
    required this.totalBeds,
    required this.properties,
    required this.tenants,
    required this.vacantBeds,
  });

  final bool loading;

  /// 0..1
  final double occupancy;
  final int occupiedBeds;
  final int totalBeds;
  final int properties;
  final int tenants;
  final int vacantBeds;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Occupancy', style: BizText.statCaption),
          const SizedBox(height: 4),
          Row(
            children: [
              if (loading)
                const Skeleton.onLight(width: 86, height: 32, radius: 10)
              else
                AnimatedNumber(
                  value: occupancy,
                  format: formatPercent,
                  style: BizText.bigNumber,
                ),
              const SizedBox(width: 12),
              Expanded(child: _OccupancyBar(fraction: loading ? 0 : occupancy)),
              const SizedBox(width: 12),
              if (!loading) _BedsPill(occupied: occupiedBeds, total: totalBeds),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 1, color: BizColors.hairline),
          const SizedBox(height: 14),
          Row(
            children: [
              _Stat(label: 'Properties', value: loading ? null : '$properties'),
              _Stat(
                label: 'Active tenants',
                value: loading ? null : '$tenants',
              ),
              _Stat(
                label: 'Vacant beds',
                value: loading ? null : '$vacantBeds',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OccupancyBar extends StatelessWidget {
  const _OccupancyBar({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 8,
        child: Stack(
          children: [
            const Positioned.fill(child: ColoredBox(color: BizColors.track)),
            Positioned.fill(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: fraction.clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 1100),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: v,
                    heightFactor: 1,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        color: BizColors.ink,
                        borderRadius: BorderRadius.all(Radius.circular(4)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BedsPill extends StatelessWidget {
  const _BedsPill({required this.occupied, required this.total});

  final int occupied;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: BizColors.greenTint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('$occupied of $total beds', style: BizText.delta),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;

  /// Null shows a placeholder.
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (value == null)
            const Skeleton.onLight(width: 28, height: 20, radius: 6)
          else
            Text(value!, style: BizText.statValue),
          const SizedBox(height: 2),
          Text(label, style: BizText.statCaption.copyWith(fontSize: 12)),
        ],
      ),
    );
  }
}
