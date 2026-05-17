import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../view_models/business_properties_viewmodel.dart';
import 'package:models/business/property/property_model.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BusinessPropertiesViewModel>(
      builder: (context, viewModel, _) {
        if (viewModel.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (viewModel.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
                const SizedBox(height: 16),
                Text(
                  viewModel.error!,
                  style: TextStyle(color: Colors.grey.shade700),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final properties = viewModel.properties;

        if (properties.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.analytics_outlined, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No reports available',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add properties to see occupancy and revenue trends.',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => viewModel.refreshProperties(properties.first.businessId),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Property Occupancy Reports',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              ...properties.map((property) => _buildPropertyReportCard(context, property, viewModel)).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPropertyReportCard(BuildContext context, Property property, BusinessPropertiesViewModel viewModel) {
    final occupancyRate = viewModel.getOccupancyRate(property);
    final totalBeds = property.totals.beds;
    final availableBeds = property.totals.availableBeds;
    final occupiedBeds = totalBeds - availableBeds;
    
    // Calculate a rough estimated revenue from current occupancy
    final minRent = [
      property.pricing.single,
      property.pricing.double,
      property.pricing.triple
    ].where((v) => v > 0).fold(0, (a, b) => a == 0 ? b : (a < b ? a : b));
    
    final estimatedRevenue = occupiedBeds * (minRent > 0 ? minRent : 5000);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    property.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: viewModel.getStatusColor(property).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    viewModel.getStatusText(property),
                    style: TextStyle(
                      color: viewModel.getStatusColor(property),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    'Occupancy',
                    '${(occupancyRate * 100).toStringAsFixed(1)}%',
                    Icons.pie_chart,
                    Colors.teal.shade600,
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    'Beds',
                    '$occupiedBeds / $totalBeds',
                    Icons.bed,
                    Colors.blue.shade600,
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    'Est. Rev.',
                    '₹ ${(estimatedRevenue / 1000).toStringAsFixed(1)}K',
                    Icons.payments_outlined,
                    Colors.green.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: occupancyRate,
                backgroundColor: Colors.grey.shade200,
                color: _getOccupancyColor(occupancyRate),
                minHeight: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Color _getOccupancyColor(double rate) {
    if (rate >= 0.8) return Colors.green.shade600;
    if (rate >= 0.5) return Colors.yellow.shade700;
    return Colors.red.shade600;
  }
}
