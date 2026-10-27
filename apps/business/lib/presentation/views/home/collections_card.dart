// lib/presentation/views/home/collections_card.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../design/motion.dart';
import 'home_format.dart';

const _countDuration = Duration(milliseconds: 1250);
const _countCurve = Curves.easeOutCubic;

/// Dark hero card: this month's rent collection with the progress ring,
/// pending / overdue tiles and the reminders button.
class CollectionsCard extends StatelessWidget {
  const CollectionsCard({
    super.key,
    required this.loading,
    required this.title,
    required this.daysLeft,
    required this.target,
    required this.collected,
    required this.pending,
    required this.overdueCount,
    required this.progress,
    required this.onSendReminders,
  });

  /// True until the first load finishes: numbers show as pulsing placeholders.
  final bool loading;
  final String title;
  final String daysLeft;
  final double target;
  final double collected;
  final double pending;
  final int overdueCount;

  /// 0..1 share of [target] already collected.
  final double progress;
  final VoidCallback onSendReminders;

  @override
  Widget build(BuildContext context) {
    final hasInvoices = target > 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 21, 20, 20),
      decoration: BoxDecoration(
        color: BizColors.card,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: BizColors.card.withValues(alpha: 0.20),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BizText.cardLabel,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 24,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: BizColors.cardPill,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(daysLeft, style: BizText.cardPill),
              ),
            ],
          ),
          const SizedBox(height: 19),
          Row(
            children: [
              _CollectionRing(progress: progress, loading: loading),
              const SizedBox(width: 18),
              Expanded(
                child: _HeroAmount(
                  loading: loading,
                  collected: collected,
                  target: target,
                  hasInvoices: hasInvoices,
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Pending',
                  loading: loading,
                  child: AnimatedNumber(
                    value: pending,
                    format: formatInr,
                    style: BizText.tileValue,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  label: 'Overdue',
                  loading: loading,
                  child: _OverdueValue(count: overdueCount),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Pressable(
            scale: 0.97,
            onTap: onSendReminders,
            child: Container(
              height: 49,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: BizColors.mint,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.translate(
                    offset: const Offset(0, 1),
                    child: Transform.rotate(
                      angle: -math.pi / 4,
                      child: const Icon(
                        Icons.send_outlined,
                        size: 18,
                        color: BizColors.onMint,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Text('Send reminders', style: BizText.button),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tweens a number from its previous value to [value] (starting at 0), so
/// figures count up when data arrives and glide when it changes.
class AnimatedNumber extends StatelessWidget {
  const AnimatedNumber({
    super.key,
    required this.value,
    required this.format,
    required this.style,
    this.duration = _countDuration,
  });

  final double value;
  final String Function(double) format;
  final TextStyle style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: duration,
      curve: _countCurve,
      builder: (context, v, _) => Text(
        format(v),
        maxLines: 1,
        overflow: TextOverflow.fade,
        softWrap: false,
        style: style,
      ),
    );
  }
}

class _HeroAmount extends StatelessWidget {
  const _HeroAmount({
    required this.loading,
    required this.collected,
    required this.target,
    required this.hasInvoices,
  });

  final bool loading;
  final double collected;
  final double target;
  final bool hasInvoices;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 1),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 3),
              child: Skeleton(width: 150, height: 30, radius: 10),
            )
          else
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: AnimatedNumber(
                value: collected,
                format: formatInr,
                style: BizText.heroAmount,
              ),
            ),
          const SizedBox(height: 7),
          if (loading)
            const Skeleton(width: 120, height: 12, radius: 6)
          else
            Text(
              hasInvoices
                  ? 'collected of ${formatInr(target)}'
                  : 'No rent invoices yet this month',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: BizText.heroCaption,
            ),
        ],
      ),
    );
  }
}

class _OverdueValue extends StatelessWidget {
  const _OverdueValue({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count == 0) {
      return Text(
        'All clear',
        style: BizText.tileValue.copyWith(color: BizColors.mint),
      );
    }
    return Text(
      count == 1 ? '1 invoice' : '$count invoices',
      maxLines: 1,
      style: BizText.tileValue.copyWith(color: BizColors.amber),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.loading,
    required this.child,
  });

  final String label;
  final bool loading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: BizColors.cardTile,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: BizText.tileLabel),
          const SizedBox(height: 3),
          if (loading)
            const Skeleton(width: 78, height: 17, radius: 6)
          else
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: child,
            ),
        ],
      ),
    );
  }
}

/// Circular progress with the percentage in the middle. The arc sweeps from
/// 12 o'clock clockwise with a rounded cap, easing out as it lands.
class _CollectionRing extends StatelessWidget {
  const _CollectionRing({required this.progress, required this.loading});

  static const double size = 92;

  final double progress;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: progress),
          duration: _countDuration,
          curve: _countCurve,
          builder: (context, value, _) => CustomPaint(
            painter: _RingPainter(value),
            child: Center(
              child: loading
                  ? const Skeleton(width: 46, height: 20, radius: 8)
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(formatPercent(value), style: BizText.ringValue),
                        const SizedBox(height: 1),
                        Text('of target', style: BizText.ringCaption),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress);

  static const double stroke = 8;

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2 - 3;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = BizColors.cardPill;
    canvas.drawCircle(center, radius, track);

    if (progress <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = BizColors.mint;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}
