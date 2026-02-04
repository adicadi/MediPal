import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

enum HealthDocRelevance { high, medium, low }

class DocumentIngestResult {
  final String name;
  final String path;
  final String extractedText;
  final int wordCount;
  final HealthDocRelevance relevance;
  final int healthKeywordHits;
  final int nonHealthKeywordHits;

  const DocumentIngestResult({
    required this.name,
    required this.path,
    required this.extractedText,
    required this.wordCount,
    required this.relevance,
    required this.healthKeywordHits,
    required this.nonHealthKeywordHits,
  });
}

class DocumentIngestService {
  static const int _maxExtractChars = 20000;

  static const List<String> _healthKeywords = [
    'symptom',
    'diagnosis',
    'medication',
    'prescription',
    'dosage',
    'mg',
    'blood',
    'pressure',
    'heart',
    'cholesterol',
    'glucose',
    'diabetes',
    'asthma',
    'pain',
    'fever',
    'cough',
    'headache',
    'clinic',
    'hospital',
    'doctor',
    'nurse',
    'lab',
    'test',
    'result',
    'report',
    'radiology',
    'scan',
    'mri',
    'ct',
    'x-ray',
    'therapy',
    'vaccine',
    'immunization',
    'allergy',
    'sleep',
    'steps',
    'heart rate',
    'resting',
    'bp',
    'bpm',
    'side effects',
    'treatment',
  ];

  static const List<String> _nonHealthKeywords = [
    'assignment',
    'homework',
    'essay',
    'literature',
    'math',
    'algebra',
    'geometry',
    'history',
    'physics',
    'chemistry',
    'biology class',
    'economics',
    'accounting',
    'marketing',
    'project',
    'report template',
    'presentation',
    'slide deck',
    'invoice',
    'receipt',
  ];

  static Future<DocumentIngestResult?> ingestFile(PlatformFile file) async {
    final path = file.path;
    if (path == null || path.isEmpty) return null;

    final name = file.name;
    final lower = name.toLowerCase();
    final extension = lower.contains('.')
        ? lower.split('.').last
        : '';

    String extractedText;
    if (['png', 'jpg', 'jpeg'].contains(extension)) {
      extractedText = await _extractTextFromImage(path);
    } else if (extension == 'pdf') {
      extractedText = await _extractTextFromPdf(path);
    } else if (extension == 'txt') {
      extractedText = await _extractTextFromTxt(path);
    } else if (extension == 'docx') {
      extractedText = await _extractTextFromDocx(path);
    } else {
      return null;
    }

    extractedText = _sanitizeText(extractedText);
    if (extractedText.isEmpty) return null;

    final wordCount = extractedText.split(RegExp(r'\s+')).length;
    final healthHits = _countKeywordHits(extractedText, _healthKeywords);
    final nonHealthHits = _countKeywordHits(extractedText, _nonHealthKeywords);
    final relevance =
        _classifyRelevance(healthHits, nonHealthHits, wordCount);

    return DocumentIngestResult(
      name: name,
      path: path,
      extractedText: extractedText,
      wordCount: wordCount,
      relevance: relevance,
      healthKeywordHits: healthHits,
      nonHealthKeywordHits: nonHealthHits,
    );
  }

  static Future<String> _extractTextFromImage(String path) async {
    final inputImage = InputImage.fromFilePath(path);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(inputImage);
      return result.text;
    } finally {
      recognizer.close();
    }
  }

  static Future<String> _extractTextFromPdf(String path) async {
    return compute(_extractPdfTextFromPath, path);
  }

  static Future<String> _extractTextFromTxt(String path) async {
    return File(path).readAsString();
  }

  static Future<String> _extractTextFromDocx(String path) async {
    return compute(_extractDocxTextFromPath, path);
  }

  static String _sanitizeText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.length <= _maxExtractChars) return trimmed;
    return trimmed.substring(0, _maxExtractChars);
  }

  static int _countKeywordHits(String text, List<String> keywords) {
    final lower = text.toLowerCase();
    int count = 0;
    for (final keyword in keywords) {
      if (lower.contains(keyword)) {
        count++;
      }
    }
    return count;
  }

  static HealthDocRelevance _classifyRelevance(
      int healthHits, int nonHealthHits, int wordCount) {
    if (healthHits >= 8) return HealthDocRelevance.high;
    if (healthHits >= 3 && nonHealthHits < 4) return HealthDocRelevance.medium;
    if (healthHits >= 2 && wordCount < 120) return HealthDocRelevance.medium;
    if (nonHealthHits >= 4 && healthHits < 3) return HealthDocRelevance.low;
    return HealthDocRelevance.low;
  }
}

String _extractPdfTextFromPath(String path) {
  final bytes = File(path).readAsBytesSync();
  final document = PdfDocument(inputBytes: bytes);
  final extractor = PdfTextExtractor(document);
  final text = extractor.extractText();
  document.dispose();
  return text;
}

String _extractDocxTextFromPath(String path) {
  final bytes = File(path).readAsBytesSync();
  final archive = ZipDecoder().decodeBytes(bytes, verify: true);
  final documentXml = archive.files
      .where((file) => file.name.toLowerCase() == 'word/document.xml')
      .map((file) => utf8.decode(file.content as List<int>))
      .cast<String?>()
      .firstWhere((content) => content != null, orElse: () => null);
  if (documentXml == null) return '';
  return documentXml
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll(RegExp(r'&nbsp;'), ' ')
      .replaceAll(RegExp(r'&amp;'), '&')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
