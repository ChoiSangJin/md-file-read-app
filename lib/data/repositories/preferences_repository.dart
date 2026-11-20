import 'dart:convert';

import 'package:md_file_read_app/data/models/reader_settings.dart';
import 'package:md_file_read_app/data/models/recent_document.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesRepository {
  PreferencesRepository(this._preferences);

  static const _recentKey = 'recent_documents';
  static const _themeKey = 'reader_theme';
  static const _fontSizeKey = 'reader_font_size';
  static const _lineHeightKey = 'reader_line_height';

  final SharedPreferencesAsync _preferences;

  Future<List<RecentDocument>> loadRecentDocuments() async {
    final encoded = await _preferences.getString(_recentKey);
    if (encoded == null) return const [];
    try {
      final items = jsonDecode(encoded) as List<dynamic>;
      return items
          .map(
            (item) => RecentDocument.fromJson(
              Map<String, Object?>.from(item as Map<dynamic, dynamic>),
            ),
          )
          .toList(growable: false);
    } on FormatException {
      return const [];
    }
  }

  Future<List<RecentDocument>> addRecentDocument(
    RecentDocument document,
  ) async {
    final existing = await loadRecentDocuments();
    final updated = [
      document,
      ...existing.where((item) => item.id != document.id),
    ].take(20).toList(growable: false);
    await _preferences.setString(
      _recentKey,
      jsonEncode(updated.map((item) => item.toJson()).toList()),
    );
    return updated;
  }

  Future<double> loadScrollOffset(String documentId) async {
    return await _preferences.getDouble(_scrollKey(documentId)) ?? 0;
  }

  Future<void> saveScrollOffset(String documentId, double offset) {
    return _preferences.setDouble(_scrollKey(documentId), offset);
  }

  Future<ReaderSettings> loadReaderSettings() async {
    final themeName = await _preferences.getString(_themeKey);
    final theme = ReaderTheme.values.where((value) => value.name == themeName);
    return ReaderSettings(
      theme: theme.isEmpty ? ReaderTheme.light : theme.first,
      fontSize: await _preferences.getDouble(_fontSizeKey) ?? 17,
      lineHeight: await _preferences.getDouble(_lineHeightKey) ?? 1.6,
    );
  }

  Future<void> saveReaderSettings(ReaderSettings settings) async {
    await Future.wait([
      _preferences.setString(_themeKey, settings.theme.name),
      _preferences.setDouble(_fontSizeKey, settings.fontSize),
      _preferences.setDouble(_lineHeightKey, settings.lineHeight),
    ]);
  }

  String _scrollKey(String documentId) {
    final safeId = base64Url.encode(utf8.encode(documentId));
    return 'scroll_$safeId';
  }
}
