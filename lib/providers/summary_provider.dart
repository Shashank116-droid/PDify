import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider to cache and persist PDF summaries locally using SharedPreferences.
/// This enables "True Offline Support" and instant opening of summaries.
class SummaryProvider extends ChangeNotifier {
  static const String _storageKey = 'cached_summaries_v2';

  // Structure: Map<pdfId, summaryDataMap>
  Map<String, Map<String, dynamic>> _cache = {};

  Map<String, Map<String, dynamic>> get cache => _cache;

  /// Loads the cached summaries from local storage.
  Future<void> loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString(_storageKey);

      if (jsonString != null) {
        final Map<String, dynamic> decoded = json.decode(jsonString);
        _cache = decoded.map(
          (key, value) => MapEntry(key, Map<String, dynamic>.from(value)),
        );
        debugPrint('SummaryProvider: loaded ${_cache.length} cached summaries');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('SummaryProvider: Error loading cache: $e');
    }
  }

  /// Retrieves a summary from the local cache. Returns null if not found.
  Map<String, dynamic>? getCachedSummary(String pdfId) {
    return _cache[pdfId];
  }

  /// Updates the local cache with new summary data and persists it.
  Future<void> updateCache(
    String pdfId,
    Map<String, dynamic> summaryData,
  ) async {
    // Sanitize first to ensure JSON-safe data
    final sanitized = _sanitizeMap(summaryData);

    // Check if the data is actually different to avoid redundant saves
    final existing = _cache[pdfId];
    if (existing != null && _areMapsEqual(existing, sanitized)) return;

    _cache[pdfId] = sanitized;
    notifyListeners();
    await _saveToStorage();
  }

  /// Removes a cached summary (e.g., when a PDF is deleted).
  Future<void> removeFromCache(String pdfId) async {
    if (_cache.containsKey(pdfId)) {
      _cache.remove(pdfId);
      notifyListeners();
      await _saveToStorage();
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String jsonString = json.encode(_cache);
      await prefs.setString(_storageKey, jsonString);
      debugPrint('SummaryProvider: saved ${_cache.length} summaries to disk');
    } catch (e) {
      debugPrint('SummaryProvider: Error saving cache: $e');
    }
  }

  /// Recursively converts all non-JSON-safe values (Timestamps, etc.) to strings.
  /// This ensures `json.encode` never fails.
  static Map<String, dynamic> _sanitizeMap(Map<String, dynamic> input) {
    final Map<String, dynamic> result = {};
    for (final entry in input.entries) {
      result[entry.key] = _sanitizeValue(entry.value);
    }
    return result;
  }

  static dynamic _sanitizeValue(dynamic value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    if (value is Map) {
      return _sanitizeMap(Map<String, dynamic>.from(value));
    }
    if (value is List) {
      return value.map(_sanitizeValue).toList();
    }
    // Catch-all for Timestamp, DateTime, and unknown types
    return value.toString();
  }

  bool _areMapsEqual(Map<String, dynamic> m1, Map<String, dynamic> m2) {
    if (m1.length != m2.length) return false;
    for (final key in m1.keys) {
      if (m1[key]?.toString() != m2[key]?.toString()) return false;
    }
    return true;
  }

  /// Returns a map of just the summary content text for all cached PDFs.
  /// Useful for deep search without loading full JSON objects.
  Map<String, String> getAllSummaryTexts() {
    final Map<String, String> texts = {};
    _cache.forEach((pdfId, data) {
      final content = data['content'] ?? '';
      texts[pdfId] = content.toString();
    });
    return texts;
  }
}
