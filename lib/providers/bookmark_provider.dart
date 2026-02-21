import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider to manage bookmarked PDF IDs.
/// Persists bookmarks via SharedPreferences.
class BookmarkProvider extends ChangeNotifier {
  static const String _key = 'bookmarked_pdfs';

  Set<String> _bookmarkedIds = {};

  Set<String> get bookmarkedIds => _bookmarkedIds;

  bool isBookmarked(String pdfId) => _bookmarkedIds.contains(pdfId);

  /// Load saved bookmarks from disk.
  Future<void> loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_key);
    if (saved != null) {
      _bookmarkedIds = saved.toSet();
    }
    notifyListeners();
  }

  /// Toggle bookmark status for a PDF.
  Future<void> toggleBookmark(String pdfId) async {
    if (_bookmarkedIds.contains(pdfId)) {
      _bookmarkedIds.remove(pdfId);
    } else {
      _bookmarkedIds.add(pdfId);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _bookmarkedIds.toList());
  }
}
