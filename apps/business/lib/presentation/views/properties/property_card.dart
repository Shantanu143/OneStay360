// lib/presentation/views/properties/property_card.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../design/components/biz_button.dart';
import '../../design/components/biz_chips.dart';
import '../../design/motion.dart';
import '../../design/tokens.dart';

typedef PropertyImageBuilder =
    Widget Function(BuildContext context, String url);

/// One property in the list: photo carousel with status and counter chips,
/// name, location, rent range, key numbers and the Edit / primary buttons.
class PropertyCard extends StatefulWidget {
  const PropertyCard({
    super.key,
    required this.name,
    required this.location,
    required this.statusLabel,
    required this.statusTone,
    required this.beds,
    required this.rooms,
    required this.updatedAgo,
    required this.primaryLabel,
    required this.onOpen,
    required this.onPrimary,
    this.onEdit,
    this.rentRange,
    this.occupancyPercent,
    this.imageUrls = const [],
    this.imageBuilder,
  });

  final String name;
  final String location;
  final String statusLabel;
  final BizTone statusTone;
  final String? rentRange;
  final int beds;
  final int rooms;

  /// Shown as a third figure when set (not for drafts).
  final int? occupancyPercent;
  final String updatedAgo;
  final List<String> imageUrls;

  /// Replaces the network image (tests, previews).
  final PropertyImageBuilder? imageBuilder;

  final String primaryLabel;
  final VoidCallback onOpen;
  final VoidCallback onPrimary;

  /// Null hides the Edit button (only owners can edit).
  final VoidCallback? onEdit;

  @override
  State<PropertyCard> createState() => _PropertyCardState();
}

class _PropertyCardState extends State<PropertyCard> {
  int _page = 0;

  Widget _image(BuildContext context, String url) {
    final custom = widget.imageBuilder;
    if (custom != null) return custom(context, url);
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      memCacheWidth: 900,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, __) => const ColoredBox(color: BizColors.photo),
      errorWidget: (_, __, ___) =>
          const _PhotoPlaceholder(label: "Photo unavailable"),
    );
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.imageUrls;

    return Pressable(
      scale: 0.99,
      onTap: widget.onOpen,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(BizRadius.hero),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 188,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (photos.isEmpty)
                    const _PhotoPlaceholder(label: 'No photo yet')
                  else
                    PageView.builder(
                      itemCount: photos.length,
                      onPageChanged: (i) => setState(() => _page = i),
                      itemBuilder: (context, i) => _image(context, photos[i]),
                    ),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: BizStatusPill(
                      widget.statusLabel,
                      tone: widget.statusTone,
                    ),
                  ),
                  if (photos.length > 1)
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: BizColors.ink.withValues(alpha: 0.62),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          '${_page + 1}/${photos.length}',
                          style: BizText.style(
                            13,
                            700,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BizText.style(
                      20,
                      700,
                      letterSpacing: -0.45,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 17,
                        color: BizColors.inkSoft,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          widget.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: BizText.style(
                            14,
                            400,
                            color: BizColors.inkSoft,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (widget.rentRange != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          widget.rentRange!,
                          style: BizText.style(
                            24,
                            700,
                            letterSpacing: -0.6,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '/ month',
                          style: BizText.style(
                            14,
                            400,
                            color: BizColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  _Facts(
                    beds: widget.beds,
                    rooms: widget.rooms,
                    occupancyPercent: widget.occupancyPercent,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Updated ${widget.updatedAgo}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: BizText.style(
                            13,
                            400,
                            color: BizColors.inkSoft,
                          ),
                        ),
                      ),
                      if (widget.onEdit != null) ...[
                        BizButton(
                          label: 'Edit',
                          kind: BizButtonKind.tonal,
                          size: BizButtonSize.compact,
                          expand: false,
                          onPressed: widget.onEdit,
                        ),
                        const SizedBox(width: 8),
                      ],
                      BizButton(
                        label: widget.primaryLabel,
                        size: BizButtonSize.compact,
                        expand: false,
                        onPressed: widget.onPrimary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: BizColors.photo,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.image_outlined,
              size: 40,
              color: BizColors.photoInk,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: BizText.style(14, 500, color: BizColors.photoInk),
            ),
          ],
        ),
      ),
    );
  }
}

class _Facts extends StatelessWidget {
  const _Facts({
    required this.beds,
    required this.rooms,
    this.occupancyPercent,
  });

  final int beds;
  final int rooms;
  final int? occupancyPercent;

  @override
  Widget build(BuildContext context) {
    final cells = <Widget>[
      _Fact(icon: Icons.bed_outlined, value: '$beds', label: 'Beds'),
      _Fact(
        icon: Icons.door_front_door_outlined,
        value: '$rooms',
        label: 'Rooms',
      ),
      if (occupancyPercent != null)
        _Fact(
          icon: Icons.pie_chart_outline_rounded,
          value: '$occupancyPercent%',
          label: 'Occupied',
        ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: BizColors.page,
        borderRadius: BorderRadius.circular(BizRadius.control),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < cells.length; i++) ...[
              if (i > 0)
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Color(0xFFE2E4E8),
                ),
              Expanded(child: cells[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Icon(icon, size: 22, color: BizColors.inkSoft),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value, style: BizText.style(17, 700, height: 1.15)),
                Text(
                  label,
                  style: BizText.style(
                    12,
                    400,
                    color: BizColors.inkSoft,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
