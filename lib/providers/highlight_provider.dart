import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdify/models/highlight_model.dart';

/// Manages highlights per PDF document, persisted via SharedPreferences.
class HighlightProvider extends ChangeNotifier {
  static const String _storageKey = 'pdf_highlights_v1';

  // Structure: Map<pdfId, List<Highlight>>
  Map<String, List<Highlight>> _highlights = {};

  Map<String, List<Highlight>> get allHighlights => _highlights;

  /// Load all highlights from local storage.
  Future<void> loadHighlights() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString(_storageKey);
      if (jsonString != null) {
        final Map<String, dynamic> decoded = json.decode(jsonString);
        _highlights = decoded.map((pdfId, list) => MapEntry(
              pdfId,
              (list as List)
                  .map((e) => Highlight.fromJson(Map<String, dynamic>.from(e)))
                  .toList(),
            ));
        debugPrint('HighlightProvider: loaded highlights for ${_highlights.length} PDFs');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('HighlightProvider: Error loading highlights: $e');
    }
  }

  /// Get highlights for a specific PDF.
  List<Highlight> getHighlightsForPdf(String pdfId) {
    return _highlights[pdfId] ?? [];
  }

  /// Get highlights for a specific PDF page.
  List<Highlight> getHighlightsForPage(String pdfId, int pageNumber) {
    return getHighlightsForPdf(pdfId)
        .where((h) => h.pageNumber == pageNumber)
        .toList();
  }

  /// Add a new highlight for a PDF.
  Future<void> addHighlight(String pdfId, Highlight highlight) async {
    _highlights.putIfAbsent(pdfId, () => []);
    _highlights[pdfId]!.add(highlight);
    notifyListeners();
    await _save();
  }

  /// Remove a specific highlight.
  Future<void> removeHighlight(String pdfId, int index) async {
    if (_highlights.containsKey(pdfId) && index < _highlights[pdfId]!.length) {
      _highlights[pdfId]!.removeAt(index);
      if (_highlights[pdfId]!.isEmpty) {
        _highlights.remove(pdfId);
      }
      notifyListeners();
      await _save();
    }
  }

  /// Clear all highlights for a PDF.
  Future<void> clearHighlightsForPdf(String pdfId) async {
    _highlights.remove(pdfId);
    notifyListeners();
    await _save();
  }

  /// Get total highlight count for a PDF.
  int getHighlightCount(String pdfId) {
    return _highlights[pdfId]?.length ?? 0;
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = _highlights.map(
        (pdfId, list) => MapEntry(pdfId, list.map((h) => h.toJson()).toList()),
      );
      await prefs.setString(_storageKey, json.encode(encoded));
    } catch (e) {
      debugPrint('HighlightProvider: Error saving highlights: $e');
    }
  }
}
