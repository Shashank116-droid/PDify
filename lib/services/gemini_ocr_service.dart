import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiOcrService {
  late final GenerativeModel _model;
  late final GenerativeModel _notesModel;

  static final String _apiKey = dotenv.get('GEMINI_API_KEY', fallback: '');

  // The system instruction helps define the strict persona of an OCR extractor.
  static const String _systemInstruction =
      "You are a highly accurate Optical Character Recognition (OCR) system. "
      "Your only task is to extract all the text visible in the provided image accurately, exactly as written. "
      "Preserve formatting (line breaks, spacing, lists) wherever possible. "
      "Do NOT include any conversational filler, introductory remarks, or explanations. "
      "Only return the raw extracted text. If no text is found, return nothing.";

  static const String _notesSystemInstruction =
      "You are an expert academic tutor and exam preparation specialist. "
      "When given topics or a syllabus, you generate comprehensive, well-structured exam notes "
      "that help students ace their exams. Your notes are clear, concise, and exam-focused. "
      "You always include key definitions, core concepts, important formulas, and quick-revision bullet points. "
      "When asked to return JSON, you MUST return ONLY valid JSON with no markdown formatting, no code blocks, and no extra text.";

  GeminiOcrService() {
    if (_apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY not found.');
    }

    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _apiKey,
      systemInstruction: Content.system(_systemInstruction),
    );

    _notesModel = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _apiKey,
      systemInstruction: Content.system(_notesSystemInstruction),
    );
  }

  /// Extracts text from the given [imageFile] using the Gemini model.
  Future<String> extractTextFromImage(File imageFile) async {
    try {
      final imageBytes = await imageFile.readAsBytes();
      final imagePart = DataPart('image/jpeg', imageBytes);

      final prompt = TextPart("Extract all text from this image.");

      final response = await _model.generateContent([
        Content.multi([prompt, imagePart]),
      ]);

      return response.text?.trim() ?? '';
    } catch (e) {
      debugPrint('GeminiOcrService Error: $e');
      throw Exception('Failed to extract text from image: $e');
    }
  }

  /// Extracts text from multiple image files concurrently.
  /// Processes up to [batchSize] images in parallel for faster throughput.
  /// Returns a list of extracted texts in the same order as input files.
  Future<List<String>> extractTextFromImagesBatch(
    List<File> imageFiles, {
    int batchSize = 3,
    void Function(int completed, int total)? onProgress,
  }) async {
    final results = List<String>.filled(imageFiles.length, '');
    int completed = 0;

    // Process in batches to avoid overwhelming the API
    for (int i = 0; i < imageFiles.length; i += batchSize) {
      final end = (i + batchSize).clamp(0, imageFiles.length);
      final batch = imageFiles.sublist(i, end);

      final batchResults = await Future.wait(
        batch.asMap().entries.map((entry) async {
          try {
            return await extractTextFromImage(entry.value);
          } catch (e) {
            debugPrint('Batch OCR failed for index ${i + entry.key}: $e');
            return '';
          }
        }),
      );

      for (int j = 0; j < batchResults.length; j++) {
        results[i + j] = batchResults[j];
        completed++;
        onProgress?.call(completed, imageFiles.length);
      }
    }

    return results;
  }

  /// Generates comprehensive exam notes and practice Q&A from [topics].
  /// Returns a Map with 'notes' (markdown string), 'questions' (List<Map>),
  /// and 'title' (short descriptive title).
  ///
  /// OPTIMIZED: Uses parallel requests — notes and Q&A are generated
  /// simultaneously, and the title is derived locally from the notes
  /// instead of making a separate API call.
  Future<Map<String, dynamic>> generateExamNotes(String topics) async {
    try {
      // Step 1: Generate exam notes prompt
      final notesPrompt =
          '''Generate comprehensive exam notes for the following topics/syllabus.

Format the notes in clean Markdown with these sections:
## 📖 Key Definitions
## 🧠 Core Concepts
## 📝 Important Points to Remember
## ⚡ Quick Revision (bullet points for last-minute study)

Make the notes detailed enough for exam preparation but concise enough to be practical.

Topics/Syllabus:
$topics''';

      // Step 2: Generate Q&A prompt
      final qaPrompt =
          '''Based on these topics, generate 8-10 practice exam questions with detailed answers.

Return ONLY a valid JSON array with no markdown formatting, no code blocks, no extra text. Just the raw JSON array:
[{"question": "What is X?", "answer": "X is..."}]

Topics:
$topics''';

      // OPTIMIZATION: Fire both requests simultaneously instead of sequentially
      final responses = await Future.wait([
        _notesModel.generateContent([Content.text(notesPrompt)]),
        _notesModel.generateContent([Content.text(qaPrompt)]),
      ]);

      final notesText = responses[0].text?.trim() ?? '';
      final qaText = responses[1].text?.trim() ?? '';

      // Parse Q&A JSON
      List<Map<String, dynamic>> questions = [];
      try {
        // Extract JSON array from response (handle markdown code blocks)
        final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(qaText);
        if (jsonMatch != null) {
          final decoded = jsonDecode(jsonMatch.group(0)!) as List;
          questions = decoded
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
      } catch (e) {
        debugPrint('Q&A parsing failed (non-critical): $e');
      }

      // OPTIMIZATION: Derive title locally instead of a 3rd API call.
      // Extract a meaningful title from the first heading or first line of notes.
      String autoTitle = _deriveTitleFromNotes(notesText, topics);

      return {'notes': notesText, 'questions': questions, 'title': autoTitle};
    } catch (e) {
      debugPrint('GeminiOcrService generateExamNotes Error: $e');
      throw Exception('Failed to generate exam notes: $e');
    }
  }

  /// Generates a full suite of document insights (Standard, Exam, Chapters) locally.
  /// Chat with a specific context (like a PDF's text or Exam Notes)
  Future<String> chatWithContext({
    required String context,
    required String message,
    List<Map<String, dynamic>> history = const [],
  }) async {
    try {
      final chat = _model.startChat(
        history: history.map((m) => Content(
          m['role'] == 'user' ? 'user' : 'model',
          [TextPart(m['text'])]
        )).toList(),
      );

      final prompt = '''You are a helpful AI study assistant. Answer the user's question based ONLY on the provided context.
If the answer is not in the context, say you don't know based on this document.

CONTEXT:
$context

USER MESSAGE:
$message''';

      final response = await chat.sendMessage(Content.text(prompt));
      return response.text ?? 'No response from AI.';
    } catch (e) {
      debugPrint('GeminiOcrService chatWithContext Error: $e');
      throw Exception('Chat failed: $e');
    }
  }

  /// OPTIMIZED: Fires all requests in parallel for maximum speed.
  Future<Map<String, dynamic>> generateFullDocumentInsights(String text) async {
    try {
      final summaryPrompt =
          'Summarize this PDF content for a student, handling key points and concepts concisely:\n\n$text';

      final examPrompt =
          '''Analyze the following content and create an exam-focused summary with these keys in a JSON format:
"definitions": [ {"term": "...", "definition": "..."} ],
"questions": [ {"question": "...", "answer": "..."} ],
"summary": "markdown string"

Content: $text''';

      final chapterPrompt =
          '''Analyze the text structure and return a JSON array of chapters. 
Each chapter should have "title" and "summary".
Return ONLY the JSON array: [ {"title": "...", "summary": "..."} ]

Content: $text''';

      // Fire all 3 major generation tasks in parallel
      final results = await Future.wait([
        _notesModel.generateContent([Content.text(summaryPrompt)]),
        _notesModel.generateContent([Content.text(examPrompt)]),
        _notesModel.generateContent([Content.text(chapterPrompt)]),
      ]);

      final summaryText = results[0].text?.trim() ?? '';
      final examRaw = results[1].text?.trim() ?? '';
      final chapterRaw = results[2].text?.trim() ?? '';

      // Parse Exam JSON
      Map<String, dynamic> examData = {};
      try {
        final match = RegExp(r'\{[\s\S]*\}').firstMatch(examRaw);
        if (match != null) {
          examData = jsonDecode(match.group(0)!);
        }
      } catch (e) {
        debugPrint('Local Exam JSON parsing failed: $e');
      }

      // Parse Chapter JSON
      List<dynamic> chapters = [];
      try {
        final match = RegExp(r'\[[\s\S]*\]').firstMatch(chapterRaw);
        if (match != null) {
          chapters = jsonDecode(match.group(0)!);
        }
      } catch (e) {
        debugPrint('Local Chapter JSON parsing failed: $e');
      }

      return {
        'full': {'content': summaryText, 'type': 'full'},
        'exam': {
          'keyDefinitions': examData['definitions'] ?? [],
          'questions': examData['questions'] ?? [],
          'content': examData['summary'] ?? '',
          'type': 'exam',
        },
        'chapters': {'chapters': chapters, 'type': 'chapters'},
        'title': _deriveTitleFromNotes(summaryText, 'Document'),
      };
    } catch (e) {
      debugPrint('GeminiOcrService generateFullDocumentInsights Error: $e');
      throw Exception('Failed to generate full insights: $e');
    }
  }

  /// Derives a short title from the generated notes content without an API call.
  /// Falls back to [fallback] (the original topics input) if extraction fails.
  String _deriveTitleFromNotes(String notesText, String fallback) {
    // Try to extract the first markdown heading
    final headingMatch = RegExp(
      r'^#+ (.+)$',
      multiLine: true,
    ).firstMatch(notesText);
    if (headingMatch != null) {
      final heading = headingMatch.group(1)!.trim();
      // Remove emoji and keep it concise
      final cleaned = heading.replaceAll(RegExp(r'[^\w\s&,:-]'), '').trim();
      if (cleaned.isNotEmpty && cleaned.length < 60) {
        return cleaned;
      }
    }

    // Try to use the first non-empty line
    final firstLine = notesText
        .split('\n')
        .firstWhere(
          (line) => line.trim().isNotEmpty && !line.startsWith('#'),
          orElse: () => '',
        )
        .trim();

    if (firstLine.isNotEmpty && firstLine.length < 60) {
      return firstLine;
    }

    // Fall back to trimmed topics
    if (fallback.length > 50) {
      return '${fallback.substring(0, 47)}...';
    }
    return fallback;
  }
}
