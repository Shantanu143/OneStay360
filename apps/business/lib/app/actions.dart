// lib/app/actions.dart
//
// Navigation actions shared by several screens. They take a [BuildContext]
// and push routes; nothing here rebuilds or replaces the shell.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_services/repositories/property_repository.dart';
import 'package:firebase_services/services/image_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/providers/business_state_provider.dart';
import '../presentation/design/components/biz_dialogs.dart';
import '../presentation/design/components/biz_chips.dart';
import '../presentation/design/tokens.dart';
import '../presentation/view_models/add_property_viewmodel.dart';
import '../presentation/views/add_property_screen.dart';
import '../presentation/notifications/notifications_screen.dart';
import '../presentation/profile/profile_screen.dart';
import '../presentation/views/edit_property_screen.dart';
import '../presentation/views/home/home_sheets.dart';
import '../presentation/payments/pending_payments_screen.dart';
import '../presentation/team/team_screen.dart';
import '../presentation/views/view_property_screen.dart';
import '../utils/permissions.dart';
import 'business_shell.dart';
import 'refresh_signals.dart';

void openProfile(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const ProfileScreen()),
  );
}

void openNotifications(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const BusinessNotificationsScreen()),
  );
}

void openTeam(BuildContext context) {
  final role = context.read<BusinessStateProvider>().role;
  if (!BusinessPermissions.fromRole(role).canInviteMembers) {
    showBizToast(context, 'Team management is owner-only.');
    return;
  }
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TeamScreen(showBack: true)));
}

void openPendingPayments(BuildContext context, {String? businessId, String? propertyId}) {
  final id = businessId ?? context.read<BusinessStateProvider>().businessId;
  if (id == null || id.isEmpty) {
    showBizToast(context, 'Business not loaded yet.', tone: BizTone.danger);
    return;
  }
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => PendingPaymentsScreen(businessId: id, propertyId: propertyId),
    ),
  );
}

/// Opens the add-property wizard (owners only).
Future<void> openAddProperty(BuildContext context) async {
  HapticFeedback.lightImpact();
  final state = context.read<BusinessStateProvider>();
  if (!BusinessPermissions.fromRole(state.role).canEditRooms) {
    showBizToast(context, 'Only owners can add properties.');
    return;
  }
  final user = FirebaseAuth.instance.currentUser;
  final businessId = state.businessId;
  if (user == null || businessId == null || businessId.isEmpty) {
    showBizToast(context, 'Please sign in again.', tone: BizTone.danger);
    return;
  }

  // The business phone lives on the user document.
  String phone = '';
  try {
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    phone = (doc.data()?['phoneNumber'] as String?) ?? '';
  } catch (_) {
    // Optional prefill; the form lets the owner type it.
  }
  if (!context.mounted) return;

  final added = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (routeContext) => ChangeNotifierProvider(
        create: (_) => AddPropertyViewModel(
          imageService: routeContext.read<ImageService>(),
          propertyRepository: routeContext.read<PropertyRepository>(),
        ),
        child: AddPropertyScreen(
          businessId: businessId,
          businessName: state.businessName,
          businessPhone: phone,
        ),
      ),
    ),
  );
  if (added == true && context.mounted) {
    try {
      context.read<RefreshSignals>().propertiesChanged();
    } catch (_) {}
    showBizToast(context, 'Property added successfully!', tone: BizTone.success);
  }
}

/// Opens a property on one of its tabs.
Future<void> openProperty(BuildContext context, String propertyId, {int? initialTabIndex}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ViewPropertyScreen(
        propertyId: propertyId,
        initialTabIndex: initialTabIndex,
      ),
    ),
  );
}

/// Opens the edit/finish-setup screen for a property.
Future<void> openEditProperty(BuildContext context, String propertyId) async {
  final businessId = context.read<BusinessStateProvider>().businessId ?? '';
  if (businessId.isEmpty) {
    showBizToast(context, 'Business not loaded yet.', tone: BizTone.danger);
    return;
  }
  final saved = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (routeContext) => ChangeNotifierProvider(
        create: (_) => AddPropertyViewModel(
          imageService: routeContext.read<ImageService>(),
          propertyRepository: routeContext.read<PropertyRepository>(),
        ),
        child: EditPropertyScreen(businessId: businessId, propertyId: propertyId),
      ),
    ),
  );
  if (saved == true && context.mounted) {
    try {
      context.read<RefreshSignals>().propertiesChanged();
    } catch (_) {}
    showBizToast(context, 'Property updated', tone: BizTone.success);
  }
}

/// Opens the newest pending enrollment request on its property's requests tab.
Future<void> openLatestPendingRequest(BuildContext context, String? businessId) async {
  HapticFeedback.lightImpact();
  if (businessId == null || businessId.isEmpty) {
    showBizToast(context, 'Business not loaded yet.', tone: BizTone.danger);
    return;
  }
  try {
    final qs = await FirebaseFirestore.instance
        .collection('enrollmentRequests')
        .where('businessId', isEqualTo: businessId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
    if (!context.mounted) return;
    if (qs.docs.isEmpty) {
      showBizToast(context, 'No pending requests.');
      return;
    }
    final propertyId = qs.docs.first.data()['propertyId']?.toString();
    if (propertyId == null || propertyId.isEmpty) {
      showBizToast(context, 'That request is missing its property.', tone: BizTone.danger);
      return;
    }
    openProperty(context, propertyId, initialTabIndex: ViewPropertyScreen.requestsTabIndex);
  } catch (e) {
    debugPrint('Error opening latest request: $e');
    if (context.mounted) {
      showBizToast(context, "Couldn't open the request. Try again.", tone: BizTone.danger);
    }
  }
}

/// The Home/All-tabs "+" menu.
Future<void> showQuickAdd(BuildContext context, ShellController shell) {
  final perms = BusinessPermissions.fromRole(context.read<BusinessStateProvider>().role);

  return showQuickAddSheet(
    context,
    actions: [
      if (perms.canEditRooms)
        QuickAction(
          icon: Icons.add_business_outlined,
          color: BizColors.green,
          title: 'Add property',
          subtitle: 'List a new PG or hostel',
          onTap: () => openAddProperty(context),
        ),
      QuickAction(
        icon: Icons.person_add_alt_1_outlined,
        color: BizColors.blue,
        title: 'Add tenant',
        subtitle: 'Move someone into a bed',
        onTap: () => shell.goTo(ShellTab.tenants),
      ),
      QuickAction(
        icon: Icons.task_outlined,
        color: BizColors.orange,
        title: 'Pending payments',
        subtitle: 'Confirm rent and deposits',
        onTap: () => openPendingPayments(context),
      ),
      if (perms.canInviteMembers)
        QuickAction(
          icon: Icons.group_add_outlined,
          color: BizColors.card,
          title: 'Invite team member',
          subtitle: 'Add a manager or staff',
          onTap: () => shell.goTo(ShellTab.team),
        ),
    ],
  );
}
