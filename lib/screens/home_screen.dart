import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:pdify/providers/chat_provider.dart';
import 'package:pdify/providers/navigation_provider.dart';
import 'package:pdify/widgets/app_drawer.dart';
import 'package:provider/provider.dart';
import 'package:pdify/services/ad_service.dart';
import 'package:pdify/providers/search_filter_provider.dart';
import 'package:pdify/providers/bookmark_provider.dart';
import 'package:pdify/screens/ai_chat_screen.dart';
import 'package:pdify/providers/folder_provider.dart';
import 'package:pdify/providers/summary_provider.dart';
import 'package:pdify/screens/document_insights_screen.dart';
import 'package:pdify/widgets/premium_header.dart';
import 'package:pdify/screens/profile_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdify/widgets/glass_card.dart';
import 'package:pdify/widgets/primary_button.dart';
import 'package:pdify/widgets/mesh_background_scaffold.dart';
import 'package:pdify/services/export_service.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:pdfx/pdfx.dart';
import 'package:pdify/repositories/pdf_repository.dart';
import 'package:pdify/repositories/summary_repository.dart';
import 'package:pdify/widgets/upload_card.dart';
import 'package:pdify/screens/pdf_highlight_viewer_screen.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class HomeScreen extends StatefulWidget {
  final bool isDocumentsOnly;
  const HomeScreen({super.key, this.isDocumentsOnly = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final User? user = FirebaseAuth.instance.currentUser;
  final TextEditingController _searchController = TextEditingController();
  bool _isUploading = false;
  bool _isDeleting = false;
  bool _isGenerating = false;
  String _statusMessage = "";

  final PdfRepository _pdfRepo = PdfRepository();
  final SummaryRepository _summaryRepo = SummaryRepository();

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  // ── Color palette matching Dashboard theme ──
  static const _deepBg = Color(0xFF0B1120);
  static const _cardBg = Color(0xFF131B2E);
  static const _accentBlue = Color(0xFF3B82F6);
  static const _accentCyan = Color(0xFF00D9FF);
  static const _emerald = Color(0xFF10B981);
  static const _amber = Color(0xFFFBBF24);
  static const _slate = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _checkForUpdate();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animController.dispose();
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
      debugPrint("Update check failed: $e");
    }
  }

  Future<void> _pickAndUploadPdf() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      String filePath = result.files.single.path!;
      String fileName = result.files.single.name;
      File file = File(filePath);

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
        _statusMessage = "Uploading PDF...";
      });

      StreamSubscription? summarySubscription;

      try {
        final pdfDoc = await PdfDocument.openFile(filePath);
        final pageCount = pdfDoc.pagesCount;
        await pdfDoc.close();

        final docRef = await _pdfRepo.uploadPdf(
          file: file,
          userId: user!.uid,
          fileName: fileName,
          pageCount: pageCount,
        );

        final pdfId = docRef.id;

        if (mounted) {
          setState(() {
            _isUploading = false;
            _isGenerating = true;
            _statusMessage = "Generating Summary...";
          });
        }

        // Listen for the summary to be generated
        summarySubscription = _summaryRepo
            .getSummariesStreamByPdfId(pdfId)
            .listen((snapshot) {
              if (snapshot.docs.isNotEmpty && mounted) {
                setState(() {
                  _isGenerating = false;
                  _statusMessage = "";
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Summary generated successfully!"),
                  ),
                );
                summarySubscription?.cancel();
              }
            });
      } catch (e) {
        if (mounted) {
          setState(() {
            _isUploading = false;
            _isGenerating = false;
            _statusMessage = "";
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Upload failed: $e")));
        }
        summarySubscription?.cancel();
      }
    }
  }

  Future<void> _deleteAllPdfs() async {
    final userId = user?.uid;
    if (userId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All PDFs?'),
        content: const Text(
          'This will permanently delete all your uploaded PDFs and their AI insights.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);

    try {
      final pdfSnapshot = await _pdfRepo.getUserPdfsFuture(userId);

      final batch = FirebaseFirestore.instance.batch();

      for (final pdfDoc in pdfSnapshot.docs) {
        final data = pdfDoc.data() as Map<String, dynamic>?;
        final storagePath = data?['storagePath'] as String?;
        if (storagePath != null && storagePath.isNotEmpty) {
          try {
            await FirebaseStorage.instance.ref().child(storagePath).delete();
          } catch (_) {}
        }

        final summarySnapshot = await _summaryRepo.getSummariesFutureByPdfId(pdfDoc.id);
        for (final summaryDoc in summarySnapshot.docs) {
          batch.delete(summaryDoc.reference);
        }
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
      if (mounted) setState(() => _isDeleting = false);
    }
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
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _summaryRepo.deleteSummariesForPdf(docId);
      await _pdfRepo.deletePdf(docId, storagePath);

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
      await _pdfRepo.renamePdf(docId, newName);
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

  Future<void> _openHighlightViewer(String docId, String fileName, String? fileUrl) async {
    if (fileUrl == null || fileUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File URL not available')),
      );
      return;
    }

    try {
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Opening PDF for study...'), duration: Duration(seconds: 1)),
      );

      // Download to temp directory
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$docId.pdf';
      final file = File(filePath);

      if (!await file.exists()) {
        final response = await http.get(Uri.parse(fileUrl));
        await file.writeAsBytes(response.bodyBytes);
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdfHighlightViewerScreen(
              pdfId: docId,
              pdfName: fileName,
              filePath: filePath,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening PDF: $e')),
        );
      }
    }
  }

  Future<void> _retryPdf(String docId, Map<String, dynamic> data) async {
    try {
      await _summaryRepo.deleteSummariesForPdf(docId);
      await _pdfRepo.retryPdf(docId, data);

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Stack(
      children: [
        MeshBackgroundScaffold(
          showAppBar: false,
          body: FadeTransition(
            opacity: _fadeAnim,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _buildDashboardAppBar(context, theme),
                ),
                if (!widget.isDocumentsOnly) ...[
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  SliverToBoxAdapter(
                    child: UploadCard(
                      isUploading: _isUploading,
                      isGenerating: _isGenerating,
                      statusMessage: _statusMessage,
                      onUploadPressed: _pickAndUploadPdf,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  SliverToBoxAdapter(child: _buildLatestDocumentSection(theme)),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        "Your smart AI workspace. Upload any document to generate summaries, exam prep, and chapter breakdowns instantly.",
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  SliverToBoxAdapter(child: _buildDashboardSearchBar(theme)),
                  SliverToBoxAdapter(child: _buildFolderChips(theme)),
                  SliverToBoxAdapter(
                    child: _buildSectionHeader(
                      'YOUR TIMELINE',
                      'Recent Documents',
                      null,
                    ),
                  ),
                  _buildSliverPdfList(theme),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 150)),
              ],
            ),
          ),
          floatingActionButton: widget.isDocumentsOnly
              ? _buildDashboardFab()
              : null,
        ),
      ],
    );
  }

  Widget _buildDashboardAppBar(BuildContext context, ThemeData theme) {
    return PremiumHeader(
      title: widget.isDocumentsOnly ? 'Documents' : 'AI Summarizer',
      onProfileTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ProfileScreen()),
      ),
      actions: [
        if (_isDeleting || _isUploading)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF3B82F6),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDashboardSearchBar(ThemeData theme) {
    final searchProvider = context.watch<SearchFilterProvider>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.dark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (val) => searchProvider.updateSearch(val),
          style: theme.textTheme.bodyMedium,
          decoration: InputDecoration(
            icon: Icon(Icons.search_rounded, color: theme.hintColor, size: 20),
            hintText: 'Search your library...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: theme.hintColor.withOpacity(0.5)),
            suffixIcon: searchProvider.searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      searchProvider.clearSearch();
                    },
                  )
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildFolderChips(ThemeData theme) {
    final searchProvider = context.watch<SearchFilterProvider>();
    final folderProvider = context.watch<FolderProvider>();
    final folders = ['All', ...folderProvider.folderNames];

    return SizedBox(
      height: 50,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: folders.length + 1,
        itemBuilder: (context, index) {
          if (index == folders.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: ActionChip(
                label: const Icon(Icons.add_rounded, size: 18),
                backgroundColor: Colors.white.withOpacity(0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onPressed: () => _showNewFolderDialog(folderProvider, theme),
              ),
            );
          }
          final folder = folders[index];
          final isSelected = searchProvider.selectedFolder == folder;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: FilterChip(
              label: Text(folder),
              selected: isSelected,
              onSelected: (val) => searchProvider.selectFolder(
                val ? (folder == 'All' ? null : folder) : null,
              ),
              backgroundColor: Colors.white.withOpacity(0.05),
              selectedColor: _accentBlue.withOpacity(0.2),
              checkmarkColor: _accentBlue,
              labelStyle: TextStyle(
                color: isSelected
                    ? _accentBlue
                    : (theme.brightness == Brightness.dark
                          ? Colors.white70
                          : Colors.black87),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected
                      ? _accentBlue.withOpacity(0.5)
                      : Colors.transparent,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String label, String title, String? action) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.5,
              color: const Color(0xFF60A5FA).withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black87,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              if (action != null) ...[
                const Spacer(),
                Text(
                  action,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLatestDocumentSection(ThemeData theme) {
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: _pdfRepo.getLatestPdfStream(user!.uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final doc = snapshot.data!.docs.first;
        final data = doc.data() as Map<String, dynamic>;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('LATEST INSIGHT', 'Current Document', null),
            _buildDashboardPdfItem(doc.id, data, theme),
          ],
        );
      },
    );
  }

  Widget _buildSliverPdfList(ThemeData theme) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SliverToBoxAdapter(child: SizedBox());

    final searchProvider = context.watch<SearchFilterProvider>();

    return StreamBuilder<QuerySnapshot>(
      stream: _pdfRepo.getUserPdfsStream(user.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: Center(
              child: Text('Something went wrong: ${snapshot.error}'),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Center(child: CircularProgressIndicator(color: _accentBlue)),
          );
        }

        final allDocs = snapshot.data!.docs;
        final folderProvider = context.watch<FolderProvider>();
        final bookmarkProvider = context.watch<BookmarkProvider>();

        // Filter and Sort using the provider's logic
        final docs = searchProvider.filterAndSort(
          allDocs,
          bookmarkProvider.bookmarkedIds,
          folderAssignments: folderProvider.assignments,
        );

        if (docs.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Column(
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 64,
                    color: theme.hintColor.withOpacity(0.2),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No documents found',
                    style: TextStyle(color: theme.hintColor.withOpacity(0.5)),
                  ),
                ],
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final doc = docs[index];
            return _buildDashboardPdfItem(
              doc.id,
              doc.data() as Map<String, dynamic>,
              theme,
            );
          }, childCount: docs.length),
        );
      },
    );
  }

  Widget _buildDashboardPdfItem(
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

    Color statusColor = status == 'completed'
        ? _emerald
        : (status == 'processing' ? _amber : Colors.redAccent);
    String statusLabel = status == 'completed'
        ? 'READY'
        : (status == 'processing' ? 'PROCESSING' : 'ERROR');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: GlassCard(
        borderRadius: 20,
        padding: EdgeInsets.zero,
        child: ExpansionTileTheme(
          data: ExpansionTileThemeData(
            shape: const Border(),
            collapsedShape: const Border(),
            iconColor: theme.brightness == Brightness.dark
                ? Colors.white54
                : Colors.black54,
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: status == 'completed'
                    ? _accentBlue.withOpacity(0.1)
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                status == 'completed'
                    ? Icons.check_circle_rounded
                    : (status == 'processing'
                          ? Icons.sync_rounded
                          : Icons.error_outline_rounded),
                color: statusColor,
                size: 24,
              ),
            ),
            title: Text(
              fileName,
              style: TextStyle(
                color: theme.brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black87,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Row(
              children: [
                if (assignedFolder != null) ...[
                  Icon(
                    Icons.folder_open_rounded,
                    size: 12,
                    color: _accentBlue.withOpacity(0.7),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    assignedFolder,
                    style: TextStyle(
                      color: _accentBlue.withOpacity(0.7),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    isBookmarked
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_outline_rounded,
                    color: isBookmarked ? _accentBlue : Colors.white24,
                    size: 20,
                  ),
                  onPressed: () => bookmarkProvider.toggleBookmark(docId),
                ),
                const Icon(Icons.expand_more_rounded, size: 20),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _actionIconBtn(
                          Icons.chat_bubble_outline_rounded,
                          "Chat",
                          () {
                            final chatProvider = context.read<ChatProvider>();
                            final navProvider = context
                                .read<NavigationProvider>();

                            chatProvider.setActiveContext(docId, fileName);
                            navProvider.setIndex(2); // Switch to Chat tab
                          },
                        ),
                        _actionIconBtn(Icons.insights_rounded, "Insights", () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  DocumentInsightsScreen(pdfId: docId),
                            ),
                          );
                        }),
                        _actionIconBtn(
                          Icons.highlight_rounded,
                          "Study",
                          () => _openHighlightViewer(docId, fileName, data['fileUrl']),
                          color: const Color(0xFFF59E0B),
                        ),
                        _actionIconBtn(
                          Icons.drive_file_rename_outline_rounded,
                          "Rename",
                          () => _renamePdf(docId, fileName),
                        ),
                        _actionIconBtn(
                          Icons.delete_outline_rounded,
                          "Delete",
                          () => _deleteSinglePdf(docId, data['storagePath']),
                          color: Colors.redAccent,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (status == 'completed')
                      _RewardedSummaryGate(pdfId: docId)
                    else if (status == 'processing')
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: CircularProgressIndicator(color: _accentBlue),
                        ),
                      )
                    else
                      TextButton.icon(
                        onPressed: () => _retryPdf(docId, data),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text("Retry Failed Process"),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionIconBtn(
    IconData icon,
    String label,
    VoidCallback onTap, {
    Color color = Colors.white54,
  }) {
    return Column(
      children: [
        IconButton(
          onPressed: onTap,
          icon: Icon(icon, color: color, size: 22),
        ),
        Text(label, style: TextStyle(color: color, fontSize: 10)),
      ],
    );
  }

  Widget _buildDashboardFab() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(colors: [_accentBlue, _accentCyan]),
        boxShadow: [
          BoxShadow(
            color: _accentBlue.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _pickAndUploadPdf,
          customBorder: const CircleBorder(),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  Future<void> _showNewFolderDialog(
    FolderProvider provider,
    ThemeData theme,
  ) async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Folder name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                provider.createFolder(controller.text);
              }
              Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
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
    final summaryProvider = context.watch<SummaryProvider>();
    final cachedData = summaryProvider.getCachedSummary(pdfId);

    final summaryRepo = SummaryRepository();

    return StreamBuilder<QuerySnapshot>(
      stream: summaryRepo.getSummariesStreamByPdfId(pdfId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            cachedData == null) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator(color: _accentBlue)),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        Map<String, dynamic>? fullSummary;
        Map<String, dynamic>? examSummary;
        Map<String, dynamic>? chapterSummary;

        if (docs.isEmpty && cachedData != null) {
          fullSummary = cachedData['full'];
          examSummary = cachedData['exam'];
          chapterSummary = cachedData['chapters'];
        } else {
          final Map<String, dynamic> newCacheEntry = {};
          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final type = data['type'] ?? 'full';
            if (type == 'full') {
              fullSummary = data;
              newCacheEntry['full'] = data;
            } else if (type == 'exam') {
              examSummary = data;
              newCacheEntry['exam'] = data;
            } else if (type == 'chapters') {
              chapterSummary = data;
              newCacheEntry['chapters'] = data;
            }
          }

          if (newCacheEntry.isNotEmpty) {
            newCacheEntry['fileName'] =
                fullSummary?['fileName'] ??
                examSummary?['fileName'] ??
                chapterSummary?['fileName'];
            newCacheEntry['content'] = [
              fullSummary?['content'] ?? '',
              examSummary?['content'] ?? '',
              (chapterSummary?['chapters'] as List?)
                      ?.map((c) => c['summary'])
                      .join(' ') ??
                  '',
            ].join(' ');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              summaryProvider.updateCache(pdfId, newCacheEntry);
            });
          }
        }

        if (fullSummary == null &&
            examSummary == null &&
            chapterSummary == null) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text(
                "Summaries appearing soon...",
                style: TextStyle(color: Colors.white70),
              ),
            ),
          );
        }

        final List<Widget> tabs = [const Tab(text: "Summary")];
        final List<Widget> views = [
          _buildSummaryContent(
            fullSummary?['content'] ?? "Generating...",
            theme,
            context,
            pdfId,
            "Document",
          ),
        ];

        tabs.add(const Tab(text: "Exam Mode"));
        views.add(
          _buildSummaryContent(
            examSummary?['content'] ?? "Exam summary is not available.",
            theme,
            context,
            pdfId,
            "Document",
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
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.2),
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
                color: _accentBlue,
              ),
              const SizedBox(width: 8),
              Text(
                isExam ? "Exam Prep" : "AI Summary",
                style: const TextStyle(
                  color: _accentBlue,
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
                  color: _accentBlue,
                ),
                onPressed: () => ExportService.exportSummaryToPdf(
                  context: context,
                  fileName: fileName,
                  summaryContent: content,
                  summaryType: isExam ? 'Exam Prep' : 'AI Summary',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildFormattedText(content, theme),
          if (isExam && questions != null && questions.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Divider(color: Colors.white24),
            ...questions.asMap().entries.map((entry) {
              final index = entry.key;
              final qa = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: _accentBlue.withOpacity(0.2),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: _accentBlue,
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
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _accentBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        qa['answer'] ?? '',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
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
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      AiChatScreen(pdfId: pdfId, fileName: fileName),
                ),
              ),
              icon: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 20,
                color: Colors.white,
              ),
              label: const Text(
                'Chat with AI',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _accentBlue,
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
          color: _accentBlue,
        ),
        h2: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: _accentBlue,
        ),
        listBullet: const TextStyle(color: _accentBlue),
      ),
    );
  }

  static const _emerald = Color(0xFF10B981);
  static const _amber = Color(0xFFFBBF24);
  static const _accentBlue = Color(0xFF3B82F6);
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
          labelColor: const Color(0xFFA78BFA),
          unselectedLabelColor: Colors.white54,
          indicatorColor: const Color(0xFFA78BFA),
          dividerColor: Colors.transparent,
          onTap: (i) => setState(() {}),
        ),
        Divider(height: 1, color: Colors.white.withOpacity(0.1)),
        widget.views[_controller.index],
      ],
    );
  }
}

class _RewardedSummaryGate extends StatefulWidget {
  final String pdfId;
  const _RewardedSummaryGate({required this.pdfId});

  @override
  State<_RewardedSummaryGate> createState() => _RewardedSummaryGateState();
}

class _RewardedSummaryGateState extends State<_RewardedSummaryGate> {
  bool _isUnlocked = false;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final summaryProvider = context.watch<SummaryProvider>();
    final isCached = summaryProvider.getCachedSummary(widget.pdfId) != null;
    if (_isUnlocked || isCached) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: PrimaryButton(
          text: "View Insights",
          icon: Icons.auto_awesome_rounded,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    DocumentInsightsScreen(pdfId: widget.pdfId),
              ),
            );
          },
        ),
      );
    }
    return Column(
      children: [
        const Icon(
          Icons.play_circle_outline_rounded,
          size: 48,
          color: Color(0xFF3B82F6),
        ),
        const SizedBox(height: 16),
        const Text(
          'Unlock AI Summary with a short ad',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _isLoading
              ? null
              : () async {
                  setState(() => _isLoading = true);
                  final adShown = await AdService().showRewardedAd(
                    onRewarded: () => setState(() => _isUnlocked = true),
                  );
                  if (!adShown && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ad not ready.')),
                    );
                  }
                  if (mounted) setState(() => _isLoading = false);
                },
          icon: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.play_arrow_rounded, color: Colors.white),
          label: Text(
            _isLoading ? 'Loading...' : 'Watch Ad & Unlock',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF3B82F6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}
