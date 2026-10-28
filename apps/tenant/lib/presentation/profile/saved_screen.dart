// lib/presentation/profile/saved_screen.dart
import 'package:flutter/material.dart';
import 'package:models/business/property/property_model.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../data/sources.dart';
import '../../data/tenant_session.dart';
import '../design/components/app_scaffold.dart';
import '../design/components/app_states.dart';
import '../design/motion.dart';
import '../explore/property_card.dart';

/// PGs the tenant saved with the heart.
class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  final Map<String, Property?> _loaded = {};

  Future<void> _load(Iterable<String> ids) async {
    final backend = context.read<TenantBackend>();
    for (final id in ids.where((id) => !_loaded.containsKey(id))) {
      _loaded[id] = null;
      try {
        final p = await backend.loadProperty(id);
        if (mounted) setState(() => _loaded[id] = p);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<TenantSession>();
    final ids = (session.account?.favorites ?? const <String>{}).toList();
    _load(ids);
    final properties = [for (final id in ids) if (_loaded[id] != null) _loaded[id]!];
    final waiting = ids.any((id) => _loaded[id] == null);

    return AppScaffold(
      title: 'Saved PGs',
      body: ids.isEmpty
          ? const AppEmptyState(
              icon: Icons.favorite_border_rounded,
              title: 'Nothing saved yet',
              message: 'Tap the heart on any PG in Explore to keep it here.',
            )
          : properties.isEmpty && waiting
              ? const Padding(padding: EdgeInsets.all(16), child: AppSkeletonList(count: 2, cardHeight: 260))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: properties.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, i) {
                    final p = properties[i];
                    return EntranceFade(
                      key: ValueKey(p.id),
                      delay: Duration(milliseconds: 50 * i),
                      child: PropertyCard(
                        property: p,
                        saved: true,
                        onTap: () => openProperty(context, p.id ?? '', preview: p),
                        onToggleSaved: () {
                          final uid = session.uid;
                          if (uid != null && p.id != null) context.read<TenantBackend>().setFavorite(uid, p.id!, false);
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
