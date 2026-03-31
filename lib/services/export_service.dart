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
          header: (ctx) => _buildHeader(ctx, summaryType),
          footer: (ctx) => _buildFooter(ctx),
          build: (ctx) => [
            _buildTitle(fileName),
            pw.SizedBox(height: 16),
            ..._buildTextParagraphs(cleanContent),
          ],
        ),
      );

      await _saveAndShare(pdf, 'Summary_${fileName.replaceAll(' ', '_')}', context);
    } catch (e) {
      _showError(context, e);
    }
  }

  /// Export Exam Prep (Definitions + Q&A) to PDF
  static Future<void> exportExamPrepToPdf({
    required BuildContext context,
    required String fileName,
    required List<dynamic> definitions,
    required List<dynamic> qa,
  }) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          header: (ctx) => _buildHeader(ctx, 'Exam Prep Mode'),
          footer: (ctx) => _buildFooter(ctx),
          build: (ctx) => [
            _buildTitle('Exam Prep: $fileName'),
            pw.SizedBox(height: 20),
            
            if (definitions.isNotEmpty) ...[
              pw.Header(level: 1, text: 'Key Definitions', textStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
              pw.SizedBox(height: 10),
              ...definitions.map((d) => pw.Bullet(
                text: '${d['term'] ?? d['word'] ?? ''}: ${d['definition'] ?? d['meaning'] ?? ''}',
                style: const pw.TextStyle(fontSize: 11),
                margin: const pw.EdgeInsets.only(bottom: 6),
              )),
              pw.SizedBox(height: 20),
            ],

            if (qa.isNotEmpty) ...[
              pw.Header(level: 1, text: 'Practice Q&A', textStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
              pw.SizedBox(height: 10),
              ...qa.map((item) {
                final q = item['question'] ?? item['q'] ?? '';
                final a = item['answer'] ?? item['a'] ?? '';
                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 12),
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Q: ${item['question'] ?? item['q'] ?? ""}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                      pw.SizedBox(height: 4),
                      pw.Text('A: ${item['answer'] ?? item['a'] ?? ""}', style: const pw.TextStyle(fontSize: 11)),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      );

      await _saveAndShare(pdf, 'ExamPrep_${fileName.replaceAll(' ', '_')}', context);
    } catch (e) {
      _showError(context, e);
    }
  }

  /// Export Exam Notes (Syllabus/Manual Topics) to PDF
  static Future<void> exportExamNotesToPdf({
    required BuildContext context,
    required String topics,
    required String notesMarkdown,
    required List<dynamic> questions,
  }) async {
    try {
      final pdf = pw.Document();
      final cleanNotes = _cleanMarkdown(notesMarkdown);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          header: (ctx) => _buildHeader(ctx, 'AI Exam Notes'),
          footer: (ctx) => _buildFooter(ctx),
          build: (ctx) => [
            _buildTitle('Study Notes'),
            pw.SizedBox(height: 8),
            pw.Text(
              'Topics: ${topics.length > 200 ? '${topics.substring(0, 200)}...' : topics}',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic),
            ),
            pw.SizedBox(height: 20),
            
            ..._buildTextParagraphs(cleanNotes),
            
            if (questions.isNotEmpty) ...[
              pw.SizedBox(height: 30),
              pw.Divider(color: PdfColors.grey300, thickness: 0.5),
              pw.SizedBox(height: 20),
              _buildTitle('Practice Q&A'),
              pw.SizedBox(height: 16),
              ...questions.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 14),
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey200),
                    borderRadius: pw.BorderRadius.circular(6),
                    color: PdfColors.grey50,
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Q${i + 1}: ${item['question'] ?? item['q'] ?? ""}', 
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                      pw.SizedBox(height: 6),
                      pw.Text('A: ${item['answer'] ?? item['a'] ?? ""}', 
                        style: const pw.TextStyle(fontSize: 10, lineSpacing: 1.5)),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      );

      await _saveAndShare(pdf, 'ExamNotes_${DateTime.now().millisecondsSinceEpoch}', context);
    } catch (e) {
      _showError(context, e);
    }
  }

  /// Export Chapter Breakdown to PDF
  static Future<void> exportChaptersToPdf({
    required BuildContext context,
    required String fileName,
    required List<dynamic> chapters,
  }) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          header: (ctx) => _buildHeader(ctx, 'Chapter Breakdown'),
          footer: (ctx) => _buildFooter(ctx),
          build: (ctx) => [
            _buildTitle('Chapters: $fileName'),
            pw.SizedBox(height: 20),
            ...chapters.map((c) {
              final title = c['title'] ?? 'Chapter';
              final content = c['summary'] ?? c['content'] ?? '';
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColor.fromHex('#3B82F6'))),
                  pw.SizedBox(height: 8),
                  pw.Text(_cleanMarkdown(content), style: const pw.TextStyle(fontSize: 11, lineSpacing: 2)),
                  pw.SizedBox(height: 16),
                  pw.Divider(color: PdfColors.grey200),
                  pw.SizedBox(height: 16),
                ],
              );
            }),
          ],
        ),
      );

      await _saveAndShare(pdf, 'Chapters_${fileName.replaceAll(' ', '_')}', context);
    } catch (e) {
      _showError(context, e);
    }
  }

  // --- Helper Methods ---

  static pw.Widget _buildHeader(pw.Context ctx, String type) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'PDify - $type',
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
    );
  }

  static pw.Widget _buildFooter(pw.Context ctx) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text(
        'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey),
      ),
    );
  }

  static pw.Widget _buildTitle(String title) {
    return pw.Text(
      title,
      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
    );
  }

  static List<pw.Widget> _buildTextParagraphs(String content) {
    return content.split('\n').map((line) {
      if (line.trim().isEmpty) return pw.SizedBox(height: 8);
      return pw.Paragraph(
        text: line,
        style: const pw.TextStyle(fontSize: 11, lineSpacing: 2),
        margin: const pw.EdgeInsets.only(bottom: 4),
      );
    }).toList();
  }

  static void _showError(BuildContext context, dynamic e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  /// Export chat history to PDF and share it.
  static Future<void> exportChatToPdf({
    required BuildContext context,
    required String fileName,
    required List<ChatMessage> messages,
  }) async {
    if (messages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No messages to export')));
      return;
    }

    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          header: (ctx) => _buildHeader(ctx, 'Chat History'),
          footer: (ctx) => _buildFooter(ctx),
          build: (ctx) => [
            _buildTitle('Chat: $fileName'),
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
                      style: const pw.TextStyle(fontSize: 11, lineSpacing: 2),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      );

      await _saveAndShare(pdf, 'Chat_${fileName.replaceAll(' ', '_')}', context);
    } catch (e) {
      _showError(context, e);
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

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: safeName,
      text: 'Exported from PDify 📄',
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
