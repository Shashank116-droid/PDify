import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // --- LOCAL PDF METADATA STORAGE ---

  Future<void> saveLocalPdfMetadata(String localId, Map<String, dynamic> metadata) async {
    final prefs = await SharedPreferences.getInstance();
    final localListStr = prefs.getString('local_pdf_list') ?? '[]';
    final List<dynamic> localList = jsonDecode(localListStr);
    
    metadata['id'] = localId;
    metadata['isLocal'] = true;
    metadata['uploadedAt'] = DateTime.now().toIso8601String();
    
    localList.insert(0, metadata);
    await prefs.setString('local_pdf_list', json.encode(localList));
  }

  Future<List<Map<String, dynamic>>> getLocalPdfs() async {
    final prefs = await SharedPreferences.getInstance();
    final localListStr = prefs.getString('local_pdf_list') ?? '[]';
    final List<dynamic> localList = jsonDecode(localListStr);
    return localList.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> deleteLocalPdf(String localId) async {
    final prefs = await SharedPreferences.getInstance();
    final localListStr = prefs.getString('local_pdf_list') ?? '[]';
    final List<dynamic> localList = jsonDecode(localListStr);
    
    localList.removeWhere((item) => item['id'] == localId);
    await prefs.setString('local_pdf_list', json.encode(localList));
    await prefs.remove('summary_cache_$localId');
  }
}
