import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:pdify/ad_service.dart';
import 'package:pdify/providers/search_filter_provider.dart';
import 'package:pdify/providers/bookmark_provider.dart';
import 'package:pdify/chat_screen.dart';
import 'package:pdify/providers/folder_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdify/widgets/glass_card.dart';
import 'package:pdify/widgets/primary_button.dart';
import 'package:pdify/widgets/mesh_background_scaffold.dart';
import 'package:pdify/services/export_service.dart';
import 'package:in_app_update/in_app_update.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  final TextEditingController _searchController = TextEditingController();
  bool _isUploading = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _checkForUpdate();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkForUpdate() async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        if (info.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
        } else if (info.flexibleUpdateAllowed) {
          await InAppUpdate.startFlexibleUpdate();
          await InAppUpdate.completeFlexibleUpdate();
        }
      }
    } catch (e) {
      // Update check failed (expected in debug/local builds)
      debugPrint("Update check failed: $e");
    }
  }

  Future<void> _uploadPdf() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      String filePath = result.files.single.path!;
      String fileName = result.files.single.name;
      File file = File(filePath);

      // Check size (10MB limit)
      int sizeInBytes = await file.length();
      if (sizeInBytes > 10 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("File size must be less than 10MB")),
          );
        }
        return;
      }

      setState(() {
        _isUploading = true;
      });

      try {
        // Upload to Storage
        String storagePath = 'users/${user!.uid}/$fileName';
        Reference ref = FirebaseStorage.instance.ref().child(storagePath);
        await ref.putFile(file);

        // Get Download URL
        String downloadUrl = await ref.getDownloadURL();

        // Create Firestore Document
        await FirebaseFirestore.instance.collection('pdfs').add({
          'userId': user!.uid,
          'fileUrl': downloadUrl,
          'storagePath': storagePath,
          'status': 'processing',
          'uploadedAt': FieldValue.serverTimestamp(),
          'fileName': fileName,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Upload successful! Processing...")),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Upload failed: $e")));
        }
      } finally {
        if (mounted) {
          setState(() {
            _isUploading = false;
          });
        }
      }
    }
  }

  Future<void> _deleteAllPdfs() async {
    final userId = user?.uid;
    if (userId == null) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All PDFs'),
        content: const Text(
          'Are you sure you want to delete all your PDFs and their summaries? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);

    try {
      // 1. Get all PDF docs for this user
      final pdfSnapshot = await FirebaseFirestore.instance
          .collection('pdfs')
          .where('userId', isEqualTo: userId)
          .get();

      final batch = FirebaseFirestore.instance.batch();

      for (final pdfDoc in pdfSnapshot.docs) {
        final data = pdfDoc.data();
        final storagePath = data['storagePath'] as String?;

        // 2. Delete file from Firebase Storage
        if (storagePath != null && storagePath.isNotEmpty) {
          try {
            await FirebaseStorage.instance.ref().child(storagePath).delete();
          } catch (_) {
            // File might already be deleted, continue
          }
        }

        // 3. Delete associated summaries
        final summarySnapshot = await FirebaseFirestore.instance
            .collection('summaries')
            .where('pdfId', isEqualTo: pdfDoc.id)
            .get();
        for (final summaryDoc in summarySnapshot.docs) {
          batch.delete(summaryDoc.reference);
        }

        // 4. Delete the PDF document itself
        batch.delete(pdfDoc.reference);
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All PDFs deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting PDFs: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Gradient Mesh  // Design Tokens
    // static const color1 = Color(0xFF7C3AED); // Vivid Purple
    // static const color2 = Color(0xFFFF6B6B); // Coral Red
    // static const color3 = Color(0xFF00D9FF); // Cyan
    // static const color4 = Color(0xFFFFD166); // Warm Yellow

    return MeshBackgroundScaffold(
      title: 'PDify',
      actions: [
        IconButton(
          icon: _isDeleting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF7C3AED),
                  ),
                )
              : const Icon(Icons.delete_sweep_rounded),
          tooltip: 'Delete All',
          onPressed: _isDeleting ? null : _deleteAllPdfs,
        ),
      ],
      body: Stack(
        children: [
          Column(
            children: [
              _buildUploadSection(theme),
              _buildSearchBar(theme),
              _buildFolderChips(theme),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('pdfs')
                      .where(
                        'userId',
                        isEqualTo: FirebaseAuth.instance.currentUser?.uid,
                      )
                      .orderBy('uploadedAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: SelectableText(
                            "Error: ${snapshot.error}",
                            style: TextStyle(color: theme.colorScheme.error),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.description_outlined,
                              size: 64,
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.3,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "No PDFs uploaded yet",
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.textTheme.bodyMedium?.color
                                    ?.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Upload a PDF to get started",
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.textTheme.bodyMedium?.color
                                    ?.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final provider = context.watch<SearchFilterProvider>();
                    final bookmarkProvider = context.watch<BookmarkProvider>();
                    final folderProvider = context.watch<FolderProvider>();

                    // Build summary content map for deep search
                    final Map<String, String> summaryContents = {};
                    // We will populate this lazily from the summary stream

                    final filteredDocs = provider.filterAndSort(
                      snapshot.data!.docs,
                      bookmarkProvider.bookmarkedIds,
                      folderAssignments: folderProvider.assignments,
                      summaryContents: summaryContents,
                    );

                    if (filteredDocs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 64,
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.3,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "No results found",
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.textTheme.bodyMedium?.color
                                    ?.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Try a different search term",
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.textTheme.bodyMedium?.color
                                    ?.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return RefreshIndicator(
                      color: const Color(0xFF7C3AED),
                      onRefresh: () async {
                        await Future.delayed(const Duration(milliseconds: 500));
                      },
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 140),
                        itemCount: filteredDocs.length,
                        itemBuilder: (context, index) {
                          var doc = filteredDocs[index];
                          var data = doc.data() as Map<String, dynamic>;
                          return _buildPdfItem(doc.id, data, theme);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: BannerAdWidget(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    final provider = context.watch<SearchFilterProvider>();
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E293B).withValues(alpha: 0.7)
              : Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: provider.updateSearch,
                style: theme.textTheme.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'Search PDFs...',
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withValues(
                      alpha: 0.4,
                    ),
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: theme.colorScheme.primary.withValues(alpha: 0.6),
                    size: 20,
                  ),
                  suffixIcon: provider.searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: theme.textTheme.bodyMedium?.color
                                ?.withValues(alpha: 0.5),
                          ),
                          onPressed: () {
                            _searchController.clear();
                            provider.clearSearch();
                            FocusScope.of(context).unfocus();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
            Container(
              height: 32,
              width: 1,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.2),
            ),
            IconButton(
              icon: Icon(
                provider.filterOnlyBookmarked
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_outline_rounded,
                size: 20,
                color: provider.filterOnlyBookmarked
                    ? const Color(0xFFFFD166)
                    : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.4),
              ),
              onPressed: provider.toggleBookmarkFilter,
              tooltip: 'Show Bookmarked Only',
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderChips(ThemeData theme) {
    final provider = context.watch<SearchFilterProvider>();
    final folderProvider = context.watch<FolderProvider>();
    final isDark = theme.brightness == Brightness.dark;

    if (folderProvider.folderNames.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            // "All" chip
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: const Text('All'),
                selected: provider.selectedFolder == null,
                onSelected: (_) => provider.selectFolder(null),
                selectedColor: const Color(0xFF7C3AED),
                labelStyle: TextStyle(
                  color: provider.selectedFolder == null
                      ? Colors.white
                      : (isDark ? Colors.white70 : Colors.black87),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
                side: BorderSide.none,
                visualDensity: VisualDensity.compact,
              ),
            ),
            // Folder chips
            ...folderProvider.folderNames.map((name) {
              final isSelected = provider.selectedFolder == name;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onLongPress: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Folder'),
                        content: Text(
                          'Delete folder "$name"? PDFs will be unassigned.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              folderProvider.deleteFolder(name);
                              if (provider.selectedFolder == name) {
                                provider.selectFolder(null);
                              }
                              Navigator.pop(ctx);
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: ChoiceChip(
                    avatar: Icon(
                      Icons.folder_rounded,
                      size: 14,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF7C3AED),
                    ),
                    label: Text(name),
                    selected: isSelected,
                    onSelected: (_) =>
                        provider.selectFolder(isSelected ? null : name),
                    selectedColor: const Color(0xFF7C3AED),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.black87),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.05),
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _showFolderPicker(
    String docId,
    FolderProvider folderProvider,
    ThemeData theme,
  ) async {
    final currentFolder = folderProvider.getFolder(docId);
    final newFolderController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.folder_rounded, color: Color(0xFF7C3AED)),
                  const SizedBox(width: 8),
                  Text(
                    'Move to Folder',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Existing folders
              if (folderProvider.folderNames.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // Remove from folder option
                    if (currentFolder != null)
                      ActionChip(
                        avatar: const Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: Colors.redAccent,
                        ),
                        label: const Text('Remove'),
                        onPressed: () {
                          folderProvider.removeFromFolder(docId);
                          Navigator.pop(ctx);
                        },
                      ),
                    ...folderProvider.folderNames.map((name) {
                      final isActive = currentFolder == name;
                      return ChoiceChip(
                        label: Text(name),
                        selected: isActive,
                        selectedColor: const Color(0xFF7C3AED),
                        labelStyle: TextStyle(
                          color: isActive ? Colors.white : null,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (_) {
                          folderProvider.assignFolder(docId, name);
                          Navigator.pop(ctx);
                        },
                      );
                    }),
                  ],
                ),
              const SizedBox(height: 16),
              // Create new folder
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: newFolderController,
                      style: theme.textTheme.bodyMedium,
                      decoration: InputDecoration(
                        hintText: 'New folder name...',
                        hintStyle: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodyMedium?.color?.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: const Color(
                              0xFF7C3AED,
                            ).withValues(alpha: 0.3),
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (value) {
                        if (value.trim().isNotEmpty) {
                          folderProvider.assignFolder(docId, value.trim());
                          Navigator.pop(ctx);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      final name = newFolderController.text.trim();
                      if (name.isNotEmpty) {
                        folderProvider.assignFolder(docId, name);
                        Navigator.pop(ctx);
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Add',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadSection(ThemeData theme) {
    return GlassCard(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      borderRadius: 24,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_upload_rounded,
              size: 32,
              color: Color(0xFF7C3AED),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Upload your notes",
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "PDFs up to 10MB • AI-powered summaries",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _isUploading
              ? Column(
                  children: [
                    const SizedBox(height: 10),
                    const CircularProgressIndicator(color: Color(0xFF7C3AED)),
                    const SizedBox(height: 10),
                    const Text(
                      "Uploading...",
                      style: TextStyle(
                        color: Color(0xFF7C3AED),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              : PrimaryButton(
                  text: "Choose PDF",
                  onPressed: _uploadPdf,
                  icon: Icons.add_rounded,
                  backgroundColor: const Color(0xFF7C3AED),
                  width: double.infinity,
                  height: 56,
                ),
        ],
      ),
    );
  }

  Future<void> _deleteSinglePdf(String docId, String? storagePath) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete PDF'),
        content: const Text(
          'Delete this PDF and its summaries? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      // Delete from Storage
      if (storagePath != null && storagePath.isNotEmpty) {
        try {
          await FirebaseStorage.instance.ref().child(storagePath).delete();
        } catch (_) {}
      }

      // Delete associated summaries
      final summarySnapshot = await FirebaseFirestore.instance
          .collection('summaries')
          .where('pdfId', isEqualTo: docId)
          .get();
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in summarySnapshot.docs) {
        batch.delete(doc.reference);
      }
      // Delete the PDF document
      batch.delete(FirebaseFirestore.instance.collection('pdfs').doc(docId));
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting PDF: $e')));
      }
    }
  }

  Future<void> _renamePdf(String docId, String currentName) async {
    final controller = TextEditingController(text: currentName);
    final theme = Theme.of(context);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename PDF'),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: theme.textTheme.bodyLarge?.color),
          decoration: const InputDecoration(hintText: 'Enter new name'),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty || newName == currentName) return;

    try {
      await FirebaseFirestore.instance.collection('pdfs').doc(docId).update({
        'fileName': newName,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF renamed successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Rename failed: $e')));
      }
    }
  }

  Future<void> _retryPdf(String docId, Map<String, dynamic> data) async {
    try {
      // Delete any partial summaries
      final summaries = await FirebaseFirestore.instance
          .collection('summaries')
          .where('pdfId', isEqualTo: docId)
          .get();
      for (final doc in summaries.docs) {
        await doc.reference.delete();
      }

      // Delete the failed doc
      await FirebaseFirestore.instance.collection('pdfs').doc(docId).delete();

      // Re-create to trigger onDocumentCreated
      await FirebaseFirestore.instance.collection('pdfs').add({
        'userId': data['userId'],
        'fileUrl': data['fileUrl'],
        'storagePath': data['storagePath'],
        'fileName': data['fileName'],
        'status': 'processing',
        'uploadedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Retrying summary generation...')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Retry failed: $e')));
      }
    }
  }

  Widget _buildPdfItem(
    String docId,
    Map<String, dynamic> data,
    ThemeData theme,
  ) {
    String status = data['status'] ?? 'unknown';
    String fileName = data['fileName'] ?? 'Unknown File';
    final bookmarkProvider = context.watch<BookmarkProvider>();
    final isBookmarked = bookmarkProvider.isBookmarked(docId);
    final folderProvider = context.watch<FolderProvider>();
    final assignedFolder = folderProvider.getFolder(docId);

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 16),
      borderRadius: 20,
      padding: EdgeInsets.zero,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          title: Row(
            children: [
              GestureDetector(
                onTap: () => _renamePdf(docId, fileName),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(
                    Icons.edit_rounded,
                    size: 16,
                    color: theme.colorScheme.primary.withValues(alpha: 0.7),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  fileName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                _buildStatusChip(status, theme),
                if (assignedFolder != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.folder_rounded,
                          size: 12,
                          color: Color(0xFF7C3AED),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          assignedFolder,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF7C3AED),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          leading: _buildStatusIcon(status, theme),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.expand_more_rounded,
                color: theme.textTheme.bodyMedium?.color?.withValues(
                  alpha: 0.5,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.folder_open_rounded,
                  color: assignedFolder != null
                      ? const Color(0xFF7C3AED)
                      : theme.textTheme.bodyMedium?.color?.withValues(
                          alpha: 0.4,
                        ),
                  size: 22,
                ),
                tooltip: 'Move to folder',
                onPressed: () =>
                    _showFolderPicker(docId, folderProvider, theme),
              ),
              IconButton(
                icon: Icon(
                  isBookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: isBookmarked
                      ? const Color(0xFFFFD166)
                      : theme.textTheme.bodyMedium?.color?.withValues(
                          alpha: 0.4,
                        ),
                  size: 22,
                ),
                tooltip: isBookmarked ? 'Remove bookmark' : 'Bookmark',
                onPressed: () => bookmarkProvider.toggleBookmark(docId),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.redAccent,
                  size: 22,
                ),
                tooltip: 'Delete',
                onPressed: () =>
                    _deleteSinglePdf(docId, data['storagePath'] as String?),
              ),
            ],
          ),
          children: [
            if (status == 'completed')
              _RewardedSummaryGate(pdfId: docId)
            else if (status == 'processing')
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF7C3AED),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        "Summarizing...",
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodyMedium?.color,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: theme.colorScheme.error),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        "Summary failed",
                        style: TextStyle(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _retryPdf(docId, data),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text("Retry"),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(String status, ThemeData theme) {
    switch (status) {
      case 'completed':
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(
              0xFF10B981,
            ).withValues(alpha: 0.1), // Emerald Green
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_rounded,
            color: Color(0xFF10B981),
            size: 20,
          ),
        );
      case 'processing':
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF7C3AED),
            ),
          ),
        );
      default:
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withValues(alpha: 0.1), // Red
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.priority_high_rounded,
            color: Color(0xFFEF4444),
            size: 20,
          ),
        );
    }
  }

  Widget _buildStatusChip(String status, ThemeData theme) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case 'completed':
        bgColor = const Color(0xFF10B981).withValues(alpha: 0.1);
        textColor = const Color(0xFF047857);
        label = 'Ready';
        break;
      case 'processing':
        bgColor = const Color(0xFF7C3AED).withValues(alpha: 0.1);
        textColor = const Color(0xFF7C3AED);
        label = 'Processing';
        break;
      default:
        bgColor = const Color(0xFFEF4444).withValues(alpha: 0.1);
        textColor = const Color(0xFFB91C1C);
        label = 'Error';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20), // Pill shape
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class SummaryView extends StatelessWidget {
  final String pdfId;

  const SummaryView({super.key, required this.pdfId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('summaries')
          .where('pdfId', isEqualTo: pdfId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
            ),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              "Could not load summaries",
              style: TextStyle(color: theme.colorScheme.error),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                "Summaries appearing soon...",
                style: TextStyle(color: Colors.white70),
              ),
            ),
          );
        }

        // Categorize summaries
        Map<String, dynamic>? fullSummary;
        Map<String, dynamic>? examSummary;
        Map<String, dynamic>? chapterSummary;

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final type = data['type'] ?? 'full';

          if (type == 'full') {
            fullSummary = data;
          } else if (type == 'exam') {
            examSummary = data;
          } else if (type == 'chapters') {
            chapterSummary = data;
          }
        }

        final List<Widget> tabs = [const Tab(text: "Summary")];
        final List<Widget> views = [
          _buildSummaryContent(
            fullSummary?['content'] ?? "Generating...",
            theme,
            context,
            pdfId,
            "Document", // We don't have fileName in SummaryView easily without another fetch, so default
          ),
        ];

        tabs.add(const Tab(text: "Exam Mode"));
        views.add(
          _buildSummaryContent(
            examSummary?['content'] ??
                "Exam summary is not available for this document.\n\nTry uploading the PDF again if this persists.",
            theme,
            context,
            pdfId,
            "Document", // Default fileName
            isExam: true,
            questions: (examSummary?['questions'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>(),
          ),
        );

        if (chapterSummary != null) {
          tabs.add(const Tab(text: "Chapters"));
          views.add(_buildChapterContent(chapterSummary['chapters'], theme));
        }

        return Container(
          // Inner container for summaries inside the ExpansionTile
          // No shadow needed here as it's inside the card
          decoration: BoxDecoration(
            color: Colors.black.withValues(
              alpha: 0.2,
            ), // Dark translucent background
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: _TabContentHelper(tabs: tabs, views: views, theme: theme),
        );
      },
    );
  }

  Widget _buildSummaryContent(
    String content,
    ThemeData theme,
    BuildContext context,
    String pdfId,
    String fileName, {
    bool isExam = false,
    List<Map<String, dynamic>>? questions,
  }) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isExam ? Icons.school_rounded : Icons.auto_awesome_rounded,
                size: 20,
                color: const Color(0xFF7C3AED),
              ),
              const SizedBox(width: 8),
              Text(
                isExam ? "Exam Prep" : "AI Summary",
                style: const TextStyle(
                  color: Color(0xFF7C3AED),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.picture_as_pdf_rounded,
                  size: 20,
                  color: Color(0xFF7C3AED),
                ),
                onPressed: () {
                  ExportService.exportSummaryToPdf(
                    context: context,
                    fileName: fileName,
                    summaryContent: content,
                    summaryType: isExam ? 'Exam Prep' : 'AI Summary',
                  );
                },
                tooltip: 'Export as PDF',
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.share_rounded,
                  size: 20,
                  color: Color(0xFF7C3AED),
                ),
                onPressed: () async {
                  final String subject = isExam
                      ? "Exam Prep Summary"
                      : "AI Summary";
                  final String shareText =
                      "$subject:\n\n$content\n\nGenerated by Pdify 📄";

                  // Use file sharing for long content to avoid truncation
                  try {
                    final dir = await Directory.systemTemp.createTemp(
                      'pdify_share',
                    );
                    final file = File('${dir.path}/summary.txt');
                    await file.writeAsString(shareText);
                    await SharePlus.instance.share(
                      ShareParams(
                        files: [XFile(file.path)],
                        title: subject,
                        text: 'Summary generated by Pdify 📄',
                      ),
                    );
                  } catch (_) {
                    // Fallback to plain text share
                    SharePlus.instance.share(
                      ShareParams(text: shareText, title: subject),
                    );
                  }
                },
                tooltip: 'Share Summary',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildFormattedText(content, theme),
          // Interactive Q&A section for Exam Mode
          if (isExam && questions != null && questions.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Divider(color: Colors.white24),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.quiz_rounded,
                  size: 20,
                  color: Color(0xFF7C3AED),
                ),
                const SizedBox(width: 8),
                Text(
                  "Practice Questions (${questions.length})",
                  style: const TextStyle(
                    color: Color(0xFF7C3AED),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...questions.asMap().entries.map((entry) {
              final index = entry.key;
              final qa = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: const Color(
                      0xFF7C3AED,
                    ).withValues(alpha: 0.2),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Color(0xFF7C3AED),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  title: Text(
                    qa['question'] ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  iconColor: const Color(0xFF7C3AED),
                  collapsedIconColor: Colors.white54,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        qa['answer'] ?? 'No answer available.',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ChatScreen(pdfId: pdfId, fileName: fileName),
                  ),
                );
              },
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
              label: const Text(
                'Chat with AI about this PDF',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChapterContent(List<dynamic> chapters, ThemeData theme) {
    chapters.sort((a, b) => (a['order'] ?? 0).compareTo(b['order'] ?? 0));

    return Column(
      children: chapters.map<Widget>((chapter) {
        return ExpansionTile(
          title: Text(
            chapter['title'] ?? "Chapter",
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: Colors.white,
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          iconColor: const Color(0xFF7C3AED),
          collapsedIconColor: Colors.white70,
          shape: const Border(), // Remove borders
          children: [_buildFormattedText(chapter['summary'] ?? "", theme)],
        );
      }).toList(),
    );
  }

  Widget _buildFormattedText(String text, ThemeData theme) {
    return MarkdownBody(
      data: text,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: const TextStyle(fontSize: 15, color: Colors.white70, height: 1.6),
        strong: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        h1: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: Color(0xFF7C3AED),
        ),
        h2: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Color(0xFF7C3AED),
        ),
        h3: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Color(0xFF7C3AED),
        ),
        listBullet: const TextStyle(color: Color(0xFF7C3AED)),
      ),
    );
  }
}

class _TabContentHelper extends StatefulWidget {
  final List<Widget> tabs;
  final List<Widget> views;
  final ThemeData theme;

  const _TabContentHelper({
    required this.tabs,
    required this.views,
    required this.theme,
  });

  @override
  State<_TabContentHelper> createState() => _TabContentHelperState();
}

class _TabContentHelperState extends State<_TabContentHelper>
    with TickerProviderStateMixin {
  late TabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: widget.tabs.length, vsync: this);
  }

  @override
  void didUpdateWidget(_TabContentHelper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tabs.length != oldWidget.tabs.length) {
      _controller.dispose();
      _controller = TabController(length: widget.tabs.length, vsync: this);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tabs.length <= 1) return widget.views.first;

    return Column(
      children: [
        TabBar(
          controller: _controller,
          tabs: widget.tabs,
          labelColor: const Color(0xFFA78BFA), // Lighter purple for dark theme
          unselectedLabelColor: Colors.white54,
          indicatorColor: const Color(0xFFA78BFA),
          indicatorSize: TabBarIndicatorSize.label,
          dividerColor: Colors.transparent,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          onTap: (index) {
            setState(() {});
          },
        ),
        Divider(height: 1, color: Colors.white.withValues(alpha: 0.1)),
        widget.views[_controller.index],
      ],
    );
  }
}

/// Gate widget that requires watching a rewarded ad before showing summary
class _RewardedSummaryGate extends StatefulWidget {
  final String pdfId;

  const _RewardedSummaryGate({required this.pdfId});

  @override
  State<_RewardedSummaryGate> createState() => _RewardedSummaryGateState();
}

class _RewardedSummaryGateState extends State<_RewardedSummaryGate> {
  bool _isUnlocked = false;
  bool _isLoading = false;

  Future<void> _watchAdToUnlock() async {
    setState(() => _isLoading = true);

    final adShown = await AdService().showRewardedAd(
      onRewarded: () {
        if (mounted) {
          setState(() {
            _isUnlocked = true;
            _isLoading = false;
          });
        }
      },
    );

    if (!adShown && mounted) {
      // Ad not ready, show message
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ad not ready. Please try again in a moment.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isUnlocked) {
      return SummaryView(pdfId: widget.pdfId);
    }

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.play_circle_outline_rounded,
                  size: 48,
                  color: Color(0xFF7C3AED),
                ),
                const SizedBox(height: 16),
                Text(
                  'Watch a short ad to view this summary',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isLoading ? null : _watchAdToUnlock,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      _isLoading ? 'Loading Ad...' : 'Watch Ad & Unlock',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
