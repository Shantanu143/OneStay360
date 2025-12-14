# OneStay360 Import Statement Migration Mapping

## Overview
Complete mapping of all import statement replacements needed to migrate from the monolithic `package:onestay360/` structure to the new modular package architecture.

---

## Migration Categories

### Category 1: Models Package (package:models/)
All data models move to the dedicated models package.

#### Files Affected
- **Tenant app:** `apps/tenant/lib/**/*.dart`
- **Business app:** `apps/business/lib/**/*.dart`
- **Shared packages:** All files importing models

#### Replacement Rules

| Old Import | New Import | Files | Priority |
|---|---|---|---|
| `package:onestay360/data/models/business/property/property_model.dart` | `package:models/business/property/property_model.dart` | Both apps, all files | HIGH |
| `package:onestay360/data/models/business/property/property_room_model.dart` | `package:models/business/property/property_room_model.dart` | Both apps | HIGH |
| `package:onestay360/data/models/business/property/property_amenities_model.dart` | `package:models/business/property/property_amenities_model.dart` | Both apps | HIGH |
| `package:onestay360/data/models/business/property/property_pricing_model.dart` | `package:models/business/property/property_pricing_model.dart` | Both apps | HIGH |
| `package:onestay360/data/models/business/property/property_food_plan_model.dart` | `package:models/business/property/property_food_plan_model.dart` | Both apps | HIGH |
| `package:onestay360/data/models/business/property/property_rules_model.dart` | `package:models/business/property/property_rules_model.dart` | Both apps | HIGH |
| `package:onestay360/data/models/business/property/property_totals_model.dart` | `package:models/business/property/property_totals_model.dart` | Both apps | HIGH |
| `package:onestay360/data/models/business/property/property_rating_model.dart` | `package:models/business/property/property_rating_model.dart` | Both apps | HIGH |
| `package:onestay360/data/models/business/property/property_bed_model.dart` | `package:models/business/property/property_bed_model.dart` | Both apps | HIGH |
| `package:onestay360/data/models/business/property/meal_enum.dart` | `package:models/business/property/meal_enum.dart` | Both apps | HIGH |
| `package:onestay360/data/models/business/tenant_model.dart` | `package:models/business/tenant_model.dart` | Business app | HIGH |
| `package:onestay360/data/models/business/tenant_invitation_model.dart` | `package:models/business/tenant_invitation_model.dart` | Both apps | HIGH |
| `package:onestay360/data/models/tenant/tenant_document_model.dart` | `package:models/tenant/tenant_document_model.dart` | Tenant app | HIGH |
| `package:onestay360/data/models/tenant/tenant_request_model.dart` | `package:models/tenant/tenant_request_model.dart` | Both apps | HIGH |

---

### Category 2: Firebase Services Package (package:firebase_services/)
Data services, repositories, and presentation services move to the firebase_services package.

#### Files Affected
- **Tenant app:** `apps/tenant/lib/**/*.dart`
- **Business app:** `apps/business/lib/**/*.dart`

#### Replacement Rules

##### 2A. Data Repositories
| Old Import | New Import | Files | Priority |
|---|---|---|---|
| `package:onestay360/data/repositories/property_repository.dart` | `package:firebase_services/repositories/property_repository.dart` | Both apps (view models, views) | HIGH |
| `package:onestay360/data/repositories/FirebasePropertyRepository.dart` | `package:firebase_services/repositories/firebase_property_repository.dart` | Both apps | HIGH |

##### 2B. Data Services
| Old Import | New Import | Files | Priority |
|---|---|---|---|
| `package:onestay360/data/services/image_service.dart` | `package:firebase_services/services/image_service.dart` | Both apps | HIGH |
| `package:onestay360/data/services/property_room_service.dart` | `package:firebase_services/services/property_room_service.dart` | Business app | HIGH |
| `package:onestay360/data/services/tenant_invitation_service.dart` | `package:firebase_services/services/tenant_invitation_service.dart` | Both apps | HIGH |
| `package:onestay360/data/services/tenant_search_service.dart` | `package:firebase_services/services/tenant_search_service.dart` | Business app | HIGH |
| `package:onestay360/data/services/id_generation_service.dart` | `package:firebase_services/services/id_generation_service.dart` | Both apps | MEDIUM |
| `package:onestay360/data/services/property_service.dart` | `package:firebase_services/services/property_service.dart` | Both apps | MEDIUM |

##### 2C. Presentation Services
| Old Import | New Import | Files | Priority |
|---|---|---|---|
| `package:onestay360/presentation/services/firestore_service.dart` | `package:firebase_services/services/firestore_service.dart` | Both apps | HIGH |
| `package:onestay360/presentation/services/auth_service.dart` | `package:firebase_services/services/auth_service.dart` | Business app | HIGH |
| `package:onestay360/presentation/services/image_service.dart` | `package:firebase_services/services/image_service.dart` | Both apps | HIGH |
| `package:onestay360/presentation/services/approval_function_client.dart` | `package:firebase_services/services/approval_function_client.dart` | Business app | MEDIUM |

---

### Category 3: Tenant App - Local Relative Imports
View models and views within the tenant app that reference other tenant-specific resources should use relative imports.

#### Files Affected
- **Tenant app only:** `apps/tenant/lib/presentation/**/*.dart`

#### Replacement Rules

##### 3A. Tenant App View Models (Relative Imports)
| Old Import | New Import | Files | Priority |
|---|---|---|---|
| `package:onestay360/presentation/view_models/tenant/profile_viewmodel.dart` | `package:../view_models/profile_viewmodel.dart` | `apps/tenant/lib/presentation/views/tenant_profile_screen.dart` | HIGH |
| `package:onestay360/presentation/view_models/tenant/pg_detail_viewmodel.dart` | `package:../view_models/pg_detail_viewmodel.dart` | `apps/tenant/lib/presentation/views/pg_detail_screen.dart` | HIGH |
| `package:onestay360/presentation/view_models/tenant/explore_viewmodel.dart` | `package:../view_models/explore_viewmodel.dart` | `apps/tenant/lib/presentation/views/explore_screen.dart` | HIGH |

##### 3B. Tenant App Views (Relative Imports)
| Old Import | New Import | Location | Priority |
|---|---|---|---|
| `package:onestay360/presentation/views/tenant/tenant_profile_screen.dart` | `./tenant_profile_screen.dart` or `tenant_profile_screen.dart` | Via tenant_scaffold or other views | HIGH |
| `package:onestay360/presentation/views/tenant/explore_screen.dart` | `./explore_screen.dart` or `explore_screen.dart` | Via tenant_scaffold | HIGH |
| `package:onestay360/presentation/views/tenant/home_screen.dart` | `./home_screen.dart` or `home_screen.dart` | Via tenant_scaffold | HIGH |
| `package:onestay360/presentation/views/tenant/my_pg_screen.dart` | `./my_pg_screen.dart` or `my_pg_screen.dart` | Via tenant_scaffold | HIGH |
| `package:onestay360/presentation/views/tenant/notifications_screen.dart` | `./notifications_screen.dart` or `notifications_screen.dart` | Via tenant_scaffold | HIGH |
| `package:onestay360/presentation/views/tenant/widgets/tenant_scaffold.dart` | `./widgets/tenant_scaffold.dart` | From views in same directory | HIGH |
| `package:onestay360/presentation/views/tenant/tenant_invitation_approval_screen.dart` | `./tenant_invitation_approval_screen.dart` | Via tenant_scaffold or notifications | HIGH |
| `package:onestay360/presentation/views/tenant/pg_detail_screen.dart` | `pg_detail_screen.dart` | From explore or my_pg screens | HIGH |

##### 3C. Tenant App Data Providers (Relative Imports)
| Old Import | New Import | Files | Priority |
|---|---|---|---|
| `package:onestay360/data/providers/tenant_state_provider.dart` | `../../data/providers/tenant_state_provider.dart` | `apps/tenant/lib/presentation/views/**/*.dart` | MEDIUM |

---

### Category 4: Business App - Local Relative Imports
View models and views within the business app that reference other business-specific resources should use relative imports.

#### Files Affected
- **Business app only:** `apps/business/lib/presentation/**/*.dart`

#### Replacement Rules

##### 4A. Business App View Models (Relative Imports)
| Old Import | New Import | Files | Priority |
|---|---|---|---|
| `package:onestay360/presentation/view_models/business/view_property_viewmodel.dart` | `../view_models/view_property_viewmodel.dart` | `apps/business/lib/presentation/views/view_property_screen.dart`, etc. | HIGH |
| `package:onestay360/presentation/view_models/business/business_properties_viewmodel.dart` | `../view_models/business_properties_viewmodel.dart` | `apps/business/lib/presentation/views/business_properties_screen.dart` | HIGH |
| `package:onestay360/presentation/view_models/business/add_tenant_viewmodel.dart` | `../view_models/add_tenant_viewmodel.dart` | `apps/business/lib/presentation/views/add_tenant_screen.dart` | HIGH |
| `package:onestay360/presentation/view_models/business/add_tenant_invitation_viewmodel.dart` | `../view_models/add_tenant_invitation_viewmodel.dart` | `apps/business/lib/presentation/views/add_tenant_screen.dart` | HIGH |
| `package:onestay360/presentation/view_models/business/add_property_viewmodel.dart` | `../view_models/add_property_viewmodel.dart` | `apps/business/lib/presentation/views/**/*.dart` | HIGH |

##### 4B. Business App Views (Relative Imports)
| Old Import | New Import | Location | Priority |
|---|---|---|---|
| `package:onestay360/presentation/views/business/business_profile_screen.dart` | `./business_profile_screen.dart` | Via business_scaffold | HIGH |
| `package:onestay360/presentation/views/business/business_properties_screen.dart` | `./business_properties_screen.dart` | Via business_scaffold, home_screen | HIGH |
| `package:onestay360/presentation/views/business/home_screen.dart` | `./home_screen.dart` | Via business_scaffold | HIGH |
| `package:onestay360/presentation/views/business/add_tenant_screen.dart` | `./add_tenant_screen.dart` | Via business_scaffold | HIGH |
| `package:onestay360/presentation/views/business/view_property_screen.dart` | `./view_property_screen.dart` | Via business_scaffold, home_screen | HIGH |
| `package:onestay360/presentation/views/business/add_property_screen.dart` | `./add_property_screen.dart` | Via business_scaffold, home_screen | HIGH |
| `package:onestay360/presentation/views/business/widgets/business_scaffold.dart` | `./widgets/business_scaffold.dart` | From views in same directory | HIGH |
| `package:onestay360/presentation/views/business/qr_scanner_screen.dart` | `./qr_scanner_screen.dart` | From add_tenant_screen | HIGH |
| `package:onestay360/presentation/views/business/tenant_search_screen.dart` | `./tenant_search_screen.dart` | From add_tenant_screen | HIGH |
| `package:onestay360/presentation/views/business/property_assignment_screen.dart` | `./property_assignment_screen.dart` | From add_tenant_screen | HIGH |
| `package:onestay360/presentation/views/business/request_detail_screen.dart` | `./request_detail_screen.dart` | From view_property_screen | HIGH |
| `package:onestay360/presentation/views/business/edit_property_screen.dart` | `./edit_property_screen.dart` | From business_properties_screen | HIGH |

##### 4C. Business App Data Providers (Relative Imports)
| Old Import | New Import | Files | Priority |
|---|---|---|---|
| `package:onestay360/data/providers/business_state_provider.dart` | `../../data/providers/business_state_provider.dart` | `apps/business/lib/presentation/views/**/*.dart` | MEDIUM |

---

## Summary Statistics

### Import Replacements by Category

| Category | Count | Scope |
|----------|-------|-------|
| Models (package:models/) | 14 | Both apps |
| Repositories (package:firebase_services/repositories/) | 2 | Both apps |
| Data Services (package:firebase_services/services/) | 6 | Both apps |
| Presentation Services (package:firebase_services/services/) | 4 | Both apps |
| Tenant App View Models (relative) | 3 | Tenant only |
| Tenant App Views (relative) | 8 | Tenant only |
| Tenant App Data Providers (relative) | 1 | Tenant only |
| Business App View Models (relative) | 5 | Business only |
| Business App Views (relative) | 11 | Business only |
| Business App Data Providers (relative) | 1 | Business only |

**Total Unique Import Patterns:** ~55

### Files to Update

#### Tenant App Files
- `apps/tenant/lib/presentation/view_models/profile_viewmodel.dart` ✓
- `apps/tenant/lib/presentation/view_models/pg_detail_viewmodel.dart` ✓
- `apps/tenant/lib/presentation/view_models/explore_viewmodel.dart` ✓
- `apps/tenant/lib/presentation/views/tenant_profile_screen.dart` ✓
- `apps/tenant/lib/presentation/views/pg_detail_screen.dart` ✓
- `apps/tenant/lib/presentation/views/explore_screen.dart` ✓
- `apps/tenant/lib/presentation/views/home_screen.dart` ✓
- `apps/tenant/lib/presentation/views/notifications_screen.dart` ✓
- `apps/tenant/lib/presentation/views/my_pg_screen.dart` ✓
- `apps/tenant/lib/presentation/views/tenant_invitation_approval_screen.dart` ✓
- `apps/tenant/lib/presentation/views/enroll_request_screen.dart` ✓
- `apps/tenant/lib/presentation/views/widgets/tenant_scaffold.dart` ✓

#### Business App Files
- `apps/business/lib/presentation/view_models/view_property_viewmodel.dart` ✓
- `apps/business/lib/presentation/view_models/business_properties_viewmodel.dart` ✓
- `apps/business/lib/presentation/view_models/add_tenant_viewmodel.dart` ✓
- `apps/business/lib/presentation/view_models/add_tenant_invitation_viewmodel.dart` ✓
- `apps/business/lib/presentation/view_models/add_property_viewmodel.dart` ✓
- `apps/business/lib/presentation/views/view_property_screen.dart` ✓
- `apps/business/lib/presentation/views/tenant_search_screen.dart` ✓
- `apps/business/lib/presentation/views/request_detail_screen.dart` ✓
- `apps/business/lib/presentation/views/qr_scanner_screen.dart` ✓
- `apps/business/lib/presentation/views/property_assignment_screen.dart` ✓
- `apps/business/lib/presentation/views/home_screen.dart` ✓
- `apps/business/lib/presentation/views/edit_property_screen.dart` ✓
- `apps/business/lib/presentation/views/business_properties_screen.dart` ✓
- `apps/business/lib/presentation/views/business_profile_screen.dart` ✓
- `apps/business/lib/presentation/views/add_tenant_screen.dart` ✓
- `apps/business/lib/presentation/views/add_property_screen.dart` ✓
- `apps/business/lib/presentation/views/widgets/business_scaffold.dart` ✓

**Total Files to Update:** 29

---

## Implementation Notes

### Priority Order
1. **HIGH Priority:** Models and Firebase Services packages (affects both apps)
2. **MEDIUM Priority:** Relative imports within each app
3. **LOW Priority:** Cleanup and verification

### Testing Checklist
- [ ] No unresolved imports in tenant app
- [ ] No unresolved imports in business app
- [ ] No duplicate or conflicting imports
- [ ] All relative imports use correct path depth
- [ ] Aliased imports (e.g., `as biz`) preserved
- [ ] Build succeeds: `flutter pub get` in both apps
- [ ] No analyzer errors reported

### Special Cases
1. **Aliased Imports:** Preserve aliases like `as biz` in:
   - `apps/business/lib/presentation/view_models/add_tenant_viewmodel.dart` (line 4)
   - `apps/business/lib/presentation/views/business_properties_screen.dart` (import aliases)

2. **Relative Imports Already Used:** Some files already use relative imports correctly:
   - `apps/business/lib/presentation/views/business_profile_screen.dart` (line 4)
   - `apps/business/lib/presentation/views/add_property_screen.dart` (uses relative)
   - Files in `presentation/views/` that already import widgets correctly

3. **Widget Imports:** Ensure relative paths for widgets are correct depth from location

---

## Verification Command

Run these commands after completing migrations:

```bash
# Check for remaining old imports
cd apps/tenant
grep -r "package:onestay360" lib/
cd ../business
grep -r "package:onestay360" lib/

# Run analysis
flutter analyze
```

Expected output: **No matches** (all imports replaced)

---

## Related Documentation
- See `IMPLEMENTATION_GUIDE.md` for step-by-step execution
- See `pubspec.yaml` files for package dependencies
- See package README files in `packages/` directory
