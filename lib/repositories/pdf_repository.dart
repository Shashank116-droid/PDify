import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class PdfRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  PdfRepository({FirebaseFirestore? firestore, FirebaseStorage? storage})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  Future<DocumentReference> uploadPdf({
    required File file,
    required String userId,
    required String fileName,
    required int pageCount,
  }) async {
    String storagePath = 'users/$userId/$fileName';
    Reference ref = _storage.ref().child(storagePath);
    await ref.putFile(file);
    String downloadUrl = await ref.getDownloadURL();

    return await _firestore.collection('pdfs').add({
      'userId': userId,
      'fileUrl': downloadUrl,
      'fileName': fileName,
      'storagePath': storagePath,
      'uploadedAt': FieldValue.serverTimestamp(),
      'status': 'processing',
      'pageCount': pageCount,
    });
  }

  Future<void> deletePdf(String docId, String? storagePath) async {
    if (storagePath != null && storagePath.isNotEmpty) {
      try {
        await _storage.ref().child(storagePath).delete();
      } catch (_) {}
    }
    await _firestore.collection('pdfs').doc(docId).delete();
  }

  Future<void> renamePdf(String docId, String newName) async {
    await _firestore.collection('pdfs').doc(docId).update({
      'fileName': newName,
    });
  }

  Future<void> retryPdf(String docId, Map<String, dynamic> data) async {
    await _firestore.collection('pdfs').doc(docId).delete();
    await _firestore.collection('pdfs').add({
      'userId': data['userId'],
      'fileUrl': data['fileUrl'],
      'storagePath': data['storagePath'],
      'fileName': data['fileName'],
      'status': 'processing',
      'uploadedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getLatestPdfStream(String userId) {
    return _firestore
        .collection('pdfs')
        .where('userId', isEqualTo: userId)
        .orderBy('uploadedAt', descending: true)
        .limit(1)
        .snapshots();
  }

  Stream<QuerySnapshot> getUserPdfsStream(String userId) {
    return _firestore
        .collection('pdfs')
        .where('userId', isEqualTo: userId)
        .orderBy('uploadedAt', descending: true)
        .snapshots();
  }
  
  Future<QuerySnapshot> getUserPdfsFuture(String userId) {
    return _firestore
        .collection('pdfs')
        .where('userId', isEqualTo: userId)
        .get();
  }

  Future<DocumentSnapshot> getPdfFuture(String docId) {
    return _firestore.collection('pdfs').doc(docId).get();
  }
}
