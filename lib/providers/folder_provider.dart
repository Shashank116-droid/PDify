import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider to manage PDF-to-folder assignments.
/// Persists folder data via SharedPreferences.
class FolderProvider extends ChangeNotifier {
  static const String _assignmentsKey = 'folder_assignments';
  static const String _foldersKey = 'folder_names';

  // pdfId → folderName
  Map<String, String> _assignments = {};
  // All folder names the user has created
  List<String> _folderNames = [];

  Map<String, String> get assignments => _assignments;
  List<String> get folderNames => _folderNames;

  /// Get the folder name for a specific PDF.
  String? getFolder(String pdfId) => _assignments[pdfId];

  /// Get all PDF IDs assigned to a specific folder.
  Set<String> getPdfsInFolder(String folderName) {
    return _assignments.entries
        .where((e) => e.value == folderName)
        .map((e) => e.key)
        .toSet();
  }

  /// Load saved data from disk.
  Future<void> loadFolders() async {
    final prefs = await SharedPreferences.getInstance();

    // Load folder names
    _folderNames = prefs.getStringList(_foldersKey) ?? [];

    // Load assignments (stored as "pdfId:folderName" pairs)
    final saved = prefs.getStringList(_assignmentsKey) ?? [];
    _assignments = {};
    for (final entry in saved) {
      final parts = entry.split('::');
      if (parts.length == 2) {
        _assignments[parts[0]] = parts[1];
      }
    }
    notifyListeners();
  }

  /// Create a new folder.
  Future<void> createFolder(String name) async {
    if (name.isEmpty || _folderNames.contains(name)) return;
    _folderNames.add(name);
    notifyListeners();
    await _saveFolderNames();
  }

  /// Delete a folder and unassign all PDFs from it.
  Future<void> deleteFolder(String name) async {
    _folderNames.remove(name);
    _assignments.removeWhere((_, folder) => folder == name);
    notifyListeners();
    await _saveFolderNames();
    await _saveAssignments();
  }

  /// Assign a PDF to a folder.
  Future<void> assignFolder(String pdfId, String folderName) async {
    _assignments[pdfId] = folderName;
    // Auto-create folder if it doesn't exist
    if (!_folderNames.contains(folderName)) {
      _folderNames.add(folderName);
      await _saveFolderNames();
    }
    notifyListeners();
    await _saveAssignments();
  }

  /// Remove a PDF from its folder.
  Future<void> removeFromFolder(String pdfId) async {
    _assignments.remove(pdfId);
    notifyListeners();
    await _saveAssignments();
  }

  Future<void> _saveFolderNames() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_foldersKey, _folderNames);
  }

  Future<void> _saveAssignments() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = _assignments.entries
        .map((e) => '${e.key}::${e.value}')
        .toList();
    await prefs.setStringList(_assignmentsKey, encoded);
  }
}
