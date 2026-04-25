import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdify/services/gemini_ocr_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:pdify/widgets/premium_header.dart';
import 'package:pdify/widgets/primary_button.dart';
import 'package:pdify/widgets/glass_card.dart';
import 'package:pdify/widgets/mesh_background_scaffold.dart';
import 'package:pdify/services/ad_service.dart';

class OcrScreen extends StatefulWidget {
  const OcrScreen({super.key});

  @override
  State<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends State<OcrScreen> {
  final ImagePicker _picker = ImagePicker();
  final GeminiOcrService _ocrService = GeminiOcrService();
  
  File? _image;
  String? _extractedText;
  bool _isProcessing = false;

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 100,
        maxWidth: 2000,
        maxHeight: 2000,
      );
      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
          _extractedText = null;
        });
        _processImage(_image!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _processImage(File image) async {
    setState(() => _isProcessing = true);
    
    try {
      final text = await _ocrService.extractTextFromImage(image);
      
      setState(() {
        _extractedText = text.isEmpty ? null : text;
      });
      
      AdService().showInterstitialAd();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error recognizing text: $e')),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _copyText() async {
    if (_extractedText != null && _extractedText!.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: _extractedText!));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Text copied to clipboard!')),
        );
      }
    }
  }

  Future<void> _shareText() async {
    if (_extractedText != null && _extractedText!.isNotEmpty) {
      await Share.share(_extractedText!);
    }
  }

  Future<void> _saveAsPdf() async {
    if (_extractedText == null || _extractedText!.isEmpty) return;

    setState(() => _isProcessing = true);
    try {
      final pdf = pw.Document();
      
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            pw.Text(
              _extractedText!,
              style: const pw.TextStyle(fontSize: 14),
            ),
          ],
        ),
      );

      final appDir = await getApplicationDocumentsDirectory();
      final pdifyDir = Directory('${appDir.path}/PDify/PDFs');
      if (!await pdifyDir.exists()) {
        await pdifyDir.create(recursive: true);
      }
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${pdifyDir.path}/OCR_Document_$timestamp.pdf';
      final file = File(outputPath);
      await file.writeAsBytes(await pdf.save());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved locally as PDF!'),
            action: SnackBarAction(
              label: 'Share',
              onPressed: () {
                Share.shareXFiles([XFile(outputPath)], text: "Shared via PDify");
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving PDF: $e')),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MeshBackgroundScaffold(
      showAppBar: false,
      body: SafeArea(
        child: Column(
          children: [
            PremiumHeader(
              title: "Image to Text",
              onProfileTap: () {},
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Image Section
                    GlassCard(
                      borderRadius: 20,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            if (_image != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(_image!, height: 200, fit: BoxFit.cover, width: double.infinity),
                              )
                            else
                              Container(
                                height: 200,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                                ),
                                child: const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.document_scanner_rounded, size: 48, color: Colors.blue),
                                      SizedBox(height: 12),
                                      Text(
                                        "No image selected",
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: PrimaryButton(
                                    text: "Camera",
                                    icon: Icons.camera_alt_rounded,
                                    onPressed: () => _pickImage(ImageSource.camera),
                                    backgroundColor: const Color(0xFF3B82F6),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: PrimaryButton(
                                    text: "Gallery",
                                    icon: Icons.photo_library_rounded,
                                    onPressed: () => _pickImage(ImageSource.gallery),
                                    backgroundColor: const Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    // Tips Section
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withOpacity(0.2)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.lightbulb_outline_rounded, color: Colors.blue, size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Tip: Keep the camera steady, ensure good lighting, and avoid rotating the paper for best results.",
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Result Section
                    if (_isProcessing)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_extractedText != null) ...[
                      const Text(
                        "Extracted Text",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      GlassCard(
                        borderRadius: 16,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: SelectableText(
                            _extractedText!.isEmpty ? "No text found in image." : _extractedText!,
                            style: const TextStyle(color: Colors.white, height: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_extractedText!.isNotEmpty)
                        Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: PrimaryButton(
                                text: "Copy",
                                icon: Icons.copy_rounded,
                                onPressed: _copyText,
                                backgroundColor: const Color(0xFF64748B),
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              flex: 1,
                              child: PrimaryButton(
                                text: "Share",
                                icon: Icons.share_rounded,
                                onPressed: _shareText,
                                backgroundColor: const Color(0xFFF59E0B),
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              flex: 1,
                              child: PrimaryButton(
                                text: "To PDF",
                                icon: Icons.picture_as_pdf_rounded,
                                onPressed: _saveAsPdf,
                                backgroundColor: const Color(0xFFEC4899),
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                    ],
                    
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
}
