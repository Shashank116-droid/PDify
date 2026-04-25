import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:pdify/widgets/mesh_background_scaffold.dart';
import 'package:pdify/widgets/glass_card.dart';
import 'package:pdify/widgets/primary_button.dart';
import 'package:pdify/widgets/qa_card.dart';
import 'package:pdify/services/export_service.dart';

class ExamNotesScreen extends StatefulWidget {
  final String topics;
  final String notesMarkdown;
  final List<Map<String, dynamic>> questions;

  const ExamNotesScreen({
    super.key,
    required this.topics,
    required this.notesMarkdown,
    required this.questions,
  });

  @override
  State<ExamNotesScreen> createState() => _ExamNotesScreenState();
}

class _ExamNotesScreenState extends State<ExamNotesScreen> {
  bool _showAnswers = true;

  // ── Build full text for copy/share ──
  String _buildFullText() {
    final buffer = StringBuffer();
    buffer.writeln('📝 Exam Notes');
    buffer.writeln('${'─' * 40}');
    buffer.writeln(widget.notesMarkdown);

    if (widget.questions.isNotEmpty) {
      buffer.writeln('\n\n🎯 Practice Q&A');
      buffer.writeln('${'─' * 40}');
      for (int i = 0; i < widget.questions.length; i++) {
        buffer.writeln('Q${i + 1}: ${widget.questions[i]['question']}');
        buffer.writeln('A: ${widget.questions[i]['answer']}\n');
      }
    }
    return buffer.toString();
  }

  Future<void> _copyAll() async {
    await Clipboard.setData(ClipboardData(text: _buildFullText()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notes copied to clipboard!')),
      );
    }
  }

  Future<void> _shareAll() async {
    await Share.share(_buildFullText());
  }

  Future<void> _exportAsPdf() async {
    await ExportService.exportExamNotesToPdf(
      context: context,
      topics: widget.topics,
      notesMarkdown: widget.notesMarkdown,
      questions: widget.questions,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = Colors.white.withOpacity(0.05);

    return MeshBackgroundScaffold(
      showAppBar: false,
      body: SafeArea(
        child: Column(
          children: [
            // ── App Bar (same style as CheatSheetScreen) ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_rounded,
                        color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'Exam Notes',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: Colors.white70),
                    tooltip: 'Copy All',
                    onPressed: _copyAll,
                  ),
                  IconButton(
                    icon:
                        const Icon(Icons.share_rounded, color: Colors.white70),
                    tooltip: 'Share',
                    onPressed: _shareAll,
                  ),
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf_rounded,
                        color: Color(0xFFEC4899)),
                    tooltip: 'Export as PDF',
                    onPressed: _exportAsPdf,
                  ),
                ],
              ),
            ),

            // ── Topic subtitle ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                widget.topics.length > 100
                    ? '${widget.topics.substring(0, 100)}...'
                    : widget.topics,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 13,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            const SizedBox(height: 12),

            // ── Content ──
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Notes Section Header ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                      child: Row(
                        children: [
                          Text(
                            'STUDY NOTES',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.0,
                              color: const Color(0xFF60A5FA).withOpacity(0.8),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.white.withOpacity(0.3),
                            size: 18,
                          ),
                        ],
                      ),
                    ),

                    // ── Notes Content ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildFormattedText(widget.notesMarkdown),
                    ),

                    // ── Q&A Section ──
                    if (widget.questions.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
                        child: Row(
                          children: [
                            const Text(
                              'Practice Q&A',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                            const Spacer(),
                            // Toggle answers button
                            InkWell(
                              onTap: () =>
                                  setState(() => _showAnswers = !_showAnswers),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3B82F6)
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: const Color(0xFF3B82F6)
                                          .withOpacity(0.2)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _showAnswers
                                          ? Icons.visibility_off_rounded
                                          : Icons.visibility_rounded,
                                      color: const Color(0xFF60A5FA),
                                      size: 14,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _showAnswers
                                          ? 'Hide Answers'
                                          : 'Show Answers',
                                      style: const TextStyle(
                                        color: Color(0xFF60A5FA),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── Q&A Cards (same QACard widget as DocumentInsightsScreen) ──
                      ...widget.questions.asMap().entries.map((entry) {
                        final i = entry.key;
                        final q = entry.value;
                        return QACard(
                          questionNumber: (i + 1).toString().padLeft(2, '0'),
                          question: q['question'] ?? '',
                          answer: q['answer'] ?? '',
                          showAnswer: _showAnswers,
                          cardBg: cardBg,
                        );
                      }),
                    ],

                    const SizedBox(height: 20),

                    // ── Bottom Action Row (same as OCR screen) ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: PrimaryButton(
                              text: "Copy",
                              icon: Icons.copy_rounded,
                              onPressed: _copyAll,
                              backgroundColor: const Color(0xFF64748B),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            flex: 1,
                            child: PrimaryButton(
                              text: "Share",
                              icon: Icons.share_rounded,
                              onPressed: _shareAll,
                              backgroundColor: const Color(0xFFF59E0B),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            flex: 1,
                            child: PrimaryButton(
                              text: "To PDF",
                              icon: Icons.picture_as_pdf_rounded,
                              onPressed: _exportAsPdf,
                              backgroundColor: const Color(0xFFEC4899),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Same MarkdownBody styling as DocumentInsightsScreen._buildFormattedText ──
  Widget _buildFormattedText(String text) {
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
}
