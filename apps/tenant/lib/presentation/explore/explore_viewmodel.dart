// lib/presentation/explore/explore_viewmodel.dart
import 'package:flutter/foundation.dart';
import 'package:models/business/property/property_model.dart';

import '../../data/firestore_sources.dart' show exploreCities;
import '../../data/sources.dart';
import 'property_facts.dart';

enum ExploreFilter {
  all('All'),
  saved('Saved'),
  budget('Under ₹10k'),
  girls('Girls'),
  boys('Boys'),
  coed('Co-ed'),
  ac('AC'),
  meals('Meals'),
  featured('Featured');

  const ExploreFilter(this.label);

  final String label;
}

enum ExploreSort {
  relevance('Recommended'),
  priceLow('Price: low to high'),
  priceHigh('Price: high to low'),
  rating('Top rated'),
  newest('Recently updated');

  const ExploreSort(this.label);

  final String label;
}

/// Browsing PGs in a city: paging, search, quick filters and sorting.
class ExploreViewModel extends ChangeNotifier {
  ExploreViewModel({
    required ExploreSource source,
    required Set<String> Function() favorites,
    String initialCity = 'Bangalore',
  })  : _source = source,
        _favorites = favorites,
        _city = initialCity;

  final ExploreSource _source;
  final Set<String> Function() _favorites;

  String _city;
  final List<Property> _all = [];
  Object? _cursor;
  bool _hasMore = true;
  bool _loading = false;
  bool _loadingMore = false;
  bool _loaded = false;
  String? _error;
  String _query = '';
  ExploreFilter _filter = ExploreFilter.all;
  ExploreSort _sort = ExploreSort.relevance;
  int _generation = 0;
  bool _disposed = false;

  String get city => _city;
  List<String> get cities => exploreCities;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  bool get loaded => _loaded;
  bool get hasMore => _hasMore;
  String? get error => _error;
  String get query => _query;
  ExploreFilter get filter => _filter;
  ExploreSort get sort => _sort;

  static int minPrice(Property p) => minPriceOf(p);
  static String priceLabel(Property p) => priceLabelOf(p);
  static String genderLabel(Property p) => genderLabelOf(p);

  List<Property> get visible {
    final q = _query.trim().toLowerCase();
    final favs = _favorites();
    final list = _all.where((p) {
      if (q.isNotEmpty) {
        final hay = '${p.name} ${p.address} ${p.landmarks} ${p.city}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return switch (_filter) {
        ExploreFilter.all => true,
        ExploreFilter.saved => favs.contains(p.id),
        ExploreFilter.budget => minPriceOf(p) > 0 && minPriceOf(p) < 10000,
        ExploreFilter.girls => genderOf(p) == GenderPolicy.girls,
        ExploreFilter.boys => genderOf(p) == GenderPolicy.boys,
        ExploreFilter.coed => genderOf(p) == GenderPolicy.coed,
        ExploreFilter.ac => p.amenities.ac,
        ExploreFilter.meals => p.amenities.foodIncluded,
        ExploreFilter.featured => p.featured,
      };
    }).toList();

    int price(Property p) => minPriceOf(p) == 0 ? 1 << 30 : minPriceOf(p);
    switch (_sort) {
      case ExploreSort.relevance:
        break;
      case ExploreSort.priceLow:
        list.sort((a, b) => price(a).compareTo(price(b)));
      case ExploreSort.priceHigh:
        list.sort((a, b) => minPriceOf(b).compareTo(minPriceOf(a)));
      case ExploreSort.rating:
        list.sort((a, b) {
          final r = b.rating.average.compareTo(a.rating.average);
          return r != 0 ? r : b.rating.count.compareTo(a.rating.count);
        });
      case ExploreSort.newest:
        list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }
    return list;
  }

  /// Loads (or reloads) the first page of the city.
  Future<void> load() async {
    final gen = ++_generation;
    _loading = true;
    _error = null;
    _notify();
    try {
      final page = await _source.loadCity(_city);
      if (gen != _generation) return;
      _all
        ..clear()
        ..addAll(page.properties);
      _cursor = page.cursor;
      _hasMore = page.hasMore;
      _loaded = true;
    } catch (e) {
      if (gen != _generation) return;
      debugPrint('❌ [Explore] $e');
      _all.clear();
      _hasMore = false;
      _error = "Couldn't load PGs in $_city. Check your connection and try again.";
    } finally {
      if (gen == _generation) {
        _loading = false;
        _notify();
      }
    }
  }

  Future<void> loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    final gen = _generation;
    _loadingMore = true;
    _notify();
    try {
      final page = await _source.loadCity(_city, cursor: _cursor);
      if (gen != _generation) return;
      final known = _all.map((p) => p.id).toSet();
      _all.addAll(page.properties.where((p) => !known.contains(p.id)));
      _cursor = page.cursor;
      _hasMore = page.hasMore;
    } catch (e) {
      debugPrint('⚠️ [Explore] more: $e');
      _hasMore = false;
    } finally {
      if (gen == _generation) {
        _loadingMore = false;
        _notify();
      }
    }
  }

  Future<void> setCity(String city) async {
    if (city == _city) return;
    _city = city;
    _all.clear();
    _cursor = null;
    _hasMore = true;
    _loaded = false;
    await load();
  }

  void setQuery(String q) {
    _query = q;
    _notify();
  }

  void setFilter(ExploreFilter f) {
    _filter = f;
    _notify();
  }

  void setSort(ExploreSort s) {
    _sort = s;
    _notify();
  }

  /// Saves or un-saves [p] on the account. The session's account stream
  /// brings the change back.
  Future<void> toggleFavorite(String uid, Property p) async {
    final id = p.id;
    if (id == null) return;
    try {
      await _source.setFavorite(uid, id, !_favorites().contains(id));
    } catch (e) {
      debugPrint('⚠️ [Explore] favourite: $e');
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
