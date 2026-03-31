import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiOcrService {
  late final GenerativeModel _model;
  late final GenerativeModel _notesModel;

  static const String _apiKey = 'AIzaSyDJ0JgkX-SS-v-JOCuyrXu56ezJtk7fGlo';

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
      "You always include key definitions, core concepts, important formulas, and quick-revision bullet points.";

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
      final imagePart = DataPart(
        'image/jpeg',
        imageBytes,
      );

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

  /// Generates comprehensive exam notes and practice Q&A from [topics].
  /// Returns a Map with 'notes' (markdown string) and 'questions' (List<Map>).
  Future<Map<String, dynamic>> generateExamNotes(String topics) async {
    try {
      // Step 1: Generate exam notes
      final notesPrompt = '''Generate comprehensive exam notes for the following topics/syllabus.

Format the notes in clean Markdown with these sections:
## 📖 Key Definitions
## 🧠 Core Concepts
## 📝 Important Points to Remember
## ⚡ Quick Revision (bullet points for last-minute study)

Make the notes detailed enough for exam preparation but concise enough to be practical.

Topics/Syllabus:
$topics''';

      final notesResponse = await _notesModel.generateContent([
        Content.text(notesPrompt),
      ]);

      final notesText = notesResponse.text?.trim() ?? '';

      // Step 2: Generate practice Q&A
      final qaPrompt = '''Based on these topics, generate 8-10 practice exam questions with detailed answers.

Return ONLY a valid JSON array with no markdown formatting, no code blocks, no extra text. Just the raw JSON array:
[{"question": "What is X?", "answer": "X is..."}]

Topics:
$topics''';

      final qaResponse = await _notesModel.generateContent([
        Content.text(qaPrompt),
      ]);

      final qaText = qaResponse.text?.trim() ?? '';
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

      // Step 3: Extract a short, descriptive title from the generated notes
      String autoTitle = topics;
      try {
        final titlePrompt = 'Based on the following study content, generate a short, descriptive title (max 6 words) that best summarizes the subject. Return ONLY the title text, nothing else.\n\n$notesText';
        final titleResponse = await _notesModel.generateContent([
          Content.text(titlePrompt),
        ]);
        final generatedTitle = titleResponse.text?.trim() ?? '';
        if (generatedTitle.isNotEmpty && generatedTitle.length < 60) {
          autoTitle = generatedTitle;
        }
      } catch (e) {
        debugPrint('Title generation failed (non-critical): $e');
      }

      return {
        'notes': notesText,
        'questions': questions,
        'title': autoTitle,
      };
    } catch (e) {
      debugPrint('GeminiOcrService generateExamNotes Error: $e');
      throw Exception('Failed to generate exam notes: $e');
    }
  }
}
