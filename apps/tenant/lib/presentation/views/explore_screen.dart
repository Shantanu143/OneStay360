import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:common_ui/common_ui.dart';
import 'package:models/business/property/property_model.dart';
import '../view_models/explore_viewmodel.dart';
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

  FloatingActionButton _buildFloatingActionButton(BuildContext context) {
    final theme = Theme.of(context);
    return FloatingActionButton.small(
      onPressed: () {
        HapticFeedback.mediumImpact();
        final viewModel = Provider.of<ExploreViewModel>(context, listen: false);
        viewModel.refreshData();
      },
      backgroundColor: Colors.white,
      foregroundColor: theme.primaryColor,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.primaryColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: const Icon(Icons.refresh_rounded, size: 20),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TenantScaffold(
      currentTab: TenantTab.explore,
      body: SafeArea(
        child: Consumer<ExploreViewModel>(
          builder: (context, viewModel, child) {
            return Column(
              children: [
                // Integrated Search & Location Header
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
      floatingActionButton: _buildFloatingActionButton(context),
    );
  }

  Widget _buildHeader(ExploreViewModel viewModel) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.primaryColor.withOpacity(0.15),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.primaryColor.withOpacity(0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.search_rounded,
                  color: theme.primaryColor,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => viewModel.updateSearchQuery(value),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1E293B),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search area, PG, or amenities...',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _searchController.clear();
                      viewModel.clearSearch();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.clear_rounded,
                        size: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                Container(
                  height: 24,
                  width: 1.5,
                  color: Colors.grey[200],
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                ),
                // Integrated Dropdown City Selector
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: viewModel.selectedCity,
                    isDense: true,
                    elevation: 3,
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: theme.primaryColor,
                      size: 18,
                    ),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.primaryColor,
                    ),
                    items: viewModel.availableCities.map((city) => DropdownMenuItem(
                      value: city,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            color: theme.primaryColor,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(city),
                        ],
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(ExploreViewModel viewModel) {
    final theme = Theme.of(context);
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.grey.shade50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: viewModel.availableFilters.length,
        itemBuilder: (context, index) {
          final filter = viewModel.availableFilters[index];
          final isSelected = viewModel.selectedFilter == filter;
          final displayName = viewModel.getFilterDisplayName(filter);
          final icon = _getFilterIcon(filter);

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              viewModel.updateFilter(filter);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(
                        colors: [theme.primaryColor, theme.colorScheme.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isSelected ? null : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? Colors.transparent : Colors.grey.shade200,
                  width: 1.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: theme.primaryColor.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 14,
                    color: isSelected ? Colors.white : Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    displayName,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected ? Colors.white : Colors.grey[700],
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _getFilterIcon(ExploreFilter filter) {
    switch (filter) {
      case ExploreFilter.all:
        return Icons.grid_view_rounded;
      case ExploreFilter.nearMe:
        return Icons.near_me_rounded;
      case ExploreFilter.underTenK:
        return Icons.currency_rupee_rounded;
      case ExploreFilter.girlsOnly:
        return Icons.female_rounded;
      case ExploreFilter.boysOnly:
        return Icons.male_rounded;
      case ExploreFilter.furnished:
        return Icons.chair_rounded;
      case ExploreFilter.verified:
        return Icons.verified_rounded;
      case ExploreFilter.featured:
        return Icons.star_rounded;
    }
  }

  Widget _buildResultsHeader(ExploreViewModel viewModel) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            '${viewModel.propertyCount} PGs found in ${viewModel.selectedCity}',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          if (viewModel.propertyCount > 0)
            InkWell(
              onTap: () => _showSortBottomSheet(context, viewModel),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.sort_rounded,
                      size: 18,
                      color: theme.primaryColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Sort (${_getSortOptionLabel(viewModel.sortOption)})',
                      style: TextStyle(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getSortOptionLabel(ExploreSortOption option) {
    switch (option) {
      case ExploreSortOption.relevance:
        return 'Relevance';
      case ExploreSortOption.priceLowToHigh:
        return 'Price: L-H';
      case ExploreSortOption.priceHighToLow:
        return 'Price: H-L';
      case ExploreSortOption.rating:
        return 'Rating';
      case ExploreSortOption.newest:
        return 'Newest';
      case ExploreSortOption.occupancy:
        return 'Availability';
    }
  }

  void _showSortBottomSheet(BuildContext context, ExploreViewModel viewModel) {
    final theme = Theme.of(context);
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Consumer<ExploreViewModel>(
          builder: (context, vm, child) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Sort By',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  _buildSortOptionTile(
                    context,
                    vm,
                    ExploreSortOption.relevance,
                    'Relevance',
                    Icons.star_outline_rounded,
                  ),
                  _buildSortOptionTile(
                    context,
                    vm,
                    ExploreSortOption.priceLowToHigh,
                    'Price: Low to High',
                    Icons.trending_up_rounded,
                  ),
                  _buildSortOptionTile(
                    context,
                    vm,
                    ExploreSortOption.priceHighToLow,
                    'Price: High to Low',
                    Icons.trending_down_rounded,
                  ),
                  _buildSortOptionTile(
                    context,
                    vm,
                    ExploreSortOption.rating,
                    'Rating',
                    Icons.grade_rounded,
                  ),
                  _buildSortOptionTile(
                    context,
                    vm,
                    ExploreSortOption.newest,
                    'Newest',
                    Icons.fiber_new_rounded,
                  ),
                  _buildSortOptionTile(
                    context,
                    vm,
                    ExploreSortOption.occupancy,
                    'Availability',
                    Icons.event_seat_rounded,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSortOptionTile(
    BuildContext context,
    ExploreViewModel viewModel,
    ExploreSortOption option,
    String label,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    final isSelected = viewModel.sortOption == option;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        viewModel.updateSortOption(option);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        color: isSelected ? theme.primaryColor.withOpacity(0.05) : null,
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? theme.primaryColor : Colors.grey[600],
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? theme.primaryColor : const Color(0xFF1E293B),
              ),
            ),
            const Spacer(),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: theme.primaryColor,
                size: 20,
              )
            else
              Icon(
                Icons.circle_outlined,
                color: Colors.grey[300],
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyList(ExploreViewModel viewModel) {
    final theme = Theme.of(context);
    if (viewModel.isLoading && viewModel.properties.isEmpty) {
      return _buildLoadingSkeletonList();
    }

    if (viewModel.hasError) {
      return ErrorStateWidget(
        message: viewModel.errorMessage,
        onRetry: () => viewModel.refreshData(),
      );
    }

    if (viewModel.properties.isEmpty) {
      return EmptyStateWidget(
        title: 'No PGs found',
        message: 'Try adjusting your filters or search terms',
        icon: Icons.search_off_rounded,
        onAction: () => viewModel.resetFilters(),
        actionLabel: 'Reset Filters',
      );
    }

    return RefreshIndicator(
      onRefresh: () => viewModel.refreshData(),
      color: theme.primaryColor,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: viewModel.properties.length + (viewModel.hasMoreData ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == viewModel.properties.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.primaryColor,
                  ),
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

  Widget _buildLoadingSkeletonList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LoadingSkeleton(
                height: 200,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        LoadingSkeleton(
                          width: MediaQuery.of(context).size.width * 0.4,
                          height: 20,
                        ),
                        LoadingSkeleton(
                          width: MediaQuery.of(context).size.width * 0.2,
                          height: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    LoadingSkeleton(
                      width: MediaQuery.of(context).size.width * 0.6,
                      height: 14,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: List.generate(
                        3,
                        (index) => Container(
                          margin: const EdgeInsets.only(right: 8),
                          child: const LoadingSkeleton(
                            width: 60,
                            height: 22,
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const LoadingSkeleton(
                      height: 14,
                    ),
                    const SizedBox(height: 6),
                    const LoadingSkeleton(
                      height: 5,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBadge({
    required Widget child,
    required Color backgroundColor,
    BorderSide? border,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: border != null ? Border.fromBorderSide(border) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildGenderBadge(Property property, ExploreViewModel viewModel) {
    final text = viewModel.getGenderText(property);
    final color = viewModel.getGenderColor(property);
    final borderColor = viewModel.getGenderBorderColor(property);
    final textColor = viewModel.getGenderTextColor(property);
    
    IconData iconData;
    if (text.toLowerCase().contains('girl')) {
      iconData = Icons.female_rounded;
    } else if (text.toLowerCase().contains('boy')) {
      iconData = Icons.male_rounded;
    } else {
      iconData = Icons.wc_rounded;
    }
    
    return _buildBadge(
      backgroundColor: color.withOpacity(0.95),
      border: BorderSide(color: borderColor),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, color: textColor, size: 12),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityMeter(Property property) {
    final available = property.totals.availableBeds;
    final total = property.totals.beds;
    if (total == 0) return const SizedBox.shrink();
    
    final fillRatio = (total - available) / total;
    final availabilityRatio = available / total;
    
    Color progressColor;
    String statusText;
    if (availabilityRatio > 0.5) {
      progressColor = const Color(0xFF10B981);
      statusText = 'Plenty available';
    } else if (availabilityRatio > 0.2) {
      progressColor = Colors.orange;
      statusText = 'Filling fast';
    } else if (available > 0) {
      progressColor = Colors.red;
      statusText = 'Almost full';
    } else {
      progressColor = Colors.grey;
      statusText = 'Sold out';
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.event_seat_rounded,
                  size: 14,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  '$available / $total beds available',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            Text(
              statusText,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: progressColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fillRatio,
            minHeight: 5,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
          ),
        ),
      ],
    );
  }

  Widget _buildPgCard(Property property, ExploreViewModel viewModel) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image / PageView Carousel Section
          Container(
            height: 200,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: PropertyImageCarousel(
                    property: property,
                    fallbackBuilder: (context) => _buildPlaceholderImage(property),
                  ),
                ),

                // Overlay gradient for readability
                Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.15),
                        Colors.transparent,
                        Colors.black.withOpacity(0.1),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),

                // Floating Badges: Top-Left
                Positioned(
                  top: 12,
                  left: 12,
                  child: Row(
                    children: [
                      if (property.featured)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _buildBadge(
                            backgroundColor: Colors.orange.withOpacity(0.95),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  color: Colors.white,
                                  size: 12,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Featured',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      _buildBadge(
                        backgroundColor: const Color(0xFF10B981).withOpacity(0.95),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified_rounded,
                              color: Colors.white,
                              size: 12,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Verified',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Rating: Top-Right
                Positioned(
                  top: 12,
                  right: 12,
                  child: _buildBadge(
                    backgroundColor: Colors.white.withOpacity(0.9),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star_rounded,
                          color: Colors.amber[600],
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          property.rating.average.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Gender Badge: Bottom-Left
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: _buildGenderBadge(property, viewModel),
                ),
              ],
            ),
          ),

          // Content Details Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name and Price Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        property.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    (() {
                      final priceRange = viewModel.getPriceRange(property);
                      final priceParts = priceRange.split('/');
                      final displayPrice = priceParts[0];
                      final displayUnit = priceParts.length > 1 ? '/${priceParts[1]}' : '/mo';
                      return RichText(
                        text: TextSpan(
                          style: const TextStyle(color: Color(0xFF1E293B)),
                          children: [
                            TextSpan(
                              text: displayPrice,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: theme.primaryColor,
                              ),
                            ),
                            TextSpan(
                              text: ' $displayUnit',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      );
                    }()),
                  ],
                ),
                const SizedBox(height: 6),

                // Location Row
                Row(
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      color: theme.primaryColor,
                      size: 15,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${property.address}, ${property.city}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Styled Amenity Badges
                _buildAmenityChips(property),
                const SizedBox(height: 16),

                const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 16),

                // Availability Progress Indicator
                _buildAvailabilityMeter(property),
                const SizedBox(height: 16),

                // Bottom actions and stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatItem(
                      Icons.meeting_room_rounded,
                      property.totals.rooms.toString(),
                      'Rooms',
                    ),
                    
                    // View Details Button with Gradient Background
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [theme.primaryColor, theme.colorScheme.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: theme.primaryColor.withOpacity(0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () => _navigateToPGDetail(property, viewModel),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'View Details',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.chevron_right_rounded, size: 16),
                          ],
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
    final theme = Theme.of(context);
    final hasImages = property.images != null && property.images!.isNotEmpty;
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.primaryColor.withOpacity(0.8),
            theme.colorScheme.secondary.withOpacity(0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported_rounded,
              size: 48,
              color: Colors.white.withOpacity(0.8),
            ),
            const SizedBox(height: 8),
            Text(
              hasImages ? 'Loading Image...' : 'No Photos Available',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
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
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAmenityChips(Property property) {
    final theme = Theme.of(context);
    final List<Widget> amenityWidgets = [];
    final List<MapEntry<String, IconData>> availableAmenities = [];

    if (property.amenities.wifi) availableAmenities.add(const MapEntry('WiFi', Icons.wifi_rounded));
    if (property.amenities.ac) availableAmenities.add(const MapEntry('AC', Icons.ac_unit_rounded));
    if (property.amenities.foodIncluded) availableAmenities.add(const MapEntry('Food', Icons.restaurant_rounded));
    if (property.amenities.laundry) availableAmenities.add(const MapEntry('Laundry', Icons.local_laundry_service_rounded));
    if (property.amenities.parking) availableAmenities.add(const MapEntry('Parking', Icons.local_parking_rounded));
    if (property.amenities.geyser) availableAmenities.add(const MapEntry('Geyser', Icons.hot_tub_rounded));
    if (property.amenities.powerBackup) availableAmenities.add(const MapEntry('Backup', Icons.bolt_rounded));
    if (property.amenities.cctv) availableAmenities.add(const MapEntry('CCTV', Icons.security_rounded));
    if (property.amenities.housekeeping) availableAmenities.add(const MapEntry('Cleaning', Icons.cleaning_services_rounded));

    for (int i = 0; i < availableAmenities.length && i < 3; i++) {
      amenityWidgets.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: theme.primaryColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.primaryColor.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                availableAmenities[i].value,
                size: 12,
                color: theme.primaryColor,
              ),
              const SizedBox(width: 4),
              Text(
                availableAmenities[i].key,
                style: TextStyle(
                  fontSize: 10,
                  color: theme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (availableAmenities.length > 3) {
      final remainingCount = availableAmenities.length - 3;
      amenityWidgets.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.grey[200]!,
              width: 1,
            ),
          ),
          child: Text(
            '+$remainingCount more',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
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

class PropertyImageCarousel extends StatefulWidget {
  final Property property;
  final Widget Function(BuildContext) fallbackBuilder;

  const PropertyImageCarousel({
    super.key,
    required this.property,
    required this.fallbackBuilder,
  });

  @override
  State<PropertyImageCarousel> createState() => _PropertyImageCarouselState();
}

class _PropertyImageCarouselState extends State<PropertyImageCarousel> {
  int _currentPage = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.property.images;
    if (images == null || images.isEmpty) {
      return widget.fallbackBuilder(context);
    }

    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() {
              _currentPage = index;
            });
          },
          itemCount: images.length,
          itemBuilder: (context, index) {
            return CachedNetworkImage(
              imageUrl: images[index],
              fit: BoxFit.cover,
              width: double.infinity,
              height: 200,
              placeholder: (context, url) => Container(
                color: Colors.grey[100],
                child: const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF06B6D4),
                    ),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => widget.fallbackBuilder(context),
            );
          },
        ),
        if (images.length > 1)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                images.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _currentPage == index ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? Colors.white
                        : Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
