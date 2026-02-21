import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Provider to manage search query and sort order for the PDF list.
class SearchFilterProvider extends ChangeNotifier {
  String _searchQuery = '';
  bool _sortNewestFirst = true;

  String get searchQuery => _searchQuery;
  bool get sortNewestFirst => _sortNewestFirst;

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

  /// Filters docs by fileName matching the search query,
  /// then sorts by upload date based on the current sort direction.
  List<QueryDocumentSnapshot> filterAndSort(List<QueryDocumentSnapshot> docs) {
    var filtered = docs;

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final fileName = (data['fileName'] ?? '').toString().toLowerCase();
        return fileName.contains(query);
      }).toList();
    }

    // The Firestore query already sorts newest-first.
    // If user wants oldest-first, reverse the list.
    if (!_sortNewestFirst) {
      filtered = filtered.reversed.toList();
    }

    return filtered;
  }
}
