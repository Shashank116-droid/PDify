import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiOcrService {
  late final GenerativeModel _model;

  // The system instruction helps define the strict persona of an OCR extractor.
  // It prevents Gemini from adding "Sure, here's the text from the image:" type boilerplate.
  static const String _systemInstruction =
      "You are a highly accurate Optical Character Recognition (OCR) system. "
      "Your only task is to extract all the text visible in the provided image accurately, exactly as written. "
      "Preserve formatting (line breaks, spacing, lists) wherever possible. "
      "Do NOT include any conversational filler, introductory remarks, or explanations. "
      "Only return the raw extracted text. If no text is found, return nothing.";

  GeminiOcrService() {
    // You can use the same key! Since dotenv isn't fully set up in the Flutter app,
    // we can use the raw string you provided. (In production, consider securing this).
    final apiKey = 'AIzaSyDJ0JgkX-SS-v-JOCuyrXu56ezJtk7fGlo';
    if (apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY not found in environment variables.');
    }

    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
      systemInstruction: Content.system(_systemInstruction),
    );
  }

  /// Extracts text from the given [imageFile] using the Gemini model.
  Future<String> extractTextFromImage(File imageFile) async {
    try {
      final imageBytes = await imageFile.readAsBytes();
      final imagePart = DataPart(
        'image/jpeg',
        imageBytes,
      ); // Assuming jpeg for photos/pdf conversions

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
}
