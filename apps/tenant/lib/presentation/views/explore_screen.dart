import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../view_models/explore_viewmodel.dart';
import 'package:models/business/property/property_model.dart';
import 'widgets/tenant_scaffold.dart';
import 'pg_detail_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Trigger initial load once after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = Provider.of<ExploreViewModel>(context, listen: false);
      if (viewModel.properties.isEmpty && !viewModel.isLoading) {
        viewModel.loadProperties(refresh: true);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final viewModel = Provider.of<ExploreViewModel>(context, listen: false);
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      viewModel.loadMoreProperties();
    }
  }

  void _navigateToPGDetail(Property property, ExploreViewModel viewModel) {
    HapticFeedback.lightImpact();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PGDetailScreen(
          propertyId: property.id!,
        ),
      ),
    );
  }

  // FIXED: Change return type to FloatingActionButton
  FloatingActionButton _buildFloatingActionButton(BuildContext context) {
    return FloatingActionButton(
      onPressed: () {
        final viewModel = Provider.of<ExploreViewModel>(context, listen: false);
        viewModel.refreshData();
      },
      backgroundColor: const Color(0xFF06B6D4),
      child: const Icon(Icons.refresh_rounded, color: Colors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TenantScaffold(
      currentTab: TenantTab.explore,
      body: SafeArea(
        child: Consumer<ExploreViewModel>(
          builder: (context, viewModel, child) {
            // Initial load moved to initState to avoid repeated triggers on rebuild

            return Column(
              children: [
                // Header with City Dropdown
                _buildHeader(viewModel),

                // Filter Chips
                _buildFilterChips(viewModel),

                // Results Count and Sort
                _buildResultsHeader(viewModel),

                // Property List
                Expanded(
                  child: _buildPropertyList(viewModel),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(context), // FIXED: Now returns FloatingActionButton
    );
  }


  Widget _buildHeader(ExploreViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.05 * 255).round()),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Explore PGs',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF164e63),
                  ),
                ),
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 120, maxWidth: 160),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Color(0xFF06B6D4).withAlpha((0.1 * 255).round()),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: Color(0xFF06B6D4).withAlpha((0.4 * 255).round()),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      color: Color(0xFF06B6D4),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: viewModel.selectedCity,
                          isDense: true,
                          icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Color(0xFF06B6D4),
                            size: 18,
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF06B6D4),
                          ),
                          items: viewModel.availableCities.map((city) => DropdownMenuItem(
                            value: city,
                            child: Text(
                              city,
                              overflow: TextOverflow.ellipsis,
                            ),
                          )).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              HapticFeedback.selectionClick();
                              viewModel.updateCity(value);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Search Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => viewModel.updateSearchQuery(value),
              decoration: InputDecoration(
                hintText: 'Search by area, PG name, or amenities...',
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF06B6D4),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () {
                    _searchController.clear();
                    viewModel.clearSearch();
                  },
                )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(ExploreViewModel viewModel) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: viewModel.availableFilters.length,
        itemBuilder: (context, index) {
          final filter = viewModel.availableFilters[index];
          final isSelected = viewModel.selectedFilter == filter;

          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(viewModel.getFilterDisplayName(filter)),
              selected: isSelected,
              onSelected: (selected) {
                HapticFeedback.selectionClick();
                viewModel.updateFilter(filter);
              },
              backgroundColor: Colors.white,
              selectedColor: const Color(0xFF06B6D4).withOpacity(0.2),
              checkmarkColor: const Color(0xFF06B6D4),
              labelStyle: TextStyle(
                color: isSelected ? const Color(0xFF06B6D4) : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              side: BorderSide(
                color: isSelected ? const Color(0xFF06B6D4) : Colors.grey[300]!,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildResultsHeader(ExploreViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            '${viewModel.propertyCount} PGs found in ${viewModel.selectedCity}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          if (viewModel.propertyCount > 0)
            PopupMenuButton<ExploreSortOption>(
              onSelected: (option) {
                HapticFeedback.selectionClick();
                viewModel.updateSortOption(option);
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.sort_rounded,
                    size: 18,
                    color: Color(0xFF06B6D4),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Sort',
                    style: TextStyle(
                      color: Color(0xFF06B6D4),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: ExploreSortOption.relevance,
                  child: Text('Relevance'),
                ),
                const PopupMenuItem(
                  value: ExploreSortOption.priceLowToHigh,
                  child: Text('Price: Low to High'),
                ),
                const PopupMenuItem(
                  value: ExploreSortOption.priceHighToLow,
                  child: Text('Price: High to Low'),
                ),
                const PopupMenuItem(
                  value: ExploreSortOption.rating,
                  child: Text('Rating'),
                ),
                const PopupMenuItem(
                  value: ExploreSortOption.newest,
                  child: Text('Newest'),
                ),
                const PopupMenuItem(
                  value: ExploreSortOption.occupancy,
                  child: Text('Availability'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPropertyList(ExploreViewModel viewModel) {
    if (viewModel.isLoading && viewModel.properties.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Color(0xFF06B6D4),
            ),
            SizedBox(height: 16),
            Text(
              'Loading PGs...',
              style: TextStyle(
                color: Color(0xFF06B6D4),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (viewModel.hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 80,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                viewModel.errorMessage,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => viewModel.refreshData(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF06B6D4),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (viewModel.properties.isEmpty) {
      return _buildEmptyState(viewModel);
    }

    return RefreshIndicator(
      onRefresh: () => viewModel.refreshData(),
      color: const Color(0xFF06B6D4),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: viewModel.properties.length + (viewModel.hasMoreData ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == viewModel.properties.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF06B6D4),
                ),
              ),
            );
          }

          final property = viewModel.properties[index];
          return _buildPgCard(property, viewModel);
        },
      ),
    );
  }

  Widget _buildEmptyState(ExploreViewModel viewModel) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No PGs found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters or search terms',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => viewModel.resetFilters(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reset Filters'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF06B6D4),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => viewModel.refreshData(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reload Data'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPgCard(Property property, ExploreViewModel viewModel) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Section
          Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF06B6D4).withOpacity(0.8),
                  const Color(0xFF0891B2).withOpacity(0.9),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                // Placeholder Image or Real Image
                if (property.images != null && property.images!.isNotEmpty)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Image.network(
                      property.images!.first,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(property),
                    ),
                  )
                else
                  _buildPlaceholderImage(property),

                // Overlay gradient
                Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.3),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),

                // Top badges
                Positioned(
                  top: 12,
                  left: 12,
                  child: Row(
                    children: [
                      if (property.featured)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.star_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Featured',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Verified',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star_rounded,
                          color: Colors.amber[600],
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          property.rating.average.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Gender badge
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: viewModel.getGenderColor(property),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: viewModel.getGenderBorderColor(property),
                      ),
                    ),
                    child: Text(
                      viewModel.getGenderText(property),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: viewModel.getGenderTextColor(property),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name and Price
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        property.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF164e63),
                        ),
                      ),
                    ),
                    Text(
                      viewModel.getPriceRange(property),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF06B6D4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Location
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      color: Color(0xFF06B6D4),
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${property.address}, ${property.city}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Amenities
                _buildAmenityChips(property),
                const SizedBox(height: 16),

                // Stats and Action
                Row(
                  children: [
                    // Stats
                    Expanded(
                      child: Row(
                        children: [
                          _buildStatItem(
                            Icons.meeting_room_rounded,
                            property.totals.rooms.toString(),
                            'Rooms',
                          ),
                          const SizedBox(width: 16),
                          _buildStatItem(
                            Icons.people_rounded,
                            '${property.totals.availableBeds}/${property.totals.beds}',
                            'Available',
                          ),
                        ],
                      ),
                    ),

                    // View Details Button
                    ElevatedButton(
                      onPressed: () => _navigateToPGDetail(property, viewModel),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF06B6D4),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'View Details',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderImage(Property property) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.home_work_rounded,
            size: 60,
            color: Colors.white.withOpacity(0.8),
          ),
          const SizedBox(height: 8),
          Text(
            '${property.images?.length ?? 0} Photos',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmenityChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF06B6D4).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF06B6D4).withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: const Color(0xFF06B6D4),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF06B6D4),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF164e63),
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAmenityChips(Property property) {
    final List<Widget> amenityWidgets = [];

    // Collect all available amenities
    final List<MapEntry<String, IconData>> availableAmenities = [];

    if (property.amenities.wifi) availableAmenities.add(const MapEntry('WiFi', Icons.wifi));
    if (property.amenities.ac) availableAmenities.add(const MapEntry('AC', Icons.ac_unit));
    if (property.amenities.foodIncluded) availableAmenities.add(const MapEntry('Food', Icons.restaurant));
    if (property.amenities.laundry) availableAmenities.add(const MapEntry('Laundry', Icons.local_laundry_service));
    if (property.amenities.parking) availableAmenities.add(const MapEntry('Parking', Icons.local_parking));
    if (property.amenities.geyser) availableAmenities.add(const MapEntry('Geyser', Icons.hot_tub));
    if (property.amenities.powerBackup) availableAmenities.add(const MapEntry('Backup', Icons.power));
    if (property.amenities.cctv) availableAmenities.add(const MapEntry('CCTV', Icons.security));
    if (property.amenities.housekeeping) availableAmenities.add(const MapEntry('Cleaning', Icons.cleaning_services));

    // Show first 3 amenities
    for (int i = 0; i < availableAmenities.length && i < 3; i++) {
      amenityWidgets.add(_buildAmenityChip(
        availableAmenities[i].value,
        availableAmenities[i].key,
      ));
    }

    // Add +X chip if there are more than 3 amenities
    if (availableAmenities.length > 3) {
      final remainingCount = availableAmenities.length - 3;
      amenityWidgets.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey[300]!,
            ),
          ),
          child: Text(
            '+$remainingCount',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: amenityWidgets,
    );
  }
}

