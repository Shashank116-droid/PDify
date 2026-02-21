import 'dart:io';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:pdify/ad_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:in_app_update/in_app_update.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _checkForUpdate();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Gradient Mesh Background Colors
    const color1 = Color(0xFF7C3AED); // Vivid Purple
    const color2 = Color(0xFFFF6B6B); // Coral Red
    const color3 = Color(0xFF00D9FF); // Cyan
    const color4 = Color(0xFFFFD166); // Warm Yellow

    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_stories, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              "Pdify",
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800, // Bolder
                color: theme.colorScheme.primary,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // --- Gradient Mesh Background ---
          Positioned(top: -100, left: -50, child: _buildMeshBlob(color1, 300)),
          Positioned(top: 150, right: -80, child: _buildMeshBlob(color2, 350)),
          Positioned(
            bottom: -50,
            left: -50,
            child: _buildMeshBlob(color3, 300),
          ),
          Positioned(
            bottom: 200,
            right: -50,
            child: _buildMeshBlob(color4, 250),
          ),

          // Blur to blend blobs into a mesh
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: Container(
                color: Colors.white.withValues(alpha: 0.3),
              ), // SLight overlay
            ),
          ),

          // --- Content ---
          SafeArea(
            child: Column(
              children: [
                _buildUploadSection(theme),
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
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Upload a PDF to get started",
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.black38,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      var docs = snapshot.data!.docs;
                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          var doc = docs[index];
                          var data = doc.data() as Map<String, dynamic>;
                          return _buildPdfItem(doc.id, data, theme);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      // Banner Ad at bottom
      bottomNavigationBar: Container(
        color: Colors.white,
        child: SafeArea(child: const BannerAdWidget()),
      ),
    );
  }

  Widget _buildMeshBlob(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: 0.6), color.withValues(alpha: 0.0)],
        ),
      ),
    );
  }

  Widget _buildUploadSection(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(
              0xFF7C3AED,
            ).withValues(alpha: 0.08), // Subtle purple shadow
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
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
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "PDFs up to 10MB • AI-powered summaries",
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
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
              : SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _uploadPdf,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text(
                      "Choose PDF",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      shadowColor: const Color(
                        0xFF7C3AED,
                      ).withValues(alpha: 0.4),
                      elevation: 8,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildPdfItem(
    String docId,
    Map<String, dynamic> data,
    ThemeData theme,
  ) {
    String status = data['status'] ?? 'unknown';
    String fileName = data['fileName'] ?? 'Unknown File';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          title: Text(
            fileName,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _buildStatusChip(status, theme),
            ),
          ),
          leading: _buildStatusIcon(status, theme),
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
                          color: Colors.black54,
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
                        "Failed.",
                        style: TextStyle(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
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
                style: TextStyle(color: Colors.black.withValues(alpha: 0.5)),
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
          ),
        ];

        tabs.add(const Tab(text: "Exam Mode"));
        views.add(
          _buildSummaryContent(
            examSummary?['content'] ??
                "Exam summary is not available for this document.\n\nTry uploading the PDF again if this persists.",
            theme,
            isExam: true,
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
            color: const Color(0xFFF9FAFB), // Very light gray for contrast
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
    ThemeData theme, {
    bool isExam = false,
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
                  Icons.share_rounded,
                  size: 20,
                  color: Color(0xFF7C3AED),
                ),
                onPressed: () {
                  final String subject = isExam
                      ? "Exam Prep Summary"
                      : "AI Summary";
                  final String shareText =
                      "$subject:\n\n$content\n\nGenerated by Pdify 📄";
                  Share.share(shareText, subject: subject);
                },
                tooltip: 'Share Summary',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildFormattedText(content, theme),
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
              color: Colors.black87,
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          iconColor: const Color(0xFF7C3AED),
          collapsedIconColor: Colors.black45,
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
        p: const TextStyle(fontSize: 15, color: Color(0xFF374151), height: 1.6),
        strong: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xFF111827),
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
          labelColor: const Color(0xFF7C3AED),
          unselectedLabelColor: Colors.black45,
          indicatorColor: const Color(0xFF7C3AED),
          indicatorSize: TabBarIndicatorSize.label,
          dividerColor: Colors.transparent,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          onTap: (index) {
            setState(() {});
          },
        ),
        Divider(height: 1, color: Colors.black.withValues(alpha: 0.05)),
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
                const Text(
                  'Watch a short ad to view this summary',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
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
                      style: const TextStyle(fontWeight: FontWeight.bold),
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
