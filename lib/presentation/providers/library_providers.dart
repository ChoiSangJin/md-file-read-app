import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:md_file_read_app/data/models/recent_document.dart';
import 'package:md_file_read_app/data/repositories/drive_repository.dart';
import 'package:md_file_read_app/data/repositories/preferences_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

final preferencesRepositoryProvider = Provider<PreferencesRepository>((ref) {
  return PreferencesRepository(SharedPreferencesAsync());
});

final driveRepositoryProvider = Provider<DriveRepository>((ref) {
  final repository = DriveRepository();
  ref.onDispose(repository.disconnect);
  return repository;
});

final recentDocumentsProvider =
    AsyncNotifierProvider<RecentDocumentsNotifier, List<RecentDocument>>(
      RecentDocumentsNotifier.new,
    );

class RecentDocumentsNotifier extends AsyncNotifier<List<RecentDocument>> {
  @override
  Future<List<RecentDocument>> build() {
    return ref.read(preferencesRepositoryProvider).loadRecentDocuments();
  }

  Future<void> record(RecentDocument document) async {
    final repository = ref.read(preferencesRepositoryProvider);
    state = AsyncData(await repository.addRecentDocument(document));
  }
}
