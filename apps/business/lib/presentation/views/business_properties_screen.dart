import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../view_models/business_properties_viewmodel.dart';
import './add_property_screen.dart';
import './view_property_screen.dart' as view_screen;
import './edit_property_screen.dart' as edit_screen;
import 'package:firebase_services/repositories/property_repository.dart';
import 'package:firebase_services/services/auth_service.dart';
import 'package:models/business/property/property_model.dart';
import '../view_models/add_property_viewmodel.dart';
import 'package:firebase_services/services/image_service.dart';
import 'widgets/business_scaffold.dart';
import '../../data/providers/business_state_provider.dart';

class BusinessPropertiesScreen extends StatelessWidget {
  const BusinessPropertiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final propertyRepository = context.read<PropertyRepository>();
    final businessState = context.watch<BusinessStateProvider>();

    return ChangeNotifierProvider(
      create: (_) => BusinessPropertiesViewModel(
        propertyRepository: propertyRepository,
      ),
      child: Consumer<BusinessPropertiesViewModel>(
        builder: (context, viewModel, _) {
          // Load properties with businessId guard
          Future.microtask(() {
            if (businessState.businessId != null && businessState.businessId!.isNotEmpty) {
              viewModel.loadProperties(businessState.businessId);
            }
          });

          return BusinessScaffold(
            currentTab: BusinessTab.properties,
            //titleText: 'Properties',
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () {
                _navigateToAddProperty(context);
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Property'),
            ),
            body: BusinessPropertiesView(
              onAddProperty: () {
                _navigateToAddProperty(context);
              },
              onPropertySelected: (Property property) {
                if (property.id != null) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => view_screen.ViewPropertyScreen(propertyId: property.id!),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cannot view property: ID is missing')),
                  );
                }
              },
            ),
          );
        },
      ),
    );
  }

  void _navigateToAddProperty(BuildContext context) {
    HapticFeedback.lightImpact();

    // Get business info before navigating
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .then((userDoc) {
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          final businessId = userData['businessId'] as String? ?? user.uid;
          final businessName = userData['businessName'] as String? ?? 'My Business';
          final businessPhone = userData['phoneNumber'] as String? ?? '';

          debugPrint('🚀 Navigating to Add Property with:');
          debugPrint('  Business ID: $businessId');
          debugPrint('  Business Name: $businessName');
          debugPrint('  Business Phone: $businessPhone');

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChangeNotifierProvider(
                create: (_) => AddPropertyViewModel(
                  imageService: Provider.of<ImageService>(context, listen: false),
                  propertyRepository: Provider.of<PropertyRepository>(context, listen: false),
                ),
                child: AddPropertyScreen(
                  businessId: businessId,
                  businessName: businessName,
                  businessPhone: businessPhone,
                ),
              ),
            ),
          );
        } else {
          // If user document doesn't exist, use default values
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChangeNotifierProvider(
                create: (_) => AddPropertyViewModel(
                  imageService: Provider.of<ImageService>(context, listen: false),
                  propertyRepository: Provider.of<PropertyRepository>(context, listen: false),
                ),
                child: AddPropertyScreen(
                  businessId: user.uid,
                  businessName: 'My Business',
                  businessPhone: '',
                ),
              ),
            ),
          );
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in again')),
      );
    }
  }
}

class BusinessPropertiesView extends StatefulWidget {
  final VoidCallback onAddProperty;
  final Function(Property) onPropertySelected;

  const BusinessPropertiesView({
    super.key,
    required this.onAddProperty,
    required this.onPropertySelected,
  });

  @override
  State<BusinessPropertiesView> createState() => _BusinessPropertiesViewState();
}

class _BusinessPropertiesViewState extends State<BusinessPropertiesView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<BusinessPropertiesViewModel>();
    final authService = context.read<AuthService>();
    final businessState = context.read<BusinessStateProvider>();
    final filteredProperties = viewModel.filteredProperties;

    return RefreshIndicator(
      onRefresh: () => viewModel.refreshProperties(businessState.businessId),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchAndControls(viewModel),
            const SizedBox(height: 16),

            if (viewModel.hasError)
              _ErrorState(
                error: viewModel.error ?? 'Unknown error',
                onRetry: () => viewModel.refreshProperties(businessState.businessId),
              )
            else if (viewModel.isLoading && filteredProperties.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (filteredProperties.isEmpty)
                _EmptyState(onAdd: widget.onAddProperty)
              else
                ListView.separated(
                  itemCount: filteredProperties.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (_, i) => _buildPropertyCard(filteredProperties[i], viewModel),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndControls(BusinessPropertiesViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search
        TextField(
          controller: _searchController,
          onChanged: viewModel.updateSearchQuery,
          decoration: InputDecoration(
            hintText: 'Search by name, address, or city',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                _searchController.clear();
                viewModel.updateSearchQuery('');
              },
            )
                : null,
            filled: true,
            fillColor: Colors.grey.shade100,
            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Filters in single row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                label: 'All',
                selected: viewModel.statusFilter == PropertyStatusFilter.all,
                onSelected: () => viewModel.updateStatusFilter(PropertyStatusFilter.all),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Active',
                selected: viewModel.statusFilter == PropertyStatusFilter.active,
                color: Colors.green.shade600,
                onSelected: () => viewModel.updateStatusFilter(PropertyStatusFilter.active),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Vacant',
                selected: viewModel.statusFilter == PropertyStatusFilter.vacant,
                color: Colors.orange.shade700,
                onSelected: () => viewModel.updateStatusFilter(PropertyStatusFilter.vacant),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Maintenance',
                selected: viewModel.statusFilter == PropertyStatusFilter.maintenance,
                color: Colors.red.shade600,
                onSelected: () => viewModel.updateStatusFilter(PropertyStatusFilter.maintenance),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Sort dropdown and total count row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Total Properties: ${viewModel.filteredProperties.length}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
            DropdownButtonHideUnderline(
              child: DropdownButton<PropertySortOption>(
                value: viewModel.sortOption,
                items: const [
                  DropdownMenuItem(
                    value: PropertySortOption.updated,
                    child: Text('Updated'),
                  ),
                  DropdownMenuItem(
                    value: PropertySortOption.newest,
                    child: Text('Newest'),
                  ),
                  DropdownMenuItem(
                    value: PropertySortOption.occupancy,
                    child: Text('Occupancy'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) {
                    viewModel.updateSortOption(v);
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPropertyCard(Property property, BusinessPropertiesViewModel viewModel) {
    final statusColor = viewModel.getStatusColor(property);
    final statusText = viewModel.getStatusText(property);
    final rentRange = viewModel.getRentRange(property);
    final occupancyRate = viewModel.getOccupancyRate(property);

    // Helper methods for navigation with null checks
    void navigateToViewProperty() {
      if (property.id != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => view_screen.ViewPropertyScreen(propertyId: property.id!),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot view property: ID is missing')),
        );
      }
    }

    void navigateToEditProperty() {
      if (property.id != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => edit_screen.EditPropertyScreen(propertyId: property.id!),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot edit property: ID is missing')),
        );
      }
    }

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        navigateToViewProperty();
      },
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPropertyImageSection(property),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row: Name and status
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          property.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Address / city
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${property.address}, ${property.city}',
                          style: TextStyle(color: Colors.grey.shade600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Stats area
                  Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _StatChip(
                                icon: Icons.bed_outlined,
                                label: '${property.totals.beds} beds',
                              ),
                              const SizedBox(width: 8),
                              _StatChip(
                                icon: Icons.meeting_room_outlined,
                                label: '${property.totals.rooms} rooms',
                              ),
                              const SizedBox(width: 8),
                              _StatChip(
                                icon: Icons.people_outline,
                                label: '${(occupancyRate * 100).toStringAsFixed(0)}% occ.',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        rentRange,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                        textAlign: TextAlign.right,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Actions
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runSpacing: 8,
                    children: [
                      Text(
                        'Updated ${_humanizeTime(property.updatedAt)}',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: navigateToViewProperty,
                            child: const Text('View'),
                          ),
                          const SizedBox(width: 4),
                          OutlinedButton(
                            onPressed: navigateToEditProperty,
                            child: const Text('Edit'),
                          ),
                        ],
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

  Widget _buildPropertyImageSection(Property property) {
    final hasImages = property.images != null && property.images!.isNotEmpty;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Main image or placeholder
          if (hasImages)
            Image.network(
              property.images!.first,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
              errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
            )
          else
            _buildImagePlaceholder(),

          // Image count badge if multiple images
          if (hasImages && property.images!.length > 1)
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '+${property.images!.length - 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: Colors.grey.shade100,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.home_work_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              'No Images',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _humanizeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// Reusable components
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final Color? color;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final clr = color ?? Theme.of(context).colorScheme.primary;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: clr.withOpacity(0.15),
      labelStyle: TextStyle(color: selected ? clr : Colors.grey.shade700),
      onSelected: (_) => onSelected(),
      side: BorderSide(color: selected ? clr.withOpacity(0.5) : Colors.grey.shade300),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade700),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(Icons.home_work_outlined, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'No properties yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Add your first property to start managing listings, rooms, and tenants.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add Property'),
            ),
          ],
        )
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, size: 56, color: Colors.red.shade400),
          const SizedBox(height: 12),
          const Text(
            'Failed to load properties',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            error.length > 100 ? '${error.substring(0, 100)}...' : error,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () {
                  // Show full error in dialog
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Error Details'),
                      content: SelectableText(error),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Details'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


