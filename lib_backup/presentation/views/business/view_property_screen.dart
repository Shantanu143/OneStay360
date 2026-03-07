// lib/presentation/views/business/view_property_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:onestay360/data/repositories/property_repository.dart';
import 'package:onestay360/presentation/view_models/business/view_property_viewmodel.dart';
import 'package:onestay360/data/services/property_room_service.dart';
import 'package:onestay360/presentation/views/business/request_detail_screen.dart';
import 'package:onestay360/data/models/tenant/tenant_request_model.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:onestay360/presentation/views/business/widgets/business_scaffold.dart';

class ViewPropertyScreen extends StatefulWidget {
  final String propertyId;
  final int? initialTabIndex;

  const ViewPropertyScreen({
    super.key,
    required this.propertyId,
    this.initialTabIndex,
  });

  @override
  State<ViewPropertyScreen> createState() => _ViewPropertyScreenState();
}

class _ViewPropertyScreenState extends State<ViewPropertyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const int kTabLayout = 0;
  static const int kTabOverview = 1;
  static const int kTabTenants = 2;
  static const int kTabFinancials = 3;
  static const int kTabRequests = 4;
  static const int kTabQr = 5;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    if (widget.initialTabIndex != null &&
        widget.initialTabIndex! >= 0 &&
        widget.initialTabIndex! < _tabController.length) {
      _tabController.index = widget.initialTabIndex!;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final propertyRepository = context.read<PropertyRepository>();
    final roomService = PropertyRoomService();

    return ChangeNotifierProvider(
      create: (_) => ViewPropertyViewModel(
        propertyRepository: propertyRepository,
        roomService: roomService,
      )
        ..loadProperty(widget.propertyId)
        ..listenRequests(widget.propertyId),
      child: Consumer<ViewPropertyViewModel>(
        builder: (context, viewModel, _) {
          // Title uses property name when available - NOW USED WITHIN DEFAULT HEADER STRUCTURE
          final titleWidget = Text(
            viewModel.property?.name ?? 'Property Details',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );

          return BusinessScaffold(
            currentTab: BusinessTab.properties,
            showBackButton: true,
            title: titleWidget, // This will be used within the default header structure
            // REMOVED: actions parameter to use default actions (which include notification bell)
            appBarBottom: _buildAppBarTabs(context, viewModel),
            body: _buildBody(viewModel),
          );
        },
      ),
    );
  }

  // REMOVED: _buildAppBarActions method entirely since we're using default actions

  PreferredSizeWidget _buildAppBarTabs(
      BuildContext context, ViewPropertyViewModel viewModel) {
    final requestCount = viewModel.pendingRequestsCount;

    return PreferredSize(
      preferredSize: const Size.fromHeight(48),
      child: Container(
        color: Colors.white,
        child: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: const Color(0xFF2E7D32),
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: const Color(0xFF2E7D32),
          indicatorWeight: 3,
          labelStyle:
          const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          unselectedLabelStyle:
          const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          tabs: [
            const Tab(text: 'Layout'),
            const Tab(text: 'Overview'),
            const Tab(text: 'Tenants'),
            const Tab(text: 'Financials'),
            Tab(
              child: Row(
                children: [
                  const Text('Requests'),
                  if (requestCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$requestCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'QR'),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ViewPropertyViewModel viewModel) {
    if (viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (viewModel.hasError) {
      return _buildErrorState(viewModel);
    }

    if (viewModel.property == null) {
      return _buildEmptyState();
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildLayoutTab(viewModel),
        _buildOverviewTab(viewModel),
        _buildTenantsTab(viewModel),
        _buildFinancialsTab(viewModel),
        _buildRequestsTab(viewModel),
        _buildQrTab(viewModel),
      ],
    );
  }

  Widget _buildErrorState(ViewPropertyViewModel viewModel) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
          const SizedBox(height: 16),
          Text(
            'Failed to load property',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            viewModel.error ?? 'Unknown error',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => viewModel.refreshProperty(widget.propertyId),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.home_work_outlined,
              size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text(
            'Property not found',
            style: TextStyle(fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildLayoutTab(ViewPropertyViewModel viewModel) {
    final floors = viewModel.getFloorsFromProperty();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOccupancyStats(viewModel),
          const SizedBox(height: 20),
          ...floors.asMap().entries.map((entry) {
            final floorIndex = entry.key;
            final floor = entry.value;
            return _buildFloorSection(floorIndex, floor);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildOccupancyStats(ViewPropertyViewModel viewModel) {
    final stats = viewModel.propertyStats;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
                'Total Rooms', stats['totalRooms'].toString(), Colors.blue),
          ),
          Expanded(
            child: _buildStatItem('Occupied Rooms',
                stats['occupiedRooms'].toString(), Colors.orange),
          ),
          Expanded(
            child: _buildStatItem(
                'Total Beds', stats['totalBeds'].toString(), Colors.green),
          ),
          Expanded(
            child: _buildStatItem(
                'Occupied Beds', stats['occupiedBeds'].toString(), Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFloorSection(int floorIndex, Map<String, dynamic> floor) {
    final rooms = floor['rooms'] as List<dynamic>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Floor ${floorIndex + 1}',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2E7D32),
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: rooms.length,
          itemBuilder: (context, roomIndex) {
            final room = rooms[roomIndex] as Map<String, dynamic>;
            return _buildRoomCard(room, floorIndex, roomIndex);
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildRoomCard(
      Map<String, dynamic> room, int floorIndex, int roomIndex) {
    final beds = room['beds'] as List<dynamic>? ?? [];
    final occupiedBeds =
        beds.where((bed) => bed['isOccupied'] == true).length;
    final totalBeds = beds.length;
    final occupancyRate = totalBeds > 0 ? occupiedBeds / totalBeds : 0.0;

    Color cardColor;
    if (occupancyRate == 0) {
      cardColor = Colors.green.shade50;
    } else if (occupancyRate == 1) {
      cardColor = Colors.red.shade50;
    } else {
      cardColor = Colors.orange.shade50;
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _showRoomDetails(room, floorIndex, roomIndex);
      },
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: occupancyRate == 0
                ? Colors.green.shade200
                : occupancyRate == 1
                ? Colors.red.shade200
                : Colors.orange.shade200,
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    room['number'] ?? 'Room ${roomIndex + 1}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: occupancyRate == 0
                          ? Colors.green
                          : occupancyRate == 1
                          ? Colors.red
                          : Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$occupiedBeds/$totalBeds',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Rent: ₹${room['rent'] ?? 'N/A'}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Type: ${room['type'] ?? 'Standard'}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              const Spacer(),
              Wrap(
                spacing: 4,
                children: beds.asMap().entries.map((entry) {
                  final bedIndex = entry.key;
                  final bed = entry.value as Map<String, dynamic>;
                  return Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: bed['isOccupied'] == true
                          ? Colors.red
                          : Colors.green,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        '${bedIndex + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRoomDetails(
      Map<String, dynamic> room, int floorIndex, int roomIndex) {
    showDialog(
      context: context,
      builder: (context) {
        final beds = room['beds'] as List<dynamic>? ?? [];
        return AlertDialog(
          title: Text('Room ${room['number'] ?? 'N/A'} (Floor ${floorIndex + 1})'),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Type: ${room['type'] ?? 'N/A'}'),
              Text('Rent: ₹${room['rent'] ?? 'N/A'}'),
              const SizedBox(height: 12),
              const Text('Beds:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...beds.asMap().entries.map((entry) {
                final bedIndex = entry.key;
                final bed = entry.value as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: bed['isOccupied'] == true
                              ? Colors.red
                              : Colors.green,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Center(
                          child: Text(
                            '${bedIndex + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                          'Bed ${bedIndex + 1}: ${bed['isOccupied'] == true ? 'Occupied' : 'Vacant'}'),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOverviewTab(ViewPropertyViewModel viewModel) {
    final stats = viewModel.propertyStats;
    final amenities = viewModel.amenities;
    final owner = viewModel.ownerInfo;
    final property = viewModel.property!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _buildStatCard('Total Rooms', '${stats['totalRooms']}',
                  Icons.meeting_room_outlined, Colors.blue.shade600),
              _buildStatCard(
                  'Occupancy Rate',
                  '${(stats['occupancyRate'] * 100).toStringAsFixed(0)}%',
                  Icons.people_outline,
                  Colors.green.shade600),
              _buildStatCard(
                  'Monthly Revenue',
                  '₹ ${(stats['monthlyRevenue'] / 1000).toStringAsFixed(0)}K',
                  Icons.currency_rupee,
                  Colors.orange.shade600),
              _buildStatCard(
                  'Pending Payments',
                  '₹ ${(stats['pendingPayments'] / 1000).toStringAsFixed(0)}K',
                  Icons.pending_actions,
                  Colors.red.shade600),
            ],
          ),
          const SizedBox(height: 24),
          _buildInfoCard('Property Information', [
            _buildInfoRow('Type', property.status),
            _buildInfoRow('Address', property.address),
            _buildInfoRow('City', '${property.city}, ${property.cityCode}'),
            _buildInfoRow('Pincode', property.pincode),
          ]),
          const SizedBox(height: 16),
          if (property.description.isNotEmpty)
            _buildInfoCard('Description', [
              Text(
                property.description,
                style: TextStyle(color: Colors.grey.shade700, height: 1.5),
              ),
            ]),
          if (property.description.isNotEmpty) const SizedBox(height: 16),
          _buildInfoCard('Amenities', [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: amenities.map((amenity) {
                return Chip(
                  label: Text(amenity),
                  backgroundColor: Colors.teal.shade50,
                  labelStyle: TextStyle(color: Colors.teal.shade700),
                );
              }).toList(),
            ),
          ]),
          const SizedBox(height: 16),
          _buildInfoCard('Owner Information', [
            _buildInfoRow('Name', owner['name']),
            _buildInfoRow('Phone', owner['phone']),
            _buildInfoRow('WhatsApp', owner['whatsapp']),
            _buildInfoRow('Email', owner['email']),
          ]),
        ],
      ),
    );
  }

  Widget _buildTenantsTab(ViewPropertyViewModel viewModel) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search tenants by name, room, or phone...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: viewModel.searchQuery.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => viewModel.updateSearchQuery(''),
              )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF2E7D32)),
              ),
            ),
            onChanged: viewModel.updateSearchQuery,
          ),
        ),
        Expanded(
          child: viewModel.filteredTenants.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  viewModel.searchQuery.isEmpty
                      ? Icons.people_outline
                      : Icons.search_off,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  viewModel.searchQuery.isEmpty
                      ? 'No tenants found'
                      : 'No tenants match your search',
                  style: TextStyle(
                      fontSize: 18, color: Colors.grey.shade600),
                ),
              ],
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: viewModel.filteredTenants.length,
            itemBuilder: (context, index) {
              final tenant = viewModel.filteredTenants[index]
              as Map<String, dynamic>;
              return _buildTenantCard(tenant);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTenantCard(Map<String, dynamic> tenant) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tenant['name'],
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  tenant['status'],
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.meeting_room, size: 16),
              const SizedBox(width: 4),
              Text('Room: ${tenant['room']}'),
              const SizedBox(width: 16),
              const Icon(Icons.currency_rupee, size: 16),
              const SizedBox(width: 4),
              Text('Rent: ₹${tenant['rent']}'),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.phone, size: 16),
              const SizedBox(width: 4),
              Text('Phone: ${tenant['phone']}'),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 16),
              const SizedBox(width: 4),
              Text('Joined: ${tenant['joinDate']}'),
              const SizedBox(width: 16),
              const Icon(Icons.payment, size: 16),
              const SizedBox(width: 4),
              Text('Last Payment: ${tenant['lastPayment']}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialsTab(ViewPropertyViewModel viewModel) {
    final financials = viewModel.financials;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Financial Overview',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _buildStatCard(
                  'Monthly Revenue',
                  '₹ ${(financials['monthlyRevenue'] / 1000).toStringAsFixed(0)}K',
                  Icons.trending_up,
                  Colors.green.shade600),
              _buildStatCard(
                  'Yearly Revenue',
                  '₹ ${(financials['yearlyRevenue'] / 100000).toStringAsFixed(1)}L',
                  Icons.account_balance,
                  Colors.blue.shade600),
              _buildStatCard(
                  'Pending Payments',
                  '₹ ${(financials['pendingPayments'] / 1000).toStringAsFixed(0)}K',
                  Icons.pending_actions,
                  Colors.red.shade600),
              _buildStatCard('Net Income',
                  '₹ ${(financials['netIncome'] / 1000).toStringAsFixed(0)}K',
                  Icons.savings, Colors.purple.shade600),
            ],
          ),
          const SizedBox(height: 24),
          _buildInfoCard('Monthly Breakdown', [
            _buildInfoRow('Total Revenue', '₹ ${financials['monthlyRevenue']}'),
            _buildInfoRow('Expenses', '₹ ${financials['expenses']}'),
            _buildInfoRow('Net Income', '₹ ${financials['netIncome']}'),
            _buildInfoRow('Pending Payments', '₹ ${financials['pendingPayments']}'),
          ]),
        ],
      ),
    );
  }

  // Requests tab
  Widget _buildRequestsTab(ViewPropertyViewModel viewModel) {
    if (viewModel.requestsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (viewModel.requestsError != null) {
      return Center(
        child: Text(
          'Failed to load requests: ${viewModel.requestsError}',
          style: TextStyle(color: Colors.red.shade400),
        ),
      );
    }
    final requests = viewModel.requests;

    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('No requests yet'),
            const SizedBox(height: 4),
            const Text('Share your QR code to start receiving requests'),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final TenantRequest r = requests[index]; // Updated type usage
        final isPending = r.status == 'pending';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
            border: Border.all(
              color: isPending
                  ? Colors.orange.shade200
                  : (r.status == 'accepted'
                  ? Colors.green.shade200
                  : Colors.red.shade200),
            ),
          ),
          child: InkWell(
            onTap: () async {
              HapticFeedback.lightImpact();
              final changed = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RequestDetailScreen(
                      propertyId: widget.propertyId, request: r),
                ),
              );
              if (changed == true) {
                // Stream updates handled in view model
              }
            },
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.teal.shade50,
                  child: Icon(Icons.person_outline, color: Colors.teal.shade700),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.tenantName,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.phone,
                                size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(r.phone,
                                style:
                                TextStyle(color: Colors.grey.shade700)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (r.sharingType != null)
                              _chip('${r.sharingType}-Sharing',
                                  Colors.blue.shade50, Colors.blue.shade700),
                            _chip(
                                r.hasAC == true ? 'AC' : 'Non-AC',
                                Colors.purple.shade50,
                                Colors.purple.shade700),
                            _chip(r.status.toUpperCase(), _statusBg(r.status),
                                _statusFg(r.status)),
                          ],
                        ),
                      ]),
                ),
                const SizedBox(width: 12),
                Icon(Icons.arrow_forward_ios,
                    size: 16, color: Colors.grey.shade500),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _statusBg(String status) {
    switch (status) {
      case 'accepted':
        return Colors.green.shade50;
      case 'rejected':
        return Colors.red.shade50;
      default:
        return Colors.orange.shade50;
    }
  }

  Color _statusFg(String status) {
    switch (status) {
      case 'accepted':
        return Colors.green.shade700;
      case 'rejected':
        return Colors.red.shade700;
      default:
        return Colors.orange.shade700;
    }
  }

  Widget _chip(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
      BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text,
          style: TextStyle(
              color: fg, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }

  // QR tab
  Widget _buildQrTab(ViewPropertyViewModel viewModel) {
    final property = viewModel.property!;
    final payloadUrl = 'https://onestay.app/request?propertyId=${property.id}';
    final deeplink = 'onestay://request?propertyId=${property.id}';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              'Share QR to Receive Requests',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800),
            ),
            const SizedBox(height: 12),
            Text(
              'Tenants can scan this QR to send a request for ${property.name}.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.grey.shade200,
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Column(
                children: [
                  QrImageView(
                    data: payloadUrl,
                    version: QrVersions.auto,
                    size: 220,
                    gapless: false,
                    eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square, color: Colors.black),
                    dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.black),
                  ),
                  const SizedBox(height: 12),
                  Text(payloadUrl,
                      style:
                      TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: payloadUrl));
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Link copied')));
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy Link'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Share via share_plus if added
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Implement share via share_plus')));
                    },
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Deep link: $deeplink',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child:
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(title,
                  style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            Icon(icon, color: color, size: 20),
          ],
        ),
        const SizedBox(height: 8),
        Text(value,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800)),
      ]),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...children,
      ]),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child:
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 100,
          child: Text(label,
              style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500)),
        ),
        const Text(': '),
        Expanded(
          child: Text(value,
              style: TextStyle(
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}