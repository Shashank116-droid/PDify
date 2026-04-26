import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:pdify/providers/summary_provider.dart';
import 'package:pdify/services/export_service.dart';
import 'package:pdify/services/ad_service.dart';
import 'package:pdify/repositories/pdf_repository.dart';
import 'package:pdify/repositories/summary_repository.dart';
import 'package:pdify/widgets/definition_card.dart';
import 'package:pdify/widgets/qa_card.dart';
import 'package:provider/provider.dart';

class DocumentInsightsScreen extends StatefulWidget {
  final String pdfId;

  const DocumentInsightsScreen({super.key, required this.pdfId});

  @override
  State<DocumentInsightsScreen> createState() => _DocumentInsightsScreenState();
}

class _DocumentInsightsScreenState extends State<DocumentInsightsScreen>
    with SingleTickerProviderStateMixin {
  int _selectedModeIndex = 1; // Exam Mode selected by default

  final PdfRepository _pdfRepo = PdfRepository();
  final SummaryRepository _summaryRepo = SummaryRepository();

  final List<String> _modes = [
    'Standard\nSummary',
    'Exam\nMode',
    'Chapter\nBreakdown',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Colors
    const deepBg = Color(0xFF0B1120);
    const cardBg = Color(0xFF131B2E);
    const accentBlue = Color(0xFF3B82F6);
    const accentCyan = Color(0xFF00D9FF);
    return Scaffold(
      backgroundColor: deepBg,
      body: Stack(
        children: [
          // ── Mesh gradient blobs ──
          Positioned(top: -120, right: -100, child: _meshBlob(accentBlue, 400)),
          Positioned(
            bottom: 200,
            left: -120,
            child: _meshBlob(const Color(0xFF1E1B4B), 500),
          ),
          Positioned(
            bottom: -80,
            right: -60,
            child: _meshBlob(accentCyan, 280),
          ),
          // Blur overlay
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(color: deepBg.withOpacity(0.65)),
            ),
          ),
          // ── Content ──
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // App Bar
                SliverToBoxAdapter(child: _buildAppBar(theme)),

                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _summaryRepo.getSummariesByPdfIdWithCache(widget.pdfId),
                  builder: (context, snapshot) {
                    debugPrint(
                      "DocumentInsightsScreen: FutureBuilder snapshot state: ${snapshot.connectionState}, hasData: ${snapshot.hasData}, pdfId: ${widget.pdfId}",
                    );
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SliverFillRemaining(
                        child: Center(
                          child: CircularProgressIndicator(color: accentBlue),
                        ),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      debugPrint(
                        "DocumentInsightsScreen: No docs in cache/firestore. Trying FutureBuilder fallback for docId.",
                      );
                      return FutureBuilder<DocumentSnapshot>(
                        future: _summaryRepo.getSummaryFuture(widget.pdfId),
                        builder: (context, docSnapshot) {
                          debugPrint(
                            "DocumentInsightsScreen: FutureBuilder fallback state: ${docSnapshot.connectionState}, exists: ${docSnapshot.data?.exists}, id: ${widget.pdfId}",
                          );
                          if (docSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const SliverFillRemaining(
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: accentBlue,
                                ),
                              ),
                            );
                          }
                          if (!docSnapshot.hasData ||
                              !docSnapshot.data!.exists) {
                            return const SliverFillRemaining(
                              child: Center(
                                child: Text(
                                  "No summary found",
                                  style: TextStyle(color: Colors.white54),
                                ),
                              ),
                            );
                          }
                          return _buildInsightsContent(
                            docSnapshot.data!.data() as Map<String, dynamic>,
                            theme,
                          );
                        },
                      );
                    }

                    debugPrint(
                      "DocumentInsightsScreen: Found ${snapshot.data!.length} summary docs for pdfId: ${widget.pdfId}",
                    );
                    // Aggregated results for multiple summary docs
                    Map<String, dynamic>? fullData;
                    Map<String, dynamic>? examData;
                    Map<String, dynamic>? chapterData;
                    Map<String, dynamic>? legacyData;

                    for (var data in snapshot.data!) {
                      final type = data['type'];
                      if (type == 'full')
                        fullData = data;
                      else if (type == 'exam')
                        examData = data;
                      else if (type == 'chapters')
                        chapterData = data;
                      else
                        legacyData = data;
                    }

                    return FutureBuilder<Map<String, dynamic>>(
                      future: widget.pdfId.startsWith('local_') 
                          ? _pdfRepo.getLocalPdfs().then((list) => list.firstWhere((e) => e['id'] == widget.pdfId, orElse: () => {}))
                          : _pdfRepo.getPdfFuture(widget.pdfId).then((doc) => doc.data() as Map<String, dynamic>? ?? {}),
                      builder: (context, pdfSnapshot) {
                        final pdfData = pdfSnapshot.data ?? {};
                        final fileName =
                            (pdfData['fileName'] ??
                                     pdfData['fileName'] ?? // Local metadata has fileName
                                    fullData?['fileName'] ??
                                    legacyData?['fileName'] ??
                                    "Document")
                                .toString();
                        final pageCount =
                            int.tryParse(
                              (pdfData['pageCount'] ??
                                      fullData?['pageCount'] ??
                                      legacyData?['pageCount'] ??
                                      0)
                                  .toString(),
                            ) ??
                            0;

                        final aggregatedData = {
                          'full': fullData ?? legacyData,
                          'exam':
                              examData ??
                              (legacyData != null && _hasExamData(legacyData)
                                  ? legacyData
                                  : null),
                          'chapter':
                              chapterData ??
                              (legacyData != null &&
                                      legacyData.containsKey('chapters')
                                  ? legacyData
                                  : null),
                          'fileName': fileName,
                          'pageCount': pageCount,
                        };

                        return _buildInsightsFromAggregated(
                          aggregatedData,
                          theme,
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      // ── Bottom Navigation ──
      // bottomNavigationBar: _buildBottomNav(isDark),
      // ── FAB ──
      /*
      floatingActionButton: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(colors: [accentBlue, accentCyan]),
          boxShadow: [
            BoxShadow(
              color: accentBlue.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.edit_rounded, color: Colors.white, size: 22),
      ),
      */
      bottomNavigationBar: const BannerAdWidget(),
    );
  }

  bool _hasExamData(Map<String, dynamic> data) {
    return data.containsKey('qa') ||
        data.containsKey('questions') ||
        data.containsKey('practiceQuestions') ||
        data.containsKey('keyDefinitions') ||
        data.containsKey('definitions');
  }

  // ══════════════════════════════════════════════════════════════════
  // UI HELPERS
  // ══════════════════════════════════════════════════════════════════

  Widget _buildInsightsContent(Map<String, dynamic> data, ThemeData theme) {
    // If it's a legacy all-in-one document
    final aggregated = {
      'full': data,
      'exam': _hasExamData(data) ? data : null,
      'chapter': data.containsKey('chapters') ? data : null,
      'fileName': data['fileName'] ?? "Document",
      'pageCount': data['pageCount'] ?? 0,
    };
    return _buildInsightsFromAggregated(aggregated, theme);
  }

  Widget _buildInsightsFromAggregated(
    Map<String, dynamic> aggregated,
    ThemeData theme,
  ) {
    final cardBg = theme.brightness == Brightness.dark
        ? Colors.white.withOpacity(0.05)
        : Colors.black.withOpacity(0.05);
    final full = aggregated['full'] as Map<String, dynamic>? ?? {};
    final exam = aggregated['exam'] as Map<String, dynamic>?;
    final chapter = aggregated['chapter'] as Map<String, dynamic>?;
    final fileName = aggregated['fileName'].toString();
    final pageCount = int.tryParse(aggregated['pageCount'].toString()) ?? 0;

    // Persist to local cache so the ad gate remains unlocked next time
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final summaryProvider =
          Provider.of<SummaryProvider>(context, listen: false);
      final existing = summaryProvider.getCachedSummary(widget.pdfId);
      if (existing == null) {
        debugPrint('DocumentInsightsScreen: No cache found for ${widget.pdfId}, updating cache now...');
        summaryProvider.updateCache(widget.pdfId, aggregated);
      } else {
        debugPrint('DocumentInsightsScreen: Cache already exists for ${widget.pdfId}');
      }
    });

    return SliverList(
      delegate: SliverChildListDelegate([
        // Document Header
        _buildDocumentHeader(theme, fileName, pageCount),
        // Mode Tabs
        _buildModeTabs(theme),

        if (_selectedModeIndex == 0) ...[
          // Standard Summary
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'AI Summary',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                _buildExportButton(() {
                  ExportService.exportSummaryToPdf(
                    context: context,
                    fileName: fileName,
                    summaryContent: full['content'] ?? full['summary'] ?? "",
                  );
                }),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildFormattedText(
              full['content'] ?? full['summary'] ?? "Generating summary...",
              theme,
            ),
          ),
        ] else if (_selectedModeIndex == 1) ...[
          // Exam Mode (Definitions + QA)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Exam Prep Mode',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                _buildExportButton(() {
                  if (exam != null) {
                    ExportService.exportExamPrepToPdf(
                      context: context,
                      fileName: fileName,
                      definitions:
                          exam['keyDefinitions'] ?? exam['definitions'] ?? [],
                      qa: exam['qa'] ?? exam['questions'] ?? [],
                    );
                  }
                }),
              ],
            ),
          ),
          if (exam != null &&
              (exam['content'] != null || exam['summary'] != null))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildFormattedText(
                exam['content'] ?? exam['summary'] ?? "",
                theme,
              ),
            ),

          if (exam != null) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Text(
                'Key Definitions',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            ...((exam['keyDefinitions'] ?? exam['definitions'] ?? [])
                    as List<dynamic>)
                .map(
                  (d) => DefinitionCard(
                    term: d['term'] ?? d['word'] ?? "",
                    definition: d['definition'] ?? d['meaning'] ?? "",
                    cardBg: cardBg,
                  ),
                ),

            const Padding(
              padding: EdgeInsets.fromLTRB(20, 28, 20, 16),
              child: Text(
                'Practice Q&A',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            ...((exam['qa'] ?? exam['questions'] ?? []) as List<dynamic>).map((
              q,
            ) {
              final questionsList =
                  ((exam['qa'] ?? exam['questions'] ?? []) as List<dynamic>);
              return QACard(
                questionNumber: (questionsList.indexOf(q) + 1)
                    .toString()
                    .padLeft(2, '0'),
                question: q['question'] ?? q['q'] ?? "",
                answer: q['answer'] ?? q['a'] ?? "",
                showAnswer: true,
                cardBg: cardBg,
              );
            }),
          ] else
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                "No exam prep found for this document.",
                style: TextStyle(color: Colors.white54),
              ),
            ),
        ] else ...[
          // Chapter Breakdown
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Chapter Analysis',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                _buildExportButton(() {
                  if (chapter != null) {
                    ExportService.exportChaptersToPdf(
                      context: context,
                      fileName: fileName,
                      chapters: chapter['chapters'] ?? [],
                    );
                  }
                }),
              ],
            ),
          ),
          if (chapter != null)
            ...(chapter['chapters'] as List<dynamic>? ?? []).map(
              (c) => _buildChapterTile(c, theme, cardBg),
            )
          else
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                "No chapter breakdown found for this document.",
                style: TextStyle(color: Colors.white54),
              ),
            ),
        ],

        const SizedBox(height: 100),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // APP BAR
  // ══════════════════════════════════════════════════════════════════
  Widget _buildAppBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 28,
                  height: 28,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'PDify',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const Spacer(),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // DOCUMENT HEADER
  // ══════════════════════════════════════════════════════════════════
  Widget _buildDocumentHeader(ThemeData theme, String title, int pageCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          // Label + icon
          Row(
            children: [
              Text(
                'DOCUMENT ANALYSIS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.0,
                  color: const Color(0xFF60A5FA).withOpacity(0.8),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.description_rounded,
                color: Colors.white.withOpacity(0.3),
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Title
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.2,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          // Metadata row
          Row(
            children: [
              Icon(
                Icons.menu_book_rounded,
                color: Colors.white.withOpacity(0.5),
                size: 15,
              ),
              const SizedBox(width: 4),
              
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // MODE TABS
  // ══════════════════════════════════════════════════════════════════
  Widget _buildModeTabs(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: List.generate(_modes.length, (i) {
            final isSelected = _selectedModeIndex == i;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedModeIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: isSelected
                        ? const LinearGradient(
                            colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
                          )
                        : null,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF3B82F6).withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    _modes[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withOpacity(0.5),
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }



  // ══════════════════════════════════════════════════════════════════
  // BOTTOM NAVIGATION
  // ══════════════════════════════════════════════════════════════════
  Widget _buildBottomNav(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B1120).withOpacity(0.95),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(Icons.dashboard_rounded, 'Dashboard', false),
                _navItem(Icons.description_rounded, 'Documents', true),
                _navItem(Icons.chat_bubble_rounded, 'Chat', false),
                _navItem(Icons.build_rounded, 'Tools', false),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExportButton(VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF3B82F6).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.2)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.ios_share_rounded, color: Color(0xFF60A5FA), size: 14),
            SizedBox(width: 6),
            Text(
              'Share PDF',
              style: TextStyle(
                color: Color(0xFF60A5FA),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool isActive) {
    final color = isActive
        ? const Color(0xFF3B82F6)
        : Colors.white.withOpacity(0.4);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // MESH BLOB
  // ══════════════════════════════════════════════════════════════════
  Widget _buildChapterTile(dynamic chapter, ThemeData theme, Color cardBg) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: ExpansionTileTheme(
          data: const ExpansionTileThemeData(
            shape: Border(),
            collapsedShape: Border(),
            iconColor: Colors.white54,
          ),
          child: ExpansionTile(
            title: Text(
              chapter['title'] ?? "Chapter",
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [_buildFormattedText(chapter['summary'] ?? "", theme)],
          ),
        ),
      ),
    );
  }

  Widget _buildFormattedText(String text, ThemeData theme) {
    return MarkdownBody(
      data: text,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: const TextStyle(fontSize: 14, color: Colors.white70, height: 1.55),
        strong: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        h1: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: Color(0xFF3B82F6),
        ),
        h2: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Color(0xFF3B82F6),
        ),
        listBullet: const TextStyle(color: Color(0xFF3B82F6)),
      ),
    );
  }

  Widget _meshBlob(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withOpacity(0.6), color.withOpacity(0.0)],
        ),
      ),
    );
  }

  Widget _buildMarkdownText(String text, TextStyle baseStyle) {
    List<TextSpan> spans = [];
    final regExp = RegExp(r'\*\*(.+?)\*\*');
    int start = 0;

    for (var match in regExp.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: baseStyle.copyWith(
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      );
      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }

    return RichText(
      text: TextSpan(children: spans, style: baseStyle),
    );
  }
}
