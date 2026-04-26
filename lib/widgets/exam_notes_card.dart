import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdify/services/gemini_ocr_service.dart';
import 'package:pdify/screens/exam_notes_screen.dart';
import 'package:pdify/widgets/primary_button.dart';
import 'package:pdify/repositories/exam_notes_repository.dart';

class ExamNotesCard extends StatefulWidget {
  const ExamNotesCard({super.key});

  @override
  State<ExamNotesCard> createState() => _ExamNotesCardState();
}

class _ExamNotesCardState extends State<ExamNotesCard> {
  // Same design tokens as UploadCard
  static const _accentBlue = Color(0xFF3B82F6);
  static const _accentCyan = Color(0xFF00D9FF);

  bool _isGenerating = false;
  String _statusMessage = '';
  final GeminiOcrService _ocrService = GeminiOcrService();
  final ExamNotesRepository _notesRepo = ExamNotesRepository();
  final ImagePicker _picker = ImagePicker();

  Future<void> _showTopicsInputDialog() async {
    final controller = TextEditingController();

    final topics = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.edit_note_rounded, color: _accentBlue),
            SizedBox(width: 12),
            Text(
              'Enter Your Topics',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Type or paste your syllabus topics, chapter names, or subjects.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: 6,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText:
                      'e.g.\nChapter 1: OOP Concepts\nChapter 2: Inheritance & Polymorphism\nChapter 3: Exception Handling',
                  hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.25),
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: _accentBlue,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          FilledButton.icon(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.of(context).pop(controller.text.trim());
              }
            },
            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
            label: const Text('Generate Notes'),
            style: FilledButton.styleFrom(
              backgroundColor: _accentBlue,
            ),
          ),
        ],
      ),
    );

    if (topics != null && topics.isNotEmpty) {
      _generateNotes(topics);
    }
  }

  // ==================== SCAN SYLLABUS BOTTOM SHEET ====================
  void _showScanOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131B2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Upload Syllabus",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Choose how to import your syllabus",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),
              _buildOptionTile(
                icon: Icons.picture_as_pdf_rounded,
                color: const Color(0xFFEF4444),
                title: "Upload PDF",
                subtitle: "Select a syllabus PDF file",
                onTap: () {
                  Navigator.pop(context);
                  _pickPdf();
                },
              ),
              const SizedBox(height: 12),
              _buildOptionTile(
                icon: Icons.photo_library_rounded,
                color: const Color(0xFF10B981),
                title: "Upload Image",
                subtitle: "Pick from gallery",
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 12),
              _buildOptionTile(
                icon: Icons.camera_alt_rounded,
                color: _accentBlue,
                title: "Take Photo",
                subtitle: "Capture with camera",
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white.withOpacity(0.2),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== PDF UPLOAD ====================
  Future<void> _pickPdf() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null || result.files.isEmpty || result.files.single.path == null) return;

      final pdfPath = result.files.single.path!;

      setState(() {
        _isGenerating = true;
        _statusMessage = 'Reading PDF pages...';
      });

      // Render all PDF pages first, then OCR in parallel batches
      final document = await pdfx.PdfDocument.openFile(pdfPath);
      final pageCount = document.pagesCount;
      final maxPages = pageCount > 10 ? 10 : pageCount; // Limit to 10 pages

      final tempDir = await getTemporaryDirectory();
      final List<File> pageImageFiles = [];

      // Phase 1: Render all pages to images (sequential — required by pdfx)
      for (int i = 1; i <= maxPages; i++) {
        if (mounted) {
          setState(() {
            _statusMessage = 'Rendering page $i of $maxPages...';
          });
        }

        final page = await document.getPage(i);
        final pageImage = await page.render(
          width: page.width * 2,
          height: page.height * 2,
          format: pdfx.PdfPageImageFormat.png,
        );

        if (pageImage != null) {
          final imageFile = File('${tempDir.path}/syllabus_page_$i.png');
          await imageFile.writeAsBytes(pageImage.bytes);
          pageImageFiles.add(imageFile);
        }

        await page.close();
      }

      await document.close();

      if (pageImageFiles.isEmpty) {
        if (mounted) {
          setState(() { _isGenerating = false; _statusMessage = ''; });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not render PDF pages. Try a different file.')),
          );
        }
        return;
      }

      // Phase 2: OCR all pages in parallel batches (3 at a time)
      if (mounted) {
        setState(() {
          _statusMessage = 'Extracting text from ${pageImageFiles.length} pages...';
        });
      }

      final pageTexts = await _ocrService.extractTextFromImagesBatch(
        pageImageFiles,
        batchSize: 3,
        onProgress: (completed, total) {
          if (mounted) {
            setState(() {
              _statusMessage = 'Reading page $completed of $total...';
            });
          }
        },
      );

      // Build combined text
      final StringBuffer allText = StringBuffer();
      for (final text in pageTexts) {
        if (text.isNotEmpty) {
          allText.writeln(text);
          allText.writeln();
        }
      }

      // Clean up temp files
      for (final file in pageImageFiles) {
        try { await file.delete(); } catch (_) {}
      }

      final extractedText = allText.toString().trim();

      if (extractedText.isEmpty) {
        if (mounted) {
          setState(() { _isGenerating = false; _statusMessage = ''; });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not extract text from PDF. Try a different file.')),
          );
        }
        return;
      }

      _generateNotes(extractedText);
    } catch (e) {
      if (mounted) {
        setState(() { _isGenerating = false; _statusMessage = ''; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error reading PDF: $e')),
        );
      }
    }
  }

  // ==================== IMAGE / CAMERA ====================
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 100,
        maxWidth: 2000,
        maxHeight: 2000,
      );

      if (pickedFile == null) return;

      setState(() {
        _isGenerating = true;
        _statusMessage = 'Reading your syllabus...';
      });

      final extractedText =
          await _ocrService.extractTextFromImage(File(pickedFile.path));

      if (extractedText.isEmpty) {
        if (mounted) {
          setState(() { _isGenerating = false; _statusMessage = ''; });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No text found in the image. Try again.')),
          );
        }
        return;
      }

      _generateNotes(extractedText);
    } catch (e) {
      if (mounted) {
        setState(() { _isGenerating = false; _statusMessage = ''; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _generateNotes(String topics) async {
    setState(() {
      _isGenerating = true;
      _statusMessage = 'Generating exam notes...';
    });

    try {
      final result = await _ocrService.generateExamNotes(topics);
      final notesMarkdown = result['notes'] as String;
      final questions = (result['questions'] as List).cast<Map<String, dynamic>>();
      final autoTitle = result['title'] as String? ?? topics;

      // Save to Firestore with AI-generated title
      final User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        setState(() {
          _statusMessage = 'Finalizing your notes...';
        });
        await _notesRepo.saveExamNotes(
          userId: user.uid,
          topics: autoTitle,
          notesMarkdown: notesMarkdown,
          questions: questions,
        );
      }

      if (mounted) {
        setState(() {
          _isGenerating = false;
          _statusMessage = '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _statusMessage = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate notes: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _accentBlue.withOpacity(0.12),
              _accentCyan.withOpacity(0.05),
            ],
          ),
          border: Border.all(color: _accentBlue.withOpacity(0.2)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row — same structure as UploadCard
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _accentBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          _isGenerating
                              ? Icons.sync_rounded
                              : Icons.school_rounded,
                          color: _accentBlue,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isGenerating
                                  ? _statusMessage
                                  : "Exam Notes Generator",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isGenerating
                                  ? "AI is crafting your study material"
                                  : "Type topics or scan your syllabus",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Loading or buttons — same structure as UploadCard
                  if (_isGenerating) ...[
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _accentBlue,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _statusMessage,
                          style: TextStyle(
                            color: _accentBlue.withOpacity(0.8),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    const SizedBox(height: 20),
                    // Two action buttons in a row using PrimaryButton
                    Row(
                      children: [
                        Expanded(
                          child: PrimaryButton(
                            text: "Type Topics",
                            onPressed: _showTopicsInputDialog,
                            icon: Icons.edit_note_rounded,
                            height: 45,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: PrimaryButton(
                            text: "Scan Syllabus",
                            onPressed: _showScanOptions,
                            icon: Icons.document_scanner_rounded,
                            height: 45,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Footer — same structure as UploadCard
                  const SizedBox(height: 20),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 16),
                  const Text(
                    "AI GENERATED CONTENT",
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.0,
                      color: _accentBlue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _insightFeature(Icons.description_rounded, "Exam Notes"),
                      _insightFeature(Icons.quiz_rounded, "Practice Q&A"),
                      _insightFeature(Icons.lightbulb_rounded, "Key Concepts"),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _insightFeature(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: Colors.white60, size: 14),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
