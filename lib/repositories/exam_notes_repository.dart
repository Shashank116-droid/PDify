import 'package:cloud_firestore/cloud_firestore.dart';

class ExamNotesRepository {
  final FirebaseFirestore _firestore;

  ExamNotesRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<DocumentReference> saveExamNotes({
    required String userId,
    required String topics,
    required String notesMarkdown,
    required List<Map<String, dynamic>> questions,
  }) async {
    return await _firestore.collection('exam_notes').add({
      'userId': userId,
      'topics': topics,
      'notesMarkdown': notesMarkdown,
      'questions': questions,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getExamNotesStream(String userId) {
    return _firestore
        .collection('exam_notes')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> deleteExamNote(String noteId) async {
    await _firestore.collection('exam_notes').doc(noteId).delete();
  }
  Future<void> renameExamNote(String noteId, String newTopics) async {
    await _firestore.collection('exam_notes').doc(noteId).update({
      'topics': newTopics,
    });
  }
}
