import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:pdify/repositories/pdf_repository.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseStorage mockStorage;
  late PdfRepository repository;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    mockStorage = MockFirebaseStorage();
    repository = PdfRepository(
      firestore: fakeFirestore,
      storage: mockStorage,
    );
  });

  group('PdfRepository Tests', () {
    test('uploadPdf creates a document in Firestore', () async {
      final file = File('test_file.pdf'); // Dummy file, mock storage doesn't actually read it
      
      final docRef = await repository.uploadPdf(
        file: file,
        userId: 'user123',
        fileName: 'test.pdf',
        pageCount: 5,
      );

      final snapshot = await docRef.get();
      expect(snapshot.exists, true);
      final data = snapshot.data() as Map<String, dynamic>;
      expect(data['userId'], 'user123');
      expect(data['fileName'], 'test.pdf');
      expect(data['pageCount'], 5);
      expect(data['status'], 'processing');
    });

    test('getUserPdfsFuture retrieves correct PDFs for user', () async {
      await fakeFirestore.collection('pdfs').add({
        'userId': 'user123',
        'fileName': 'doc1.pdf',
        'uploadedAt': DateTime.now(),
      });
      await fakeFirestore.collection('pdfs').add({
        'userId': 'user456',
        'fileName': 'doc2.pdf',
        'uploadedAt': DateTime.now(),
      });

      final snapshot = await repository.getUserPdfsFuture('user123');
      expect(snapshot.docs.length, 1);
      expect(snapshot.docs.first['fileName'], 'doc1.pdf');
    });

    test('deletePdf removes document from Firestore', () async {
      final docRef = await fakeFirestore.collection('pdfs').add({
        'userId': 'user123',
        'fileName': 'to_delete.pdf',
      });

      await repository.deletePdf(docRef.id, 'some/path.pdf');

      final checkSnapshot = await docRef.get();
      expect(checkSnapshot.exists, false);
    });

    test('renamePdf updates fileName in Firestore', () async {
      final docRef = await fakeFirestore.collection('pdfs').add({
        'userId': 'user123',
        'fileName': 'old_name.pdf',
      });

      await repository.renamePdf(docRef.id, 'new_name.pdf');

      final updatedSnapshot = await docRef.get();
      final data = updatedSnapshot.data() as Map<String, dynamic>;
      expect(data['fileName'], 'new_name.pdf');
    });
  });
}
