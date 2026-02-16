import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

/// Service for converting documents via the Cloud Run LibreOffice service.
class ConversionService {
  static const String _baseUrl =
      'https://pdify-converter-z2x52vmfja-uc.a.run.app';

  static final ConversionService _instance = ConversionService._internal();
  factory ConversionService() => _instance;
  ConversionService._internal();

  /// Convert Word/PPT to PDF.
  /// Returns the path to the saved PDF file, or null on failure.
  Future<String?> convertToPdf({
    required String inputFilePath,
    required String outputDir,
  }) async {
    try {
      final file = File(inputFilePath);
      final fileName = path.basename(inputFilePath);
      final baseName = path.basenameWithoutExtension(inputFilePath);

      final uri = Uri.parse('$_baseUrl/convert/to-pdf');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          filename: fileName,
        ),
      );

      final response = await request.send().timeout(const Duration(minutes: 3));

      if (response.statusCode == 200) {
        final bytes = await response.stream.toBytes();
        final outputPath = '$outputDir/$baseName.pdf';
        await File(outputPath).writeAsBytes(bytes);
        return outputPath;
      } else {
        final body = await response.stream.bytesToString();
        throw Exception('Server error: $body');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Convert PDF to Word or PowerPoint.
  /// [outputFormat] should be 'docx' or 'pptx'.
  /// Returns the path to the saved file, or null on failure.
  Future<String?> convertFromPdf({
    required String inputFilePath,
    required String outputDir,
    required String outputFormat,
  }) async {
    try {
      final file = File(inputFilePath);
      final fileName = path.basename(inputFilePath);
      final baseName = path.basenameWithoutExtension(inputFilePath);

      final uri = Uri.parse('$_baseUrl/convert/from-pdf');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          filename: fileName,
        ),
      );
      request.fields['format'] = outputFormat;

      final response = await request.send().timeout(const Duration(minutes: 3));

      if (response.statusCode == 200) {
        final bytes = await response.stream.toBytes();
        final outputPath = '$outputDir/$baseName.$outputFormat';
        await File(outputPath).writeAsBytes(bytes);
        return outputPath;
      } else {
        final body = await response.stream.bytesToString();
        throw Exception('Server error: $body');
      }
    } catch (e) {
      rethrow;
    }
  }
}
