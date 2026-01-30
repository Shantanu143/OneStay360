class BusinessPermissions {
  final bool canInviteMembers;
  final bool canViewBilling;
  final bool canEditRooms;
  final bool canDeleteTenants;

  const BusinessPermissions({
    required this.canInviteMembers,
    required this.canViewBilling,
    required this.canEditRooms,
    required this.canDeleteTenants,
  });

  static BusinessPermissions fromRole(String role) {
    switch (role) {
      case 'owner':
        return const BusinessPermissions(
          canInviteMembers: true,
          canViewBilling: true,
          canEditRooms: true,
          canDeleteTenants: true,
        );
      case 'manager':
        return const BusinessPermissions(
          canInviteMembers: false,
          canViewBilling: false,
          canEditRooms: false,
          canDeleteTenants: false,
        );
      case 'staff':
      default:
        return const BusinessPermissions(
          canInviteMembers: false,
          canViewBilling: false,
          canEditRooms: false,
          canDeleteTenants: false,
        );
    }
  }
}

class PropertyPermissions {
  final bool canViewProperty;
  final bool canCreateRoomsBeds;
  final bool canUpdateRoomsBeds;
  final bool canUpdateBedOccupancy;
  final bool canCreateTenants;
  final bool canUpdateTenants;
  final bool canDeleteTenants;

  const PropertyPermissions({
    required this.canViewProperty,
    required this.canCreateRoomsBeds,
    required this.canUpdateRoomsBeds,
    required this.canUpdateBedOccupancy,
    required this.canCreateTenants,
    required this.canUpdateTenants,
    required this.canDeleteTenants,
  });

  static PropertyPermissions fromRoles({required String businessRole, String? propertyRole}) {
    final effectiveRole = businessRole == 'owner' ? 'owner' : (propertyRole ?? 'staff');
    switch (effectiveRole) {
      case 'owner':
        return const PropertyPermissions(
          canViewProperty: true,
          canCreateRoomsBeds: true,
          canUpdateRoomsBeds: true,
          canUpdateBedOccupancy: true,
          canCreateTenants: true,
          canUpdateTenants: true,
          canDeleteTenants: true,
        );
      case 'manager':
        return const PropertyPermissions(
          canViewProperty: true,
          canCreateRoomsBeds: false,
          canUpdateRoomsBeds: false,
          canUpdateBedOccupancy: true,
          canCreateTenants: true,
          canUpdateTenants: true,
          canDeleteTenants: false,
        );
      case 'staff':
      default:
        return const PropertyPermissions(
          canViewProperty: true,
          canCreateRoomsBeds: false,
          canUpdateRoomsBeds: false,
          canUpdateBedOccupancy: true,
          canCreateTenants: true,
          canUpdateTenants: true,
          canDeleteTenants: false,
        );
    }
  }
}
