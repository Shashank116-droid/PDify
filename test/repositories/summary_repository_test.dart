import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdify/repositories/summary_repository.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late SummaryRepository repository;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repository = SummaryRepository(firestore: fakeFirestore);
    SharedPreferences.setMockInitialValues({});
  });

  group('SummaryRepository Tests', () {
    test('getSummariesFutureByPdfId returns correct summaries', () async {
      await fakeFirestore.collection('summaries').add({
        'pdfId': 'pdf123',
        'type': 'full',
        'content': 'This is a summary',
      });
      await fakeFirestore.collection('summaries').add({
        'pdfId': 'pdf456',
        'type': 'full',
        'content': 'Another summary',
      });

      final snapshot = await repository.getSummariesFutureByPdfId('pdf123');
      expect(snapshot.docs.length, 1);
      expect(snapshot.docs.first['type'], 'full');
    });

    test('getSummariesByPdfIdWithCache fetches and caches from Firestore', () async {
      final docRef = await fakeFirestore.collection('summaries').add({
        'pdfId': 'test_cache_pdf',
        'type': 'exam',
      });

      final results = await repository.getSummariesByPdfIdWithCache('test_cache_pdf');
      expect(results.length, 1);
      expect(results.first['type'], 'exam');

      // Now delete from Firestore to verify cache is hit on next call
      await docRef.delete();

      final cachedResults = await repository.getSummariesByPdfIdWithCache('test_cache_pdf');
      expect(cachedResults.length, 1);
      expect(cachedResults.first['type'], 'exam');
    });

    test('getSummariesByPdfIdWithCache forceRefresh ignores cache', () async {
      final docRef = await fakeFirestore.collection('summaries').add({
        'pdfId': 'refresh_pdf',
        'type': 'exam',
      });

      await repository.getSummariesByPdfIdWithCache('refresh_pdf');
      
      // Delete from Firestore
      await docRef.delete();
      
      // Force refresh should query firestore and return empty
      final freshResults = await repository.getSummariesByPdfIdWithCache('refresh_pdf', forceRefresh: true);
      expect(freshResults.length, 0);
    });

    test('deleteSummariesForPdf deletes all summaries for a pdf', () async {
      await fakeFirestore.collection('summaries').add({
        'pdfId': 'del_pdf',
        'type': 'full',
      });
      await fakeFirestore.collection('summaries').add({
        'pdfId': 'del_pdf',
        'type': 'chapters',
      });
      await fakeFirestore.collection('summaries').add({
        'pdfId': 'keep_pdf',
        'type': 'full',
      });

      await repository.deleteSummariesForPdf('del_pdf');

      final delSnapshot = await repository.getSummariesFutureByPdfId('del_pdf');
      expect(delSnapshot.docs.length, 0);

      final keepSnapshot = await repository.getSummariesFutureByPdfId('keep_pdf');
      expect(keepSnapshot.docs.length, 1);
    });
  });
}
