// lib/presentation/property_detail/tabs/qr_tab.dart
import 'package:flutter/material.dart';
import 'package:models/business/property/property_model.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../design/components/biz_button.dart';
import '../../design/tokens.dart';
import '../property_detail_actions.dart';
import 'detail_common.dart';

/// The link a tenant opens to ask for a bed at [propertyId].
String propertyRequestLink(String propertyId) =>
    'https://onestay.app/request?propertyId=$propertyId';

/// A WhatsApp "share" link that lets the owner pick any chat.
Uri whatsappShareLink(Property property) {
  final text =
      'Looking for a bed at ${property.name}? Request it on OneStay360: '
      '${propertyRequestLink(property.id ?? '')}';
  return Uri.https('wa.me', '/', {'text': text});
}

/// A QR code and link tenants use to send a request for this property.
class QrTab extends StatelessWidget {
  const QrTab({super.key, required this.property, required this.actions});

  final Property property;
  final PropertyDetailActions actions;

  @override
  Widget build(BuildContext context) {
    final link = propertyRequestLink(property.id ?? '');
    return detailSliver([
      Text('Share to get requests', style: BizText.sectionTitle),
      const SizedBox(height: 6),
      Text(
        'Tenants scan this code or open the link to ask for a bed at ${property.name}.',
        style: BizText.rowSubtitle.copyWith(fontSize: 14, height: 1.4),
      ),
      gap(18),
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(BizRadius.hero),
        ),
        child: Column(
          children: [
            QrImageView(
              data: link,
              version: QrVersions.auto,
              size: 220,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: BizColors.ink),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: BizColors.ink,
              ),
            ),
            const SizedBox(height: 14),
            SelectableText(
              link,
              textAlign: TextAlign.center,
              style: BizText.caption,
            ),
          ],
        ),
      ),
      gap(18),
      BizButton(
        label: 'Share on WhatsApp',
        icon: Icons.share_rounded,
        onPressed: () => actions.openUrl(context, whatsappShareLink(property)),
      ),
      gap(10),
      BizButton(
        label: 'Copy link',
        icon: Icons.copy_rounded,
        kind: BizButtonKind.outline,
        onPressed: () => actions.copy(context, link, message: 'Link copied'),
      ),
    ]);
  }
}
