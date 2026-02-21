import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import 'package:pdf_manipulator/pdf_manipulator.dart';
import 'package:pdify/ad_service.dart';
import 'package:pdify/conversion_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:share_plus/share_plus.dart';
import 'package:pdify/widgets/glass_card.dart';
import 'package:pdify/widgets/primary_button.dart';
import 'package:pdify/widgets/mesh_background_scaffold.dart';

class ConvertScreen extends StatefulWidget {
  const ConvertScreen({super.key});

  @override
  State<ConvertScreen> createState() => _ConvertScreenState();
}

class _ConvertScreenState extends State<ConvertScreen> {
  bool _isProcessing = false;
  String? _statusMessage;
  bool _isSuccess = false;
  List<String> _shareablePaths = [];

  // ==================== DIRECTORIES ====================

  Future<Directory> _getPdfsDirectory() async {
    final baseDir = Directory('/storage/emulated/0/Download/PDify/PDFs');
    if (!await baseDir.exists()) {
      await baseDir.create(recursive: true);
    }
    return baseDir;
  }

  Future<Directory> _getImagesDirectory() async {
    final baseDir = Directory('/storage/emulated/0/Download/PDify/Images');
    if (!await baseDir.exists()) {
      await baseDir.create(recursive: true);
    }
    return baseDir;
  }

  Future<Directory> _getDocsDirectory() async {
    final baseDir = Directory('/storage/emulated/0/Download/PDify/Documents');
    if (!await baseDir.exists()) {
      await baseDir.create(recursive: true);
    }
    return baseDir;
  }

  // ==================== DIALOGS ====================

  Future<String?> _showFileNameDialog({
    required String defaultName,
    required int fileCount,
    String suffix = '.pdf',
    String buttonLabel = 'Create PDF',
  }) async {
    final controller = TextEditingController(text: defaultName);

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.edit_document, color: Color(0xFF7C3AED)),
            const SizedBox(width: 12),
            Text(suffix == '.pdf' ? 'Name your PDF' : 'Name your file'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$fileCount file${fileCount > 1 ? 's' : ''} selected',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'File name',
                hintText: 'Enter name',
                suffixText: suffix,
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
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }

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

  // ==================== MERGE PDF ====================
  Future<void> _mergePdf() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
      );

      if (result == null || result.files.length < 2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select at least 2 PDFs to merge.'),
            ),
          );
        }
        return;
      }

      final paths = result.files
          .where((f) => f.path != null)
          .map((f) => f.path!)
          .toList();
      if (paths.length < 2) return;

      final fileName = await _showFileNameDialog(
        defaultName: 'Merged_Document',
        fileCount: paths.length,
        buttonLabel: 'Merge',
      );
      if (fileName == null) return;

      setState(() {
        _isProcessing = true;
        _statusMessage = "Merging ${paths.length} PDFs...";
        _isSuccess = false;
      });

      final mergedPath = await PdfManipulator().mergePDFs(
        params: PDFMergerParams(pdfsPaths: paths),
      );

      if (mergedPath != null) {
        final outputDir = await _getPdfsDirectory();
        final safeName = fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
        final outputPath = '${outputDir.path}/$safeName.pdf';
        await File(mergedPath).copy(outputPath);

        setState(() {
          _isProcessing = false;
          _isSuccess = true;
          _statusMessage = "Merged PDF saved!\n$outputPath";
          _shareablePaths = [outputPath];
        });
      } else {
        setState(() {
          _isProcessing = false;
          _isSuccess = false;
          _statusMessage = "Merge failed. Please try again.";
        });
      }

      AdService().showInterstitialAd();
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _isSuccess = false;
        _statusMessage = "Error: $e";
      });
    }
  }

  // ==================== SPLIT PDF ====================
  Future<void> _splitPdf() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null ||
          result.files.isEmpty ||
          result.files.single.path == null)
        return;

      final pdfPath = result.files.single.path!;

      // Get page count for info
      final document = await pdfx.PdfDocument.openFile(pdfPath);
      final pageCount = document.pagesCount;
      await document.close();

      if (pageCount < 2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF has only 1 page. Nothing to split.'),
            ),
          );
        }
        return;
      }

      // Ask user for split point
      final splitPage = await _showSplitDialog(pageCount);
      if (splitPage == null) return;

      setState(() {
        _isProcessing = true;
        _statusMessage = "Splitting PDF at page $splitPage...";
        _isSuccess = false;
      });

      final outputDir = await _getPdfsDirectory();
      final baseName = result.files.single.name.replaceAll('.pdf', '');
      final List<String> savedPaths = [];

      // Use pageRanges to split into 2 parts
      final pageRange1 = "1-$splitPage";
      final pageRange2 = "${splitPage + 1}-$pageCount";

      final splitPaths = await PdfManipulator().splitPDF(
        params: PDFSplitterParams(
          pdfPath: pdfPath,
          pageRanges: [pageRange1, pageRange2],
        ),
      );

      if (splitPaths != null && splitPaths.isNotEmpty) {
        for (int i = 0; i < splitPaths.length; i++) {
          final outPath = '${outputDir.path}/${baseName}_part${i + 1}.pdf';
          await File(splitPaths[i]).copy(outPath);
          savedPaths.add(outPath);
        }
      }

      setState(() {
        _isProcessing = false;
        _isSuccess = savedPaths.isNotEmpty;
        _statusMessage = savedPaths.isNotEmpty
            ? "Split into ${savedPaths.length} parts!\n${outputDir.path}"
            : "Split failed.";
        _shareablePaths = savedPaths;
      });

      AdService().showInterstitialAd();
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _isSuccess = false;
        _statusMessage = "Error: $e";
      });
    }
  }

  Future<int?> _showSplitDialog(int totalPages) {
    int selectedPage = (totalPages / 2).ceil();
    return showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.call_split_rounded, color: Color(0xFF7C3AED)),
              SizedBox(width: 12),
              Text('Split PDF'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Total pages: $totalPages',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              Text(
                'Split after page $selectedPage',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Slider(
                value: selectedPage.toDouble(),
                min: 1,
                max: (totalPages - 1).toDouble(),
                divisions: totalPages - 2 > 0 ? totalPages - 2 : 1,
                activeColor: const Color(0xFF7C3AED),
                label: '$selectedPage',
                onChanged: (val) {
                  setDialogState(() => selectedPage = val.round());
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Part 1: Pages 1–$selectedPage',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                  Text(
                    'Part 2: Pages ${selectedPage + 1}–$totalPages',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(selectedPage),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
              ),
              child: const Text('Split'),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== COMPRESS PDF ====================
  Future<void> _compressPdf() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null ||
          result.files.isEmpty ||
          result.files.single.path == null)
        return;

      final pdfPath = result.files.single.path!;
      final originalSize = File(pdfPath).lengthSync();

      setState(() {
        _isProcessing = true;
        _statusMessage = "Compressing PDF...";
        _isSuccess = false;
      });

      final compressedPath = await PdfManipulator().pdfCompressor(
        params: PDFCompressorParams(
          pdfPath: pdfPath,
          imageQuality: 50,
          imageScale: 0.5,
        ),
      );

      if (compressedPath != null) {
        final compressedSize = File(compressedPath).lengthSync();
        final savings = ((1 - compressedSize / originalSize) * 100)
            .toStringAsFixed(1);

        final outputDir = await _getPdfsDirectory();
        final baseName = result.files.single.name.replaceAll('.pdf', '');
        final outputPath = '${outputDir.path}/${baseName}_compressed.pdf';
        await File(compressedPath).copy(outputPath);

        setState(() {
          _isProcessing = false;
          _isSuccess = true;
          _statusMessage =
              "Compressed! Saved $savings%\n${_formatBytes(originalSize)} → ${_formatBytes(compressedSize)}\n$outputPath";
          _shareablePaths = [outputPath];
        });
      } else {
        setState(() {
          _isProcessing = false;
          _isSuccess = false;
          _statusMessage = "Compression failed.";
        });
      }

      AdService().showInterstitialAd();
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _isSuccess = false;
        _statusMessage = "Error: $e";
      });
    }
  }

  // ==================== COMPRESS IMAGE ====================
  Future<void> _compressImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) return;

      setState(() {
        _isProcessing = true;
        _statusMessage = "Compressing ${result.files.length} image(s)...";
        _isSuccess = false;
      });

      final outputDir = await _getImagesDirectory();
      final List<String> savedPaths = [];
      int totalOriginal = 0;
      int totalCompressed = 0;

      for (var file in result.files) {
        if (file.path == null) continue;
        final originalFile = File(file.path!);
        totalOriginal += originalFile.lengthSync();

        final compressedFile = await FlutterImageCompress.compressAndGetFile(
          file.path!,
          '${outputDir.path}/compressed_${file.name}',
          quality: 50,
          minWidth: 1920,
          minHeight: 1080,
        );

        if (compressedFile != null) {
          final compressedSize = await compressedFile.length();
          totalCompressed += compressedSize;
          savedPaths.add(compressedFile.path);
        }
      }

      final savings = totalOriginal > 0
          ? ((1 - totalCompressed / totalOriginal) * 100).toStringAsFixed(1)
          : '0';

      setState(() {
        _isProcessing = false;
        _isSuccess = savedPaths.isNotEmpty;
        _statusMessage = savedPaths.isNotEmpty
            ? "Compressed ${savedPaths.length} image(s)! Saved $savings%\n${_formatBytes(totalOriginal)} → ${_formatBytes(totalCompressed)}\n${outputDir.path}"
            : "Compression failed.";
        _shareablePaths = savedPaths;
      });

      AdService().showInterstitialAd();
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _isSuccess = false;
        _statusMessage = "Error: $e";
      });
    }
  }

  // ==================== IMAGE → PDF ====================
  Future<void> _imagesToPdf() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) return;

      final fileName = await _showFileNameDialog(
        defaultName: 'My_Document',
        fileCount: result.files.length,
      );
      if (fileName == null) return;

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

        final buffer = await ui.ImmutableBuffer.fromUint8List(imageBytes);
        final descriptor = await ui.ImageDescriptor.encoded(buffer);
        final imgWidth = descriptor.width.toDouble();
        final imgHeight = descriptor.height.toDouble();
        descriptor.dispose();

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(imgWidth, imgHeight),
            margin: pw.EdgeInsets.zero,
            build: (pw.Context context) {
              return pw.Image(image, fit: pw.BoxFit.cover);
            },
          ),
        );
      }

      final outputDir = await _getPdfsDirectory();
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

      final imageName = await _showImageNameDialog(
        defaultName: 'Page',
        pageCount: pageCount,
      );

      if (imageName == null) {
        await document.close();
        return;
      }

      setState(() {
        _isProcessing = true;
        _statusMessage = "Extracting images...";
        _isSuccess = false;
      });

      final outputDir = await _getImagesDirectory();
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

      AdService().showInterstitialAd();
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _isSuccess = false;
        _statusMessage = "Error: $e";
      });
    }
  }

  // ==================== WORD → PDF ====================
  Future<void> _wordToPdf() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['docx', 'doc'],
      );

      if (result == null ||
          result.files.isEmpty ||
          result.files.single.path == null)
        return;

      final filePath = result.files.single.path!;
      final originalName = result.files.single.name;
      final defaultName = originalName.replaceAll(
        RegExp(r'\.docx?$', caseSensitive: false),
        '',
      );

      final fileName = await _showFileNameDialog(
        defaultName: defaultName,
        fileCount: 1,
        suffix: '.pdf',
        buttonLabel: 'Convert',
      );

      if (fileName == null) return;

      setState(() {
        _isProcessing = true;
        _statusMessage = "Converting Word to PDF...";
        _isSuccess = false;
      });

      final outputDir = await _getPdfsDirectory();
      final outputPath = await ConversionService().convertToPdf(
        inputFilePath: filePath,
        outputDir: outputDir.path,
        newFileName: fileName,
      );

      setState(() {
        _isProcessing = false;
        _isSuccess = outputPath != null;
        _statusMessage = outputPath != null
            ? "PDF saved!\n$outputPath"
            : "Conversion failed.";
        _shareablePaths = outputPath != null ? [outputPath] : [];
      });

      AdService().showInterstitialAd();
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _isSuccess = false;
        _statusMessage = "Error: $e";
      });
    }
  }

  // ==================== PPT → PDF ====================
  Future<void> _pptToPdf() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pptx', 'ppt'],
      );

      if (result == null ||
          result.files.isEmpty ||
          result.files.single.path == null)
        return;

      final filePath = result.files.single.path!;
      final originalName = result.files.single.name;
      final defaultName = originalName.replaceAll(
        RegExp(r'\.pptx?$', caseSensitive: false),
        '',
      );

      final fileName = await _showFileNameDialog(
        defaultName: defaultName,
        fileCount: 1,
        suffix: '.pdf',
        buttonLabel: 'Convert',
      );

      if (fileName == null) return;

      setState(() {
        _isProcessing = true;
        _statusMessage = "Converting PowerPoint to PDF...";
        _isSuccess = false;
      });

      final outputDir = await _getPdfsDirectory();
      final outputPath = await ConversionService().convertToPdf(
        inputFilePath: filePath,
        outputDir: outputDir.path,
        newFileName: fileName,
      );

      setState(() {
        _isProcessing = false;
        _isSuccess = outputPath != null;
        _statusMessage = outputPath != null
            ? "PDF saved!\n$outputPath"
            : "Conversion failed.";
        _shareablePaths = outputPath != null ? [outputPath] : [];
      });

      AdService().showInterstitialAd();
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _isSuccess = false;
        _statusMessage = "Error: $e";
      });
    }
  }

  // ==================== PDF → WORD ====================
  Future<void> _pdfToWord() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null ||
          result.files.isEmpty ||
          result.files.single.path == null)
        return;

      final filePath = result.files.single.path!;
      final originalName = result.files.single.name;
      final defaultName = originalName.replaceAll(
        RegExp(r'\.pdf$', caseSensitive: false),
        '',
      );

      final fileName = await _showFileNameDialog(
        defaultName: defaultName,
        fileCount: 1,
        suffix: '.docx',
        buttonLabel: 'Convert',
      );

      if (fileName == null) return;

      setState(() {
        _isProcessing = true;
        _statusMessage = "Converting PDF to Word...";
        _isSuccess = false;
      });

      final outputDir = await _getDocsDirectory();
      final outputPath = await ConversionService().convertFromPdf(
        inputFilePath: filePath,
        outputDir: outputDir.path,
        outputFormat: 'docx',
        newFileName: fileName,
      );

      setState(() {
        _isProcessing = false;
        _isSuccess = outputPath != null;
        _statusMessage = outputPath != null
            ? "Word file saved!\n$outputPath"
            : "Conversion failed.";
        _shareablePaths = outputPath != null ? [outputPath] : [];
      });

      AdService().showInterstitialAd();
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _isSuccess = false;
        _statusMessage = "Error: $e";
      });
    }
  }

  // ==================== PDF → PPT ====================
  Future<void> _pdfToPpt() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null ||
          result.files.isEmpty ||
          result.files.single.path == null)
        return;

      final filePath = result.files.single.path!;
      final originalName = result.files.single.name;
      final defaultName = originalName.replaceAll(
        RegExp(r'\.pdf$', caseSensitive: false),
        '',
      );

      final fileName = await _showFileNameDialog(
        defaultName: defaultName,
        fileCount: 1,
        suffix: '.pptx',
        buttonLabel: 'Convert',
      );

      if (fileName == null) return;

      setState(() {
        _isProcessing = true;
        _statusMessage = "Converting PDF to PowerPoint...";
        _isSuccess = false;
      });

      final outputDir = await _getDocsDirectory();
      final outputPath = await ConversionService().convertFromPdf(
        inputFilePath: filePath,
        outputDir: outputDir.path,
        outputFormat: 'pptx',
        newFileName: fileName,
      );

      setState(() {
        _isProcessing = false;
        _isSuccess = outputPath != null;
        _statusMessage = outputPath != null
            ? "PowerPoint file saved!\n$outputPath"
            : "Conversion failed.";
        _shareablePaths = outputPath != null ? [outputPath] : [];
      });

      AdService().showInterstitialAd();
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _isSuccess = false;
        _statusMessage = "Error: $e";
      });
    }
  }

  // ==================== HELPERS ====================
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Design Tokens
    // const color1 = Color(0xFF7C3AED); // Vivid Purple
    // const color2 = Color(0xFFFF6B6B); // Coral Red
    // const color3 = Color(0xFF00D9FF); // Cyan

    // Feature definitions
    final features = [
      _FeatureTile(
        icon: Icons.merge_rounded,
        title: 'Merge PDF',
        description: 'Combine multiple PDFs into one',
        color: const Color(0xFF7C3AED),
        onTap: _isProcessing ? null : _mergePdf,
      ),
      _FeatureTile(
        icon: Icons.call_split_rounded,
        title: 'Split PDF',
        description: 'Separate pages from a PDF',
        color: const Color(0xFF10B981),
        onTap: _isProcessing ? null : _splitPdf,
      ),
      _FeatureTile(
        icon: Icons.compress_rounded,
        title: 'Compress PDF',
        description: 'Reduce PDF file size',
        color: const Color(0xFFFF6B6B),
        onTap: _isProcessing ? null : _compressPdf,
      ),
      _FeatureTile(
        icon: Icons.photo_size_select_large_rounded,
        title: 'Compress Image',
        description: 'Compress JPG & PNG images',
        color: const Color(0xFFF59E0B),
        onTap: _isProcessing ? null : _compressImage,
      ),
      _FeatureTile(
        icon: Icons.image_rounded,
        title: 'Images to PDF',
        description: 'Combine images into a PDF',
        color: const Color(0xFF3B82F6),
        onTap: _isProcessing ? null : _imagesToPdf,
      ),
      _FeatureTile(
        icon: Icons.picture_as_pdf_rounded,
        title: 'PDF to Images',
        description: 'Extract pages as images',
        color: const Color(0xFFEC4899),
        onTap: _isProcessing ? null : _pdfToImages,
      ),
      _FeatureTile(
        icon: Icons.description_rounded,
        title: 'Word to PDF',
        description: 'Convert DOCX to PDF',
        color: const Color(0xFF2563EB),
        onTap: _isProcessing ? null : _wordToPdf,
      ),
      _FeatureTile(
        icon: Icons.slideshow_rounded,
        title: 'PPT to PDF',
        description: 'Convert PPTX to PDF',
        color: const Color(0xFFDC2626),
        onTap: _isProcessing ? null : _pptToPdf,
      ),
      _FeatureTile(
        icon: Icons.article_rounded,
        title: 'PDF to Word',
        description: 'Convert PDF to DOCX',
        color: const Color(0xFF0891B2),
        onTap: _isProcessing ? null : _pdfToWord,
      ),
      _FeatureTile(
        icon: Icons.present_to_all_rounded,
        title: 'PDF to PPT',
        description: 'Convert PDF to PPTX',
        color: const Color(0xFFE11D48),
        onTap: _isProcessing ? null : _pdfToPpt,
      ),
    ];

    return MeshBackgroundScaffold(
      title: 'Tools',
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Grid of feature tiles
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: features.length,
                  itemBuilder: (context, index) {
                    final f = features[index];
                    return _buildGridTile(f, theme);
                  },
                ),

                const SizedBox(height: 16),

                // Status Display
                if (_isProcessing || _statusMessage != null)
                  _buildStatusCard(theme),
              ],
            ),
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

  Widget _buildGridTile(_FeatureTile feature, ThemeData theme) {
    return GestureDetector(
      onTap: feature.onTap,
      child: GlassCard(
        borderRadius: 20,
        blur: 15,
        opacity: 0.6,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: feature.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(feature.icon, color: feature.color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              feature.title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              feature.description,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(ThemeData theme) {
    final statusColor = _isProcessing
        ? const Color(0xFF7C3AED)
        : _isSuccess
        ? const Color(0xFF10B981)
        : const Color(0xFFEF4444);

    return GlassCard(
      borderRadius: 16,
      child: Column(
        children: [
          Row(
            children: [
              if (_isProcessing)
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: statusColor,
                  ),
                )
              else
                Icon(
                  _isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
                  color: statusColor,
                  size: 24,
                ),
              const SizedBox(width: 16),
              Expanded(
                child: SelectableText(
                  _statusMessage ?? "",
                  style: TextStyle(
                    fontSize: 14,
                    color: statusColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (_isSuccess && _shareablePaths.isNotEmpty) ...[
            const SizedBox(height: 16),
            PrimaryButton(
              text: _shareablePaths.length == 1
                  ? 'Share File'
                  : 'Share ${_shareablePaths.length} Files',
              onPressed: _shareFiles,
              icon: Icons.share_rounded,
              backgroundColor: const Color(0xFF10B981),
              width: double.infinity,
            ),
          ],
        ],
      ),
    );
  }

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

class _FeatureTile {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback? onTap;

  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });
}
