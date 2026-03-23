import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:pdify/models/highlight_model.dart';
import 'package:pdify/providers/highlight_provider.dart';
import 'package:pdify/widgets/mesh_background_scaffold.dart';
import 'package:pdify/widgets/glass_card.dart';

class CheatSheetScreen extends StatelessWidget {
  final String pdfId;
  final String pdfName;

  const CheatSheetScreen({
    super.key,
    required this.pdfId,
    required this.pdfName,
  });

  String _buildCheatSheetText(List<Highlight> highlights) {
    final buffer = StringBuffer();
    buffer.writeln('📋 Cheat Sheet: $pdfName');
    buffer.writeln('${'─' * 40}');

    // Group by page
    final Map<int, List<Highlight>> grouped = {};
    for (final h in highlights) {
      grouped.putIfAbsent(h.pageNumber, () => []).add(h);
    }

    final sortedPages = grouped.keys.toList()..sort();
    for (final page in sortedPages) {
      buffer.writeln('\n📄 Page $page');
      for (final h in grouped[page]!) {
        buffer.writeln('  • ${h.text}');
      }
    }

    return buffer.toString();
  }

  Future<void> _exportAsPdf(BuildContext context, List<Highlight> highlights) async {
    try {
      final pdf = pw.Document();
      final cheatText = _buildCheatSheetText(highlights);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (ctx) => [
            pw.Header(
              level: 0,
              child: pw.Text('Cheat Sheet: $pdfName',
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Text(cheatText, style: const pw.TextStyle(fontSize: 12)),
          ],
        ),
      );

      final appDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${appDir.path}/PDify/PDFs');
      if (!await dir.exists()) await dir.create(recursive: true);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '${dir.path}/CheatSheet_$timestamp.pdf';
      final file = File(path);
      await file.writeAsBytes(await pdf.save());

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Cheat Sheet exported as PDF!'),
            action: SnackBarAction(
              label: 'Share',
              onPressed: () => Share.shareXFiles([XFile(path)], text: 'Cheat Sheet from PDify'),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final highlightProvider = context.watch<HighlightProvider>();
    final highlights = highlightProvider.getHighlightsForPdf(pdfId);

    // Group by page
    final Map<int, List<Highlight>> grouped = {};
    for (final h in highlights) {
      grouped.putIfAbsent(h.pageNumber, () => []).add(h);
    }
    final sortedPages = grouped.keys.toList()..sort();

    return MeshBackgroundScaffold(
      showAppBar: false,
      body: SafeArea(
        child: Column(
          children: [
            // App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'Cheat Sheet',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (highlights.isNotEmpty) ...[
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, color: Colors.white70),
                      tooltip: 'Copy All',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _buildCheatSheetText(highlights)));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Cheat sheet copied!')),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.share_rounded, color: Colors.white70),
                      tooltip: 'Share',
                      onPressed: () => Share.share(_buildCheatSheetText(highlights)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFEC4899)),
                      tooltip: 'Export as PDF',
                      onPressed: () => _exportAsPdf(context, highlights),
                    ),
                  ],
                ],
              ),
            ),

            // Document Name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                pdfName,
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            const SizedBox(height: 12),

            // Content
            Expanded(
              child: highlights.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.highlight_off_rounded, size: 64, color: Colors.white24),
                          SizedBox(height: 16),
                          Text(
                            'No highlights yet.\nOpen the PDF viewer and add some!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white38, fontSize: 15),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: sortedPages.length,
                      itemBuilder: (context, sectionIndex) {
                        final page = sortedPages[sectionIndex];
                        final pageHighlights = grouped[page]!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 16, bottom: 8),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF3B82F6).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Page $page',
                                      style: const TextStyle(
                                        color: Color(0xFF60A5FA),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${pageHighlights.length} highlight${pageHighlights.length > 1 ? 's' : ''}',
                                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            ...pageHighlights.asMap().entries.map((entry) {
                              final h = entry.value;
                              final globalIndex = highlights.indexOf(h);
                              return Dismissible(
                                key: ValueKey('${h.pageNumber}_${h.createdAt.toIso8601String()}'),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.delete_rounded, color: Colors.redAccent),
                                ),
                                onDismissed: (_) {
                                  highlightProvider.removeHighlight(pdfId, globalIndex);
                                },
                                child: GlassCard(
                                  borderRadius: 12,
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 4,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF59E0B),
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            h.text,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              height: 1.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
