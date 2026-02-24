import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdify/providers/chat_provider.dart';

class ExportService {
  /// Export a summary to PDF and share it.
  static Future<void> exportSummaryToPdf({
    required BuildContext context,
    required String fileName,
    required String summaryContent,
    String summaryType = 'AI Summary',
  }) async {
    try {
      final pdf = pw.Document();
      final cleanContent = _cleanMarkdown(summaryContent);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          header: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'PDify - $summaryType',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColor.fromHex('#7C3AED'),
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Divider(color: PdfColor.fromHex('#7C3AED'), thickness: 0.5),
              pw.SizedBox(height: 8),
            ],
          ),
          footer: (ctx) => pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey),
            ),
          ),
          build: (ctx) => [
            pw.Text(
              fileName,
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 16),
            // Split content into paragraphs to allow page breaks
            ...cleanContent.split('\n').map((line) {
              if (line.trim().isEmpty) return pw.SizedBox(height: 8);
              return pw.Paragraph(
                text: line,
                style: const pw.TextStyle(fontSize: 12, lineSpacing: 2),
                margin: const pw.EdgeInsets.only(bottom: 4),
              );
            }),
          ],
        ),
      );

      await _saveAndShare(pdf, 'Summary_$fileName', context);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  /// Export chat history to PDF and share it.
  static Future<void> exportChatToPdf({
    required BuildContext context,
    required String fileName,
    required List<ChatMessage> messages,
  }) async {
    if (messages.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No messages to export')));
      return;
    }

    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          header: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'PDify - Chat History',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColor.fromHex('#7C3AED'),
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Divider(color: PdfColor.fromHex('#7C3AED'), thickness: 0.5),
              pw.SizedBox(height: 8),
            ],
          ),
          footer: (ctx) => pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey),
            ),
          ),
          build: (ctx) => [
            pw.Text(
              'Chat: $fileName',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 16),
            ...messages.map((msg) {
              final isUser = msg.role == 'user';
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 12),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: isUser
                      ? PdfColor.fromHex('#EDE9FE')
                      : PdfColor.fromHex('#F1F5F9'),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      isUser ? 'You' : 'AI Assistant',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: isUser
                            ? PdfColor.fromHex('#7C3AED')
                            : PdfColor.fromHex('#334155'),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      _cleanMarkdown(msg.text),
                      style: const pw.TextStyle(fontSize: 11, lineSpacing: 5),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      );

      await _saveAndShare(pdf, 'Chat_$fileName', context);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  static Future<void> _saveAndShare(
    pw.Document pdf,
    String name,
    BuildContext context,
  ) async {
    final dir = await getTemporaryDirectory();
    final safeName = name.replaceAll(RegExp(r'[^\w\s\-.]'), '_');
    final file = File('${dir.path}/$safeName.pdf');
    await file.writeAsBytes(await pdf.save());

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        title: safeName,
        text: 'Exported from PDify',
      ),
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF exported successfully!')),
      );
    }
  }

  /// Strip Markdown formatting and unsupported characters for plain-text PDF output.
  static String _cleanMarkdown(String text) {
    String cleaned = text
        .replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => m[1]!) // Bold
        .replaceAllMapped(RegExp(r'\*(.+?)\*'), (m) => m[1]!) // Italic
        .replaceAllMapped(RegExp(r'`(.+?)`'), (m) => m[1]!) // Inline code
        .replaceAll(RegExp(r'```[\s\S]*?```'), '') // Code blocks
        .replaceAll(RegExp(r'^#+\s', multiLine: true), '') // Headers
        .replaceAll(
          RegExp(r'^[-*]\s', multiLine: true),
          '- ',
        ) // List items (safe dash)
        .replaceAll(RegExp(r'\n{3,}'), '\n\n'); // Extra spacing

    // Final pass: Remove emojis and non-standard characters that don't exist in Helvetica
    // Only allow common printable ASCII: space (32) to ~ (126), and newlines
    return cleaned
        .split('')
        .where((char) {
          final code = char.codeUnitAt(0);
          return (code >= 32 && code <= 126) || code == 10 || code == 13;
        })
        .join('')
        .trim();
  }
}
