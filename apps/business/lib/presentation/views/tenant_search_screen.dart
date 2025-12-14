import 'package:flutter/material.dart';
import 'package:firebase_services/services/tenant_search_service.dart';

class TenantSearchScreen extends StatefulWidget {
  final Function(TenantSearchResult)? onTenantSelected;

  const TenantSearchScreen({
    super.key,
    this.onTenantSelected,
  });

  @override
  State<TenantSearchScreen> createState() => _TenantSearchScreenState();
}

class _TenantSearchScreenState extends State<TenantSearchScreen> {
  final _searchController = TextEditingController();
  final _searchService = TenantSearchService();
  List<TenantSearchResult> _results = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _results = [];
      });
      return;
    }

    _performSearch(query);
  }

  Future<void> _performSearch(String query) async {
    if (query.length < 2) return;

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await _searchService.searchTenants(query);
      setState(() {
        _results = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Tenant'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or phone number',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              autofocus: true,
            ),
          ),
          if (_isSearching)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            )
          else if (_results.isEmpty && _searchController.text.isNotEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No tenants found'),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final tenant = _results[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: tenant.profileImage != null
                          ? NetworkImage(tenant.profileImage!)
                          : null,
                      child: tenant.profileImage == null
                          ? Text(tenant.name.isNotEmpty
                              ? tenant.name[0].toUpperCase()
                              : 'T')
                          : null,
                    ),
                    title: Text(tenant.name),
                    subtitle: Text(tenant.phone),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      if (widget.onTenantSelected != null) {
                        widget.onTenantSelected!(tenant);
                      }
                      Navigator.pop(context, tenant);
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}




