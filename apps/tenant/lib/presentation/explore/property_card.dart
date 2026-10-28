// lib/presentation/explore/property_card.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:models/business/property/property_model.dart';

import '../design/components/app_card.dart';
import '../design/motion.dart';
import '../design/tokens.dart';
import 'property_facts.dart';

/// A PG in a list: photo (swipeable), name, area, price, who it is for.
class PropertyCard extends StatelessWidget {
  const PropertyCard({
    super.key,
    required this.property,
    required this.saved,
    required this.onTap,
    required this.onToggleSaved,
  });

  final Property property;
  final bool saved;
  final VoidCallback onTap;
  final VoidCallback onToggleSaved;

  @override
  Widget build(BuildContext context) {
    final p = property;
    final beds = p.totals.availableBeds;
    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              PhotoCarousel(images: p.images ?? const [], height: 184, heroTag: 'photo-${p.id}'),
              Positioned(
                top: 12,
                right: 12,
                child: SaveButton(saved: saved, onTap: onToggleSaved),
              ),
              if (p.featured)
                Positioned(
                  top: 12,
                  left: 12,
                  child: _Badge(label: 'Featured', color: AppColors.amber, ink: AppColors.onMint),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.cardTitle),
                    ),
                    if (p.rating.count > 0) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.star_rounded, size: 18, color: AppColors.orange),
                      const SizedBox(width: 2),
                      Text(p.rating.average.toStringAsFixed(1), style: AppText.bodyStrong),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  [p.landmarks, p.address].firstWhere((s) => s.trim().isNotEmpty, orElse: () => p.city),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.rowSubtitle,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: priceLabelOf(p), style: AppText.style(17, 700, letterSpacing: -0.3)),
                            if (minPriceOf(p) > 0) TextSpan(text: ' /month', style: AppText.rowSubtitle),
                          ],
                        ),
                      ),
                    ),
                    _Tag(genderLabelOf(p)),
                    if (beds > 0) ...[
                      const SizedBox(width: 6),
                      _Tag('$beds ${beds == 1 ? 'bed' : 'beds'} free', highlight: true),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, {this.highlight = false});

  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: highlight ? AppColors.greenTint : AppColors.page,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label, style: AppText.style(12, 600, color: highlight ? AppColors.greenDeep : AppColors.inkSoft)),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color, required this.ink});

  final String label;
  final Color color;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: AppText.style(12, 700, color: ink)),
    );
  }
}

/// The heart on a photo. Pops when toggled.
class SaveButton extends StatelessWidget {
  const SaveButton({super.key, required this.saved, required this.onTap});

  final bool saved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.85,
      onTap: onTap,
      semanticLabel: saved ? 'Remove from saved' : 'Save',
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.94), shape: BoxShape.circle),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          transitionBuilder: (child, a) => ScaleTransition(scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack), child: child),
          child: Icon(
            saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            key: ValueKey(saved),
            size: 21,
            color: saved ? AppColors.badge : AppColors.ink,
          ),
        ),
      ),
    );
  }
}

/// Swipeable photos with page dots; a placeholder when there are none.
class PhotoCarousel extends StatefulWidget {
  const PhotoCarousel({super.key, required this.images, required this.height, this.heroTag});

  final List<String> images;
  final double height;
  final String? heroTag;

  @override
  State<PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<PhotoCarousel> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    if (images.isEmpty) {
      return Container(
        height: widget.height,
        color: AppColors.photo,
        alignment: Alignment.center,
        child: const Icon(Icons.apartment_rounded, size: 52, color: AppColors.photoInk),
      );
    }
    Widget photo(String url) => CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          fadeInDuration: const Duration(milliseconds: 220),
          placeholder: (_, _) => Container(color: AppColors.photo),
          errorWidget: (_, _, _) => Container(
            color: AppColors.photo,
            alignment: Alignment.center,
            child: const Icon(Icons.image_not_supported_outlined, color: AppColors.photoInk),
          ),
        );
    return SizedBox(
      height: widget.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            itemCount: images.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => i == 0 && widget.heroTag != null
                ? Hero(tag: widget.heroTag!, child: photo(images[i]))
                : photo(images[i]),
          ),
          if (images.length > 1)
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < images.length && i < 8; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _page ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: i == _page ? 1 : 0.6),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
