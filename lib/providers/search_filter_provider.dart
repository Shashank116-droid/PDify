import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Provider to manage search query, sort order, and folder filter for the PDF list.
class SearchFilterProvider extends ChangeNotifier {
  String _searchQuery = '';
  bool _sortNewestFirst = true;
  bool _filterOnlyBookmarked = false;
  String? _selectedFolder;

  String get searchQuery => _searchQuery;
  bool get sortNewestFirst => _sortNewestFirst;
  bool get filterOnlyBookmarked => _filterOnlyBookmarked;
  String? get selectedFolder => _selectedFolder;

  void updateSearch(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    notifyListeners();
  }

  void toggleSort() {
    _sortNewestFirst = !_sortNewestFirst;
    notifyListeners();
  }

  void toggleBookmarkFilter() {
    _filterOnlyBookmarked = !_filterOnlyBookmarked;
    notifyListeners();
  }

  void selectFolder(String? folderName) {
    _selectedFolder = folderName;
    notifyListeners();
  }

  /// Filters docs by fileName and summary content matching the search query,
  /// then applies bookmark and folder filters,
  /// then sorts by upload date based on the current sort direction.
  List<QueryDocumentSnapshot> filterAndSort(
    List<QueryDocumentSnapshot> docs,
    Set<String> bookmarkedIds, {
    Map<String, String> folderAssignments = const {},
    Map<String, String> summaryContents = const {},
  }) {
    var filtered = docs;

    // Filter by search query (filename + summary content)
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final fileName = (data['fileName'] ?? '').toString().toLowerCase();
        final summaryText = (summaryContents[doc.id] ?? '').toLowerCase();
        return fileName.contains(query) || summaryText.contains(query);
      }).toList();
    }

    // Filter by bookmarks
    if (_filterOnlyBookmarked) {
      filtered = filtered
          .where((doc) => bookmarkedIds.contains(doc.id))
          .toList();
    }

    // Filter by folder
    if (_selectedFolder != null) {
      filtered = filtered
          .where((doc) => folderAssignments[doc.id] == _selectedFolder)
          .toList();
    }

    // The Firestore query already sorts newest-first.
    // If user wants oldest-first, reverse the list.
    if (!_sortNewestFirst) {
      filtered = filtered.reversed.toList();
    }

    return filtered;
  }
}
