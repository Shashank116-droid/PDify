import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdify/ad_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:share_plus/share_plus.dart';

class ConvertScreen extends StatefulWidget {
  const ConvertScreen({super.key});

  @override
  State<ConvertScreen> createState() => _ConvertScreenState();
}

class _ConvertScreenState extends State<ConvertScreen> {
  bool _isProcessing = false;
  String? _statusMessage;
  bool _isSuccess = false;
  List<String> _shareablePaths = []; // Paths for sharing

  /// Gets the PDify/PDFs directory for converted PDFs
  Future<Directory> _getPdfsDirectory() async {
    final baseDir = Directory('/storage/emulated/0/Download/PDify/PDFs');
    if (!await baseDir.exists()) {
      await baseDir.create(recursive: true);
    }
    return baseDir;
  }

  /// Gets the PDify/Images directory for extracted images
  Future<Directory> _getImagesDirectory() async {
    final baseDir = Directory('/storage/emulated/0/Download/PDify/Images');
    if (!await baseDir.exists()) {
      await baseDir.create(recursive: true);
    }
    return baseDir;
  }

  /// Shows a dialog to get custom filename from user
  Future<String?> _showFileNameDialog({
    required String defaultName,
    required int fileCount,
  }) async {
    final controller = TextEditingController(text: defaultName);

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.edit_document, color: Color(0xFF7C3AED)),
            SizedBox(width: 12),
            Text('Name your PDF'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$fileCount image${fileCount > 1 ? 's' : ''} selected',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'File name',
                hintText: 'Enter PDF name',
                suffixText: '.pdf',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF7C3AED),
                    width: 2,
                  ),
                ),
              ),
              onSubmitted: (value) {
                Navigator.of(context).pop(value.isEmpty ? defaultName : value);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.isEmpty
                  ? defaultName
                  : controller.text;
              Navigator.of(context).pop(name);
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
            ),
            child: const Text('Create PDF'),
          ),
        ],
      ),
    );
  }

  /// Shows a dialog to get image prefix name from user
  Future<String?> _showImageNameDialog({
    required String defaultName,
    required int pageCount,
  }) async {
    final controller = TextEditingController(text: defaultName);

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.image_rounded, color: Color(0xFF7C3AED)),
            SizedBox(width: 12),
            Text('Name your images'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$pageCount page${pageCount > 1 ? 's' : ''} will be extracted',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Image prefix',
                hintText: 'Enter name prefix',
                suffixText: '_1.png',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF7C3AED),
                    width: 2,
                  ),
                ),
              ),
              onSubmitted: (value) {
                Navigator.of(context).pop(value.isEmpty ? defaultName : value);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.isEmpty
                  ? defaultName
                  : controller.text;
              Navigator.of(context).pop(name);
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
            ),
            child: const Text('Extract Images'),
          ),
        ],
      ),
    );
  }

  // ==================== IMAGE → PDF ====================
  Future<void> _imagesToPdf() async {
    try {
      // Pick multiple images
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) return;

      // Show dialog to get filename
      final fileName = await _showFileNameDialog(
        defaultName: 'My_Document',
        fileCount: result.files.length,
      );

      if (fileName == null) return; // User cancelled

      setState(() {
        _isProcessing = true;
        _statusMessage = "Creating PDF...";
        _isSuccess = false;
      });

      final pdf = pw.Document();

      for (var file in result.files) {
        if (file.path == null) continue;

        final imageBytes = await File(file.path!).readAsBytes();
        final image = pw.MemoryImage(imageBytes);

        // Decode image to get dimensions using ImmutableBuffer
        final buffer = await ui.ImmutableBuffer.fromUint8List(imageBytes);
        final descriptor = await ui.ImageDescriptor.encoded(buffer);
        final imgWidth = descriptor.width.toDouble();
        final imgHeight = descriptor.height.toDouble();
        descriptor.dispose();

        pdf.addPage(
          pw.Page(
            // Use image dimensions as page size (no white borders)
            pageFormat: PdfPageFormat(imgWidth, imgHeight),
            margin: pw.EdgeInsets.zero,
            build: (pw.Context context) {
              return pw.Image(image, fit: pw.BoxFit.cover);
            },
          ),
        );
      }

      // Save PDF to PDify/PDFs folder with custom name
      final outputDir = await _getPdfsDirectory();
      // Sanitize filename (remove invalid characters)
      final safeName = fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final outputPath = '${outputDir.path}/$safeName.pdf';
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(await pdf.save());

      setState(() {
        _isProcessing = false;
        _isSuccess = true;
        _statusMessage = "PDF saved!\n$outputPath";
        _shareablePaths = [outputPath];
      });

      // Show interstitial ad after conversion
      AdService().showInterstitialAd();
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _isSuccess = false;
        _statusMessage = "Error: $e";
      });
    }
  }

  // ==================== PDF → IMAGES ====================
  Future<void> _pdfToImages() async {
    try {
      // Pick a single PDF
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null ||
          result.files.isEmpty ||
          result.files.single.path == null) {
        return;
      }

      final pdfPath = result.files.single.path!;
      final document = await pdfx.PdfDocument.openFile(pdfPath);
      final pageCount = document.pagesCount;

      // Show dialog to get image prefix name
      final imageName = await _showImageNameDialog(
        defaultName: 'Page',
        pageCount: pageCount,
      );

      if (imageName == null) {
        await document.close();
        return; // User cancelled
      }

      setState(() {
        _isProcessing = true;
        _statusMessage = "Extracting images...";
        _isSuccess = false;
      });

      // Save images to PDify/Images folder
      final outputDir = await _getImagesDirectory();
      // Sanitize filename
      final safeName = imageName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final List<String> savedPaths = [];

      for (int i = 1; i <= pageCount; i++) {
        final page = await document.getPage(i);
        final pageImage = await page.render(
          width: page.width * 2,
          height: page.height * 2,
          format: pdfx.PdfPageImageFormat.png,
        );

        if (pageImage != null) {
          final imagePath = '${outputDir.path}/${safeName}_$i.png';
          final imageFile = File(imagePath);
          await imageFile.writeAsBytes(pageImage.bytes);
          savedPaths.add(imagePath);
        }

        await page.close();
      }

      await document.close();

      setState(() {
        _isProcessing = false;
        _isSuccess = true;
        _statusMessage =
            "Saved ${savedPaths.length} images!\n${outputDir.path}";
        _shareablePaths = savedPaths;
      });

      // Show interstitial ad after conversion
      AdService().showInterstitialAd();
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _isSuccess = false;
        _statusMessage = "Error: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Gradient Mesh Colors (matching home_screen.dart)
    const color1 = Color(0xFF7C3AED); // Vivid Purple
    const color2 = Color(0xFFFF6B6B); // Coral Red
    const color3 = Color(0xFF00D9FF); // Cyan

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.transform_rounded, color: Color(0xFF7C3AED)),
            const SizedBox(width: 8),
            Text(
              "Convert",
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF7C3AED),
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
          Positioned(top: -80, right: -60, child: _buildMeshBlob(color1, 280)),
          Positioned(
            bottom: 100,
            left: -60,
            child: _buildMeshBlob(color2, 300),
          ),
          Positioned(
            bottom: -50,
            right: -40,
            child: _buildMeshBlob(color3, 250),
          ),

          // Blur overlay
          Positioned.fill(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: Container(color: Colors.white.withValues(alpha: 0.3)),
            ),
          ),

          // --- Content ---
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Images → PDF Card
                  _buildConversionCard(
                    icon: Icons.image_rounded,
                    title: "Images to PDF",
                    description:
                        "Combine multiple images into a single PDF file",
                    buttonLabel: "Select Images",
                    onPressed: _isProcessing ? null : _imagesToPdf,
                    theme: theme,
                  ),

                  const SizedBox(height: 20),

                  // PDF → Images Card
                  _buildConversionCard(
                    icon: Icons.picture_as_pdf_rounded,
                    title: "PDF to Images",
                    description: "Extract each page of a PDF as an image",
                    buttonLabel: "Select PDF",
                    onPressed: _isProcessing ? null : _pdfToImages,
                    theme: theme,
                  ),

                  const SizedBox(height: 24),

                  // Status Display
                  if (_isProcessing || _statusMessage != null)
                    _buildStatusCard(theme),
                ],
              ),
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

  Widget _buildConversionCard({
    required IconData icon,
    required String title,
    required String description,
    required String buttonLabel,
    required VoidCallback? onPressed,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF7C3AED), size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.folder_open_rounded),
              label: Text(
                buttonLabel,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                disabledBackgroundColor: Colors.grey.shade300,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isProcessing
            ? const Color(0xFF7C3AED).withValues(alpha: 0.05)
            : _isSuccess
            ? const Color(0xFF10B981).withValues(alpha: 0.05)
            : const Color(0xFFEF4444).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isProcessing
              ? const Color(0xFF7C3AED).withValues(alpha: 0.2)
              : _isSuccess
              ? const Color(0xFF10B981).withValues(alpha: 0.2)
              : const Color(0xFFEF4444).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (_isProcessing)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFF7C3AED),
                  ),
                )
              else
                Icon(
                  _isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
                  color: _isSuccess
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444),
                  size: 24,
                ),
              const SizedBox(width: 16),
              Expanded(
                child: SelectableText(
                  _statusMessage ?? "",
                  style: TextStyle(
                    fontSize: 14,
                    color: _isProcessing
                        ? const Color(0xFF7C3AED)
                        : _isSuccess
                        ? const Color(0xFF047857)
                        : const Color(0xFFB91C1C),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          // Share button - shows only on success
          if (_isSuccess && _shareablePaths.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _shareFiles,
                icon: const Icon(Icons.share_rounded),
                label: Text(
                  _shareablePaths.length == 1
                      ? 'Share File'
                      : 'Share ${_shareablePaths.length} Files',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Shares the converted files
  Future<void> _shareFiles() async {
    if (_shareablePaths.isEmpty) return;

    try {
      final xFiles = _shareablePaths.map((path) => XFile(path)).toList();
      await Share.shareXFiles(xFiles, text: 'Shared via PDify 📄');
    } catch (e) {
      setState(() {
        _statusMessage = "Share failed: $e";
        _isSuccess = false;
      });
    }
  }
}
