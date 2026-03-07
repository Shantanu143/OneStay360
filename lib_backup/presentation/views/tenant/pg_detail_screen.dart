import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:onestay360/presentation/view_models/tenant/pg_detail_viewmodel.dart';
import 'package:onestay360/data/models/business/property/property_model.dart';
import 'package:onestay360/data/repositories/property_repository.dart';
import 'widgets/tenant_scaffold.dart';
import 'enroll_request_screen.dart';

class PGDetailScreen extends StatefulWidget {
  final String propertyId;
  final Map<String, String>? pgData;

  const PGDetailScreen({
    super.key,
    required this.propertyId,
    this.pgData,
  });

  @override
  State<PGDetailScreen> createState() => _PGDetailScreenState();
}

class _PGDetailScreenState extends State<PGDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late PGDetailViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _viewModel = PGDetailViewModel(
      propertyRepository: Provider.of<PropertyRepository>(context, listen: false),
    );
    _loadProperty();
  }

  Future<void> _loadProperty() async {
    await _viewModel.loadPropertyDetails(widget.propertyId);
  }

  void _sendEnrollRequest() {
    if (_viewModel.property == null) return;

    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EnrollRequestScreen(
          pgName: _viewModel.property!.name,
          location: _viewModel.property!.address,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  // FIXED: Change return type to FloatingActionButton
  FloatingActionButton _buildFloatingActionButton(PGDetailViewModel viewModel) {
    return FloatingActionButton(
      onPressed: _sendEnrollRequest,
      backgroundColor: const Color(0xFF06B6D4),
      child: const Icon(Icons.send_rounded, color: Colors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<PGDetailViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading) {
            return TenantScaffold(
              currentTab: TenantTab.explore,
              showBackButton: true,
              body: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF06B6D4)),
                ),
              ),
            );
          }

          if (viewModel.hasError) {
            return TenantScaffold(
              currentTab: TenantTab.explore,
              showBackButton: true,
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Error Loading Property',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        viewModel.errorMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600], height: 1.4),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => viewModel.loadPropertyDetails(widget.propertyId),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF06B6D4),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final property = viewModel.property;
          if (property == null) {
            return TenantScaffold(
              currentTab: TenantTab.explore,
              showBackButton: true,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.home_work_outlined, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'Property Not Found',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'The property you\'re looking for doesn\'t exist or has been removed.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return TenantScaffold(
            currentTab: TenantTab.explore,
            showBackButton: true,
            actions: [
              _buildActionButton(
                icon: Icon(
                  viewModel.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: viewModel.isFavorite ? Colors.redAccent : Colors.grey[600],
                ),
                onPressed: viewModel.toggleFavorite,
              ),
              _buildActionButton(
                icon: const Icon(Icons.share_rounded),
                onPressed: viewModel.shareProperty,
              ),
            ],
            body: Column(
              children: [
                // Image Carousel
                _buildImageCarousel(viewModel),

                // Header Info
                _buildHeaderInfo(viewModel),

                // Tab Bar
                Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    onTap: viewModel.updateTabIndex,
                    labelColor: const Color(0xFF06B6D4),
                    unselectedLabelColor: Colors.grey[600],
                    indicatorColor: const Color(0xFF06B6D4),
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                    tabs: const [
                      Tab(text: 'Overview'),
                      Tab(text: 'Amenities'),
                      Tab(text: 'Rules'),
                      Tab(text: 'Rooms'),
                    ],
                  ),
                ),

                // Tab Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverviewTab(viewModel),
                      _buildAmenitiesTab(viewModel),
                      _buildRulesTab(viewModel),
                      _buildRoomsTab(viewModel),
                    ],
                  ),
                ),
              ],
            ),
            floatingActionButton: _buildFloatingActionButton(viewModel), // FIXED: Now returns FloatingActionButton
          );
        },
      ),
    );
  }

  Widget _buildActionButton({required Widget icon, required VoidCallback onPressed}) {
    return IconButton(
      icon: icon,
      onPressed: onPressed,
    );
  }

  Widget _buildImageCarousel(PGDetailViewModel viewModel) {
    final property = viewModel.property!;
    final images = property.images ?? [];
    final screenWidth = MediaQuery.of(context).size.width;

    if (images.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF06B6D4).withAlpha((0.9 * 255).round()),
              Color(0xFF0891B2).withAlpha((0.95 * 255).round()),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.home_work_rounded,
                  size: screenWidth * 0.15,
                            color: Colors.white.withAlpha((0.85 * 255).round())
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  property.name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 200,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            itemCount: images.length,
            onPageChanged: viewModel.updateImageIndex,
            itemBuilder: (context, index) {
              return CachedNetworkImage(
                imageUrl: images[index],
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[300],
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF06B6D4)),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF06B6D4).withAlpha((0.8 * 255).round()),
                        Color(0xFF0891B2).withAlpha((0.9 * 255).round()),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image_rounded,
                            size: screenWidth * 0.1,
                            color: Colors.white.withAlpha((0.8 * 255).round())
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Image ${index + 1}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // Gradient overlay
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black.withAlpha((0.15 * 255).round())],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // Page indicators
          if (images.length > 1)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(images.length, (index) {
                  final isActive = viewModel.currentImageIndex == index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive ? Colors.white : Colors.white.withAlpha((0.5 * 255).round()),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),

          // Rating badge
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withAlpha((0.15 * 255).round()),
                      blurRadius: 8,
                      offset: const Offset(0, 2)
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_rounded, color: Colors.amber[600], size: 18),
                  const SizedBox(width: 4),
                  Text(
                    property.rating.average.toStringAsFixed(1),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14
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

  Widget _buildHeaderInfo(PGDetailViewModel viewModel) {
    final property = viewModel.property!;
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name and Gender
          Row(
            children: [
              Expanded(
                child: Text(
                  property.name,
                  style: TextStyle(
                    fontSize: screenWidth * 0.055,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[850],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: viewModel.getGenderColor(),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: viewModel.getGenderBorderColor()),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person,
                      size: 14,
                      color: viewModel.getGenderTextColor(),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      viewModel.getGenderText(),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: viewModel.getGenderTextColor()
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Location row
          GestureDetector(
            onTap: viewModel.openGoogleMaps,
            child: Row(
              children: [
                const Icon(Icons.location_on_rounded, color: Color(0xFF06B6D4), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    property.address,
                    style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.open_in_new, size: 16, color: Colors.grey[500]),
              ],
            ),
          ),

          if (property.landmarks.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.place_rounded, color: Colors.grey[500], size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Near: ${property.landmarks}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),

          // Quick Stats
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                    Icons.meeting_room_rounded,
                    property.totals.rooms.toString(),
                    'Rooms',
                    Colors.blue
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                    Icons.bed_rounded,
                    property.totals.availableBeds.toString(),
                    'Available',
                    Colors.green
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                    Icons.people_rounded,
                    viewModel.getOccupancyText(),
                    'Occupied',
                    Colors.orange
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha((0.08 * 255).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha((0.18 * 255).round())),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600]
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(PGDetailViewModel viewModel) {
    final property = viewModel.property!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
              'About',
              property.description.isNotEmpty ? property.description : 'No description available.',
              Icons.info_outline_rounded
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
              'Food Plan',
              viewModel.getFoodPlanText(),
              Icons.restaurant_rounded
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
              'Location Details',
              viewModel.getLocationDetails(),
              Icons.location_on_outlined
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
              'Contact Information',
              viewModel.getContactDetails(),
              Icons.contact_phone_outlined
          ),
        ],
      ),
    );
  }

  Widget _buildAmenitiesTab(PGDetailViewModel viewModel) {
    final amenities = viewModel.getAmenityList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Amenities',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800]
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: amenities.map((amenity) {
              final isAvailable = amenity['available'] as bool;
              final IconData icon = amenity['icon'] as IconData;
              final String name = amenity['name'] as String;

              return FilterChip(
                avatar: CircleAvatar(
                  backgroundColor: isAvailable ?
                  Color(0xFF06B6D4).withAlpha((0.12 * 255).round()) :
                  Colors.grey.withAlpha((0.12 * 255).round()),
                  child: Icon(
                      icon,
                      size: 18,
                      color: isAvailable ? const Color(0xFF06B6D4) : Colors.grey
                  ),
                ),
                label: Text(
                  name,
                  style: TextStyle(
                      color: isAvailable ? Colors.grey[800] : Colors.grey[500],
                      fontWeight: FontWeight.w600
                  ),
                ),
                selected: isAvailable,
                onSelected: (_) {},
                selectedColor: Color(0xFF06B6D4).withAlpha((0.08 * 255).round()),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                        color: isAvailable ?
                        Color(0xFF06B6D4).withAlpha((0.12 * 255).round()) :
                        Colors.grey.withAlpha((0.12 * 255).round())
                    )
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Grid view for amenities
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: amenities.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.2
            ),
            itemBuilder: (context, index) {
              final amenity = amenities[index];
              final isAvailable = amenity['available'] as bool;

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isAvailable ?
                      Color(0xFF06B6D4).withAlpha((0.18 * 255).round()) :
                      Colors.grey.withAlpha((0.18 * 255).round())
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                        amenity['icon'] as IconData,
                        size: 28,
                        color: isAvailable ? const Color(0xFF06B6D4) : Colors.grey
                    ),
                    const SizedBox(height: 8),
                    Text(
                      amenity['name'] as String,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isAvailable ? Colors.grey[800] : Colors.grey[500]
                      ),
                    ),
                    const SizedBox(height: 6),
                    Icon(
                        isAvailable ? Icons.check_circle : Icons.cancel,
                        size: 16,
                        color: isAvailable ? Colors.green : Colors.red
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRulesTab(PGDetailViewModel viewModel) {
    final rules = viewModel.getHouseRules();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSectionCard(
              'House Rules',
              rules.map((rule) => '• $rule').join('\n'),
              Icons.rule_rounded
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
              'Payment Terms',
              viewModel.getPaymentTerms(),
              Icons.payment_rounded
          ),
        ],
      ),
    );
  }

  Widget _buildRoomsTab(PGDetailViewModel viewModel) {
    final roomTypes = viewModel.getRoomTypes();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Pricing Cards
          ...roomTypes.map((roomType) => _buildPricingCard(
            roomType['type'] as String,
            roomType['price'] as int,
            roomType['icon'] as IconData,
            roomType['description'] as String,
          )),

          const SizedBox(height: 16),

          // Room Summary
          _buildSectionCard(
            'Room Summary',
            'Total Rooms: ${viewModel.property!.totals.rooms}\n'
                'Total Beds: ${viewModel.property!.totals.beds}\n'
                'Available Beds: ${viewModel.property!.totals.availableBeds}\n'
                'Occupancy Rate: ${viewModel.getOccupancyText()}',
            Icons.bed_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildPricingCard(String title, int price, IconData icon, String description) {
    final formattedPrice = price.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},'
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF06B6D4).withAlpha((0.18 * 255).round())),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha((0.03 * 255).round()),
              blurRadius: 8,
              offset: const Offset(0, 2)
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Color(0xFF06B6D4).withAlpha((0.08 * 255).round()),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF06B6D4), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600]
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '₹$formattedPrice per month',
                  style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700]
                  ),
                ),
              ],
            ),
          ),
          Text(
            '₹$formattedPrice',
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF06B6D4)
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(String title, String content, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha((0.04 * 255).round()),
              blurRadius: 8,
              offset: const Offset(0, 2)
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Color(0xFF06B6D4).withAlpha((0.08 * 255).round()),
                    shape: BoxShape.circle
                ),
                child: Icon(icon, color: const Color(0xFF06B6D4), size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF164e63)
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
                color: Colors.grey[700],
                height: 1.45
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(PGDetailViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha((0.06 * 255).round()),
              blurRadius: 12,
              offset: const Offset(0, -2)
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Price
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Starting from',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600]
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    viewModel.getPriceRange(),
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF06B6D4)
                    ),
                  ),
                ],
              ),
            ),

            // Call Button
            Container(
              margin: const EdgeInsets.only(right: 12),
              child: ElevatedButton.icon(
                onPressed: viewModel.makeCall,
                icon: const Icon(Icons.phone_rounded, size: 18),
                label: const Text('Call'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            // Send Request Button
            ElevatedButton(
              onPressed: _sendEnrollRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF06B6D4),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                  'Send Request',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)
              ),
            ),
          ],
        ),
      ),
    );
  }
}