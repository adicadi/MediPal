import 'dart:async';

import 'package:file_picker/file_picker.dart';

import '../models/chat_attachment.dart';
import 'document_ingest_service.dart';

class DocumentIngestEvent {
  final String sessionId;
  final DocumentIngestResult? result;
  final String? error;

  const DocumentIngestEvent({
    required this.sessionId,
    this.result,
    this.error,
  });
}

class DocumentIngestQueue {
  static final StreamController<DocumentIngestEvent> _controller =
      StreamController<DocumentIngestEvent>.broadcast();

  static final Map<String, List<DocumentIngestResult>> _pendingResults = {};

  static Stream<DocumentIngestEvent> get stream => _controller.stream;

  static Future<void> enqueue(
      PlatformFile file, String sessionId) async {
    try {
      final result = await DocumentIngestService.ingestFile(file);
      if (result != null) {
        _pendingResults.putIfAbsent(sessionId, () => []).add(result);
      }
      _controller.add(DocumentIngestEvent(
        sessionId: sessionId,
        result: result,
      ));
    } catch (e) {
      _controller.add(DocumentIngestEvent(
        sessionId: sessionId,
        error: e.toString(),
      ));
    }
  }

  static List<DocumentIngestResult> takePending(String sessionId) {
    return _pendingResults.remove(sessionId) ?? [];
  }

  static ChatAttachment toAttachment(DocumentIngestResult result) {
    final trimmed = result.extractedText.length > 1800
        ? '${result.extractedText.substring(0, 1800)}...'
        : result.extractedText;
    return ChatAttachment(
      name: result.name,
      path: result.path,
      contextText: trimmed,
      addedAt: DateTime.now(),
    );
  }
}
