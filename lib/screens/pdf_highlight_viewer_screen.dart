import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:provider/provider.dart';
import 'package:pdify/services/gemini_ocr_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:pdify/models/highlight_model.dart';
import 'package:pdify/providers/highlight_provider.dart';
import 'package:pdify/screens/cheat_sheet_screen.dart';
import 'package:pdify/widgets/mesh_background_scaffold.dart';
import 'package:pdify/widgets/glass_card.dart';

class PdfHighlightViewerScreen extends StatefulWidget {
  final String pdfId;
  final String pdfName;
  final String filePath;

  const PdfHighlightViewerScreen({
    super.key,
    required this.pdfId,
    required this.pdfName,
    required this.filePath,
  });

  @override
  State<PdfHighlightViewerScreen> createState() => _PdfHighlightViewerScreenState();
}

class _PdfHighlightViewerScreenState extends State<PdfHighlightViewerScreen> {
  late PdfControllerPinch _pdfController;
  final GeminiOcrService _ocrService = GeminiOcrService();
  int _currentPage = 1;
  int _totalPages = 0;
  bool _isExtracting = false;

  @override
  void initState() {
    super.initState();
    _pdfController = PdfControllerPinch(
      document: PdfDocument.openFile(widget.filePath),
    );
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  void _showAddHighlightDialog({String initialText = ''}) {
    final textController = TextEditingController(text: initialText);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.edit_note_rounded, color: Color(0xFF60A5FA), size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Highlight from Page $_currentPage',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: textController,
                autofocus: true,
                maxLines: 5,
                minLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Type or paste the text you want to highlight...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF3B82F6)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  final text = textController.text.trim();
                  if (text.isNotEmpty) {
                    context.read<HighlightProvider>().addHighlight(
                          widget.pdfId,
                          Highlight(pageNumber: _currentPage, text: text),
                        );
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Highlight saved!')),
                    );
                  }
                },
                icon: const Icon(Icons.bookmark_add_rounded),
                label: const Text('Save Highlight'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _extractTextFromPage() async {
    setState(() => _isExtracting = true);
    try {
      // 1. Open document and page using low-level API
      final document = await PdfDocument.openFile(widget.filePath);
      final page = await document.getPage(_currentPage);
      
      // 2. Render page to image bytes (higher quality for OCR)
      final pageImage = await page.render(
        width: page.width * 2.0,
        height: page.height * 2.0,
        format: PdfPageImageFormat.jpeg,
        quality: 100,
      );

      if (pageImage != null) {
        // 3. Save to temp file
        final tempDir = await getTemporaryDirectory();
        final imagePath = p.join(tempDir.path, 'ocr_page_${widget.pdfId}_$_currentPage.jpg');
        final file = File(imagePath);
        await file.writeAsBytes(pageImage.bytes);

        // 4. Run OCR
        final extractedText = await _ocrService.extractTextFromImage(file);
        
        // 5. Cleanup and Show Dialog
        await page.close();
        await document.close();
        
        if (mounted) {
          if (extractedText.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No text could be extracted from this page.')),
            );
          } else {
            _showAddHighlightDialog(initialText: extractedText);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Extraction failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExtracting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final highlightProvider = context.watch<HighlightProvider>();
    final pageHighlights = highlightProvider.getHighlightsForPage(widget.pdfId, _currentPage);
    final totalHighlights = highlightProvider.getHighlightCount(widget.pdfId);

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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.pdfName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Page $_currentPage of $_totalPages',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (totalHighlights > 0)
                    TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CheatSheetScreen(
                              pdfId: widget.pdfId,
                              pdfName: widget.pdfName,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFF59E0B), size: 20),
                      label: Text(
                        'Cheat Sheet ($totalHighlights)',
                        style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 13),
                      ),
                    ),
                ],
              ),
            ),

            // PDF Viewer
            Expanded(
              child: PdfViewPinch(
                controller: _pdfController,
                onDocumentLoaded: (document) {
                  setState(() => _totalPages = document.pagesCount);
                },
                onPageChanged: (page) {
                  setState(() => _currentPage = page);
                },
              ),
            ),

            // Page Highlights
            if (pageHighlights.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 120),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: pageHighlights.length,
                  itemBuilder: (context, index) {
                    final h = pageHighlights[index];
                    // Find the global index for deletion
                    final globalIndex = highlightProvider
                        .getHighlightsForPdf(widget.pdfId)
                        .indexOf(h);
                    return Container(
                      width: 200,
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.format_quote_rounded, color: Color(0xFF60A5FA), size: 16),
                              const Spacer(),
                              InkWell(
                                onTap: () {
                                  highlightProvider.removeHighlight(widget.pdfId, globalIndex);
                                },
                                child: const Icon(Icons.close_rounded, color: Colors.white38, size: 16),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Expanded(
                            child: Text(
                              h.text,
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 4,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

            // Bottom Action Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withOpacity(0.8),
                border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isExtracting ? null : _extractTextFromPage,
                      icon: _isExtracting 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.auto_fix_high_rounded, size: 20),
                      label: Text(_isExtracting ? 'Extracting...' : 'Smart Extract'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6), // Purple for magic/AI
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showAddHighlightDialog(),
                      icon: const Icon(Icons.highlight_rounded, size: 20),
                      label: const Text('Manual'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  if (totalHighlights > 0) ...[
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CheatSheetScreen(
                              pdfId: widget.pdfId,
                              pdfName: widget.pdfName,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.auto_awesome_rounded, size: 20),
                      label: const Text('Cheat Sheet'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
