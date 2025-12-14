// lib/presentation/views/business/business_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'widgets/business_scaffold.dart';
import 'payment_methods_screen.dart';
import '../../data/providers/business_state_provider.dart';

class BusinessProfileScreen extends StatelessWidget {
  const BusinessProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFF0891B2);

    return DefaultTabController(
      length: 4,
      child: BusinessScaffold(
        currentTab: BusinessTab.profile, // FIXED: Changed from currentIndex to currentTab
        //titleText: 'Business Profile',
        appBarBottom: TabBar(
          labelColor: primary,
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: primary,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'KYC'),
            Tab(text: 'Team'),
            Tab(text: 'Settings'),
          ],
        ),
        body: const TabBarView(
          children: [
            _BusinessOverviewTab(),
            _BusinessKYCTab(),
            _BusinessTeamTab(),
            _BusinessSettingsTab(),
          ],
        ),
      ),
    );
  }
}

class _BusinessOverviewTab extends StatelessWidget {
  const _BusinessOverviewTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _CardSection(
          title: 'Company',
          child: _InfoRow(icon: Icons.apartment_rounded, label: 'Name', value: 'Acme Stays Pvt Ltd'),
        ),
        SizedBox(height: 16),
        _CardSection(
          title: 'Contact',
          child: Column(
            children: [
              _InfoRow(icon: Icons.email_outlined, label: 'Email', value: 'admin@acmestays.com'),
              SizedBox(height: 12),
              _InfoRow(icon: Icons.phone_outlined, label: 'Phone', value: '+91 90000 11111'),
            ],
          ),
        ),
        SizedBox(height: 16),
        _CardSection(
          title: 'Business Stats',
          child: _StatsRow(
            items: [
              _Stat(value: '12', label: 'Properties'),
              _Stat(value: '98', label: 'Tenants'),
              _Stat(value: '85%', label: 'Occupancy'),
            ],
          ),
        ),
      ],
    );
  }
}

class _BusinessKYCTab extends StatelessWidget {
  const _BusinessKYCTab();

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade300),
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _CardSection(
          title: 'Business KYC',
          child: Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  labelText: 'GSTIN',
                  hintText: '22ABCDE1234F1Z5',
                  border: border,
                  enabledBorder: border,
                  focusedBorder: border.copyWith(
                    borderSide: const BorderSide(color: Color(0xFF0891B2)),
                  ),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(
                  labelText: 'PAN (Company)',
                  hintText: 'ABCDE1234F',
                  border: border,
                  enabledBorder: border,
                  focusedBorder: border.copyWith(
                    borderSide: const BorderSide(color: Color(0xFF0891B2)),
                  ),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Registered Address',
                  border: border,
                  enabledBorder: border,
                  focusedBorder: border.copyWith(
                    borderSide: const BorderSide(color: Color(0xFF0891B2)),
                  ),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => HapticFeedback.lightImpact(),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save KYC'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _CardSection(
          title: 'Compliance Documents',
          child: Column(
            children: [
              OutlinedButton.icon(
                onPressed: () => HapticFeedback.lightImpact(),
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Upload Incorporation Certificate'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => HapticFeedback.lightImpact(),
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Upload Cancelled Cheque'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BusinessTeamTab extends StatelessWidget {
  const _BusinessTeamTab();

  @override
  Widget build(BuildContext context) {
    final team = [
      {'name': 'Priya Sharma', 'role': 'Manager', 'email': 'priya@acmestays.com'},
      {'name': 'Rahul Verma', 'role': 'Ops Lead', 'email': 'rahul@acmestays.com'},
      {'name': 'Anita Gupta', 'role': 'Support', 'email': 'anita@acmestays.com'},
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: team.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: () => HapticFeedback.lightImpact(),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Add Member'),
              ),
            ),
          );
        }
        final member = team[index - 1];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF0891B2).withOpacity(0.1),
              child: const Icon(Icons.person_outline, color: Color(0xFF0891B2)),
            ),
            title: Text(member['name']!),
            subtitle: Text('${member['role']} • ${member['email']}'),
            trailing: IconButton(
              icon: const Icon(Icons.more_horiz),
              onPressed: () => HapticFeedback.lightImpact(),
            ),
          ),
        );
      },
    );
  }
}

class _BusinessSettingsTab extends StatelessWidget {
  const _BusinessSettingsTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SettingsCard(
          children: [
            _SettingRow(
              icon: Icons.payment_outlined,
              title: 'Payment Methods',
              subtitle: 'Manage UPI, Bank, Cash',
              color: const Color(0xFF8b5cf6),
              onTap: () {
                final businessState = context.read<BusinessStateProvider>();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PaymentMethodsScreen(
                      businessId: businessState.businessId,
                    ),
                  ),
                );
              },
            ),
            const _RowDivider(),
            const _SettingRow(
              icon: Icons.password_outlined,
              title: 'Change Password',
              subtitle: 'Update account password',
              color: Color(0xFF3b82f6),
            ),
            const _RowDivider(),
            const _SettingRow(
              icon: Icons.notifications_active_outlined,
              title: 'Notifications',
              subtitle: 'Manage alerts & emails',
              color: Color(0xFFf59e0b),
            ),
            const _RowDivider(),
            const _SettingRow(
              icon: Icons.verified_user_outlined,
              title: 'Access Control',
              subtitle: 'Manage team permissions',
              color: Color(0xFF10b981),
            ),
            const _RowDivider(),
            const _SettingRow(
              icon: Icons.description_outlined,
              title: 'Billing',
              subtitle: 'Invoices & payments',
              color: Color(0xFF6366f1),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _SettingsCard(
          children: [
            _SettingRow(
              icon: Icons.logout_outlined,
              title: 'Logout',
              subtitle: 'Sign out of business account',
              color: Color(0xFFef4444),
            ),
          ],
        ),
      ],
    );
  }
}

// Reusable UI

class _CardSection extends StatelessWidget {
  final String title;
  final Widget child;
  const _CardSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF164e63),
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF0891B2).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF0891B2)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  final List<_Stat> items;
  const _StatsRow({required this.items});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: items
          .map((e) => Expanded(
        child: Column(
          children: [
            Text(
              e.value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Color(0xFF164e63),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              e.label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF475569),
              ),
            ),
          ],
        ),
      ))
          .toList(),
    );
  }
}

class _Stat {
  final String value;
  final String label;
  const _Stat({required this.value, required this.label});
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;
  const _SettingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
      onTap: onTap ?? () => HapticFeedback.lightImpact(),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, color: Colors.grey.shade200);
  }
}

