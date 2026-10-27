// lib/presentation/explore/explore_tab.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../data/sources.dart';
import '../../data/tenant_session.dart';
import '../design/components/app_chips.dart';
import '../design/components/app_dialogs.dart';
import '../design/components/app_header.dart';
import '../design/components/app_scaffold.dart';
import '../design/components/app_search_field.dart';
import '../design/components/app_states.dart';
import '../design/components/floating_nav_bar.dart';
import '../design/motion.dart';
import '../design/tokens.dart';
import 'explore_viewmodel.dart';
import 'property_card.dart';

/// Browse PGs in a city: search, quick filters, sort, save.
class ExploreTab extends StatefulWidget {
  const ExploreTab({super.key});

  @override
  State<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<ExploreTab> {
  late final TenantSession _session = context.read<TenantSession>();
  late final ExploreViewModel _vm = ExploreViewModel(
    source: context.read<TenantBackend>(),
    favorites: () => _session.account?.favorites ?? const {},
  );
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _vm.load();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 600) _vm.loadMore();
    });
  }

  @override
  void dispose() {
    _vm.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _pickCity() async {
    final city = await showAppSheet<String>(
      context,
      title: 'Choose a city',
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          for (final c in _vm.cities)
            AppSheetOption(label: c, selected: c == _vm.city, onTap: () => Navigator.of(ctx).pop(c)),
        ],
      ),
    );
    if (city != null) _vm.setCity(city);
  }

  Future<void> _pickSort() async {
    final sort = await showAppSheet<ExploreSort>(
      context,
      title: 'Sort by',
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          for (final s in ExploreSort.values)
            AppSheetOption(label: s.label, selected: s == _vm.sort, onTap: () => Navigator.of(ctx).pop(s)),
        ],
      ),
    );
    if (sort != null) _vm.setSort(sort);
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild when saved PGs change on the account.
    context.select<TenantSession, int>((s) => s.account?.favorites.length ?? 0);
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        final list = _vm.visible;
        return AppScrollPage(
          controller: _scroll,
          eyebrow: 'PGs and hostels',
          title: 'Explore',
          bottomInset: FloatingNavBar.heightFor(context) + 12,
          onRefresh: _vm.load,
          actions: [
            AppRoundButton(icon: Icons.swap_vert_rounded, tooltip: 'Sort', onTap: _pickSort),
          ],
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(child: AppSearchField(hint: 'Search area, landmark or name', onChanged: _vm.setQuery)),
                    const SizedBox(width: 10),
                    Pressable(
                      onTap: _pickCity,
                      scale: 0.95,
                      semanticLabel: 'City: ${_vm.city}',
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
                        child: Row(
                          children: [
                            const Icon(Icons.place_rounded, size: 18, color: AppColors.green),
                            const SizedBox(width: 4),
                            Text(_vm.city, style: AppText.bodyStrong),
                            const Icon(Icons.expand_more_rounded, size: 20, color: AppColors.inkSoft),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 12),
                child: AppFilterChips(
                  chips: [for (final f in ExploreFilter.values) AppChipData(f.label)],
                  selectedIndex: _vm.filter.index,
                  onSelected: (i) => _vm.setFilter(ExploreFilter.values[i]),
                ),
              ),
            ),
            if (_vm.sort != ExploreSort.relevance || _vm.loaded)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: Text(
                    _vm.loading
                        ? 'Looking in ${_vm.city}…'
                        : '${list.length} ${list.length == 1 ? 'place' : 'places'} in ${_vm.city}'
                            '${_vm.sort == ExploreSort.relevance ? '' : ' · ${_vm.sort.label}'}',
                    style: AppText.caption,
                  ),
                ),
              ),
            if (_vm.loading && list.isEmpty)
              const SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(child: AppSkeletonList(count: 3, cardHeight: 260)),
              )
            else if (_vm.error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: AppErrorState(message: _vm.error!, onRetry: _vm.load),
              )
            else if (list.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _vm.filter == ExploreFilter.saved
                    ? const AppEmptyState(
                        icon: Icons.favorite_border_rounded,
                        title: 'No saved PGs here',
                        message: 'Tap the heart on a PG to keep it for later.',
                      )
                    : AppEmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'No PGs match',
                        message: _vm.query.isNotEmpty || _vm.filter != ExploreFilter.all
                            ? 'Try another search or filter.'
                            : 'No listings in ${_vm.city} yet. Try another city.',
                        actionLabel: _vm.filter != ExploreFilter.all ? 'Show all' : 'Change city',
                        onAction: _vm.filter != ExploreFilter.all ? () => _vm.setFilter(ExploreFilter.all) : _pickCity,
                      ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.separated(
                  itemCount: list.length + (_vm.loadingMore ? 1 : 0),
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, i) {
                    if (i == list.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
                      );
                    }
                    final p = list[i];
                    return EntranceFade(
                      key: ValueKey('${_vm.city}-${p.id}'),
                      delay: Duration(milliseconds: i < 6 ? 50 * i : 0),
                      child: PropertyCard(
                        property: p,
                        saved: _session.isFavorite(p.id ?? ''),
                        onTap: () => openProperty(context, p.id ?? '', preview: p),
                        onToggleSaved: () {
                          final uid = _session.uid;
                          if (uid != null) _vm.toggleFavorite(uid, p);
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}
