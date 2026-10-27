// lib/presentation/views/view_property_screen.dart
import 'package:flutter/widgets.dart';

import '../property_detail/property_detail_screen.dart';
import '../property_detail/property_detail_viewmodel.dart';

/// Entry point for a property's detail page. Callers and deep links reach it
/// by this name; the page itself lives in `property_detail/`.
class ViewPropertyScreen extends StatelessWidget {
  const ViewPropertyScreen({
    super.key,
    required this.propertyId,
    this.initialTabIndex,
  });

  final String propertyId;
  final int? initialTabIndex;

  /// Tab indexes deep links open (notifications, push).
  static final int requestsTabIndex = PropertyDetailTab.requests.index;
  static final int billingTabIndex = PropertyDetailTab.payments.index;

  @override
  Widget build(BuildContext context) =>
      PropertyDetailScreen(propertyId: propertyId, initialTabIndex: initialTabIndex);
}
