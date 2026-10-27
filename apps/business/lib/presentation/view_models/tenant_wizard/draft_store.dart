// lib/presentation/view_models/tenant_wizard/draft_store.dart
import 'dart:convert';
import 'dart:io';

/// Persists a half-finished Add Tenant form so "Save draft" survives closing
/// the app.
abstract class WizardDraftStore {
  Future<Map<String, dynamic>?> read();
  Future<void> write(Map<String, dynamic> draft);
  Future<void> clear();
}

class MemoryDraftStore implements WizardDraftStore {
  Map<String, dynamic>? _draft;

  @override
  Future<Map<String, dynamic>?> read() async =>
      _draft == null ? null : Map.of(_draft!);

  @override
  Future<void> write(Map<String, dynamic> draft) async =>
      _draft = Map.of(draft);

  @override
  Future<void> clear() async => _draft = null;
}

/// One JSON file per business, in the app's documents folder.
class FileDraftStore implements WizardDraftStore {
  FileDraftStore(this.file);

  final File file;

  @override
  Future<Map<String, dynamic>?> read() async {
    try {
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null; // unreadable draft: behave as if there is none
    }
  }

  @override
  Future<void> write(Map<String, dynamic> draft) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(draft));
  }

  @override
  Future<void> clear() async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
