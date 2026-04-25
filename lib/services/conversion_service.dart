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
    String? newFileName,
    void Function(String status, double? progress)? onProgress,
  }) async {
    try {
      final file = File(inputFilePath);
      final fileName = path.basename(inputFilePath);
      final baseName =
          newFileName ?? path.basenameWithoutExtension(inputFilePath);

      onProgress?.call("Preparing file for upload...", 0.1);

      final uri = Uri.parse('$_baseUrl/convert/to-pdf');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          filename: fileName,
        ),
      );

      onProgress?.call("Uploading to conversion server...", 0.3);
      final response = await request.send().timeout(const Duration(minutes: 3));

      if (response.statusCode == 200) {
        onProgress?.call("Conversion complete. Downloading...", 0.6);
        final contentLength = response.contentLength ?? 0;
        final bytes = <int>[];
        int received = 0;
        
        await for (final chunk in response.stream) {
          bytes.addAll(chunk);
          received += chunk.length;
          if (contentLength > 0) {
            final p = 0.6 + (0.4 * (received / contentLength));
            onProgress?.call("Downloading PDF...", p);
          }
        }
        
        final nameWithExt = baseName.toLowerCase().endsWith('.pdf')
            ? baseName
            : '$baseName.pdf';
        final outputPath = '$outputDir/$nameWithExt';
        await File(outputPath).writeAsBytes(bytes);
        onProgress?.call("Done!", 1.0);
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
    String? newFileName,
    void Function(String status, double? progress)? onProgress,
  }) async {
    try {
      final file = File(inputFilePath);
      final fileName = path.basename(inputFilePath);
      final baseName =
          newFileName ?? path.basenameWithoutExtension(inputFilePath);

      onProgress?.call("Preparing file for upload...", 0.1);

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

      onProgress?.call("Uploading to conversion server...", 0.3);
      final response = await request.send().timeout(const Duration(minutes: 3));

      if (response.statusCode == 200) {
        onProgress?.call("Conversion complete. Downloading...", 0.6);
        final contentLength = response.contentLength ?? 0;
        final bytes = <int>[];
        int received = 0;
        
        await for (final chunk in response.stream) {
          bytes.addAll(chunk);
          received += chunk.length;
          if (contentLength > 0) {
            final p = 0.6 + (0.4 * (received / contentLength));
            onProgress?.call("Downloading file...", p);
          }
        }
        
        final nameWithExt = baseName.toLowerCase().endsWith('.$outputFormat')
            ? baseName
            : '$baseName.$outputFormat';
        final outputPath = '$outputDir/$nameWithExt';
        await File(outputPath).writeAsBytes(bytes);
        onProgress?.call("Done!", 1.0);
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
