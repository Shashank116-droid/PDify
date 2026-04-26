import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SummaryRepository {
  final FirebaseFirestore _firestore;

  SummaryRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<QuerySnapshot> getSummariesStreamByPdfId(String pdfId) {
    return _firestore
        .collection('summaries')
        .where('pdfId', isEqualTo: pdfId)
        .snapshots();
  }

  Future<QuerySnapshot> getSummariesFutureByPdfId(String pdfId) {
    return _firestore
        .collection('summaries')
        .where('pdfId', isEqualTo: pdfId)
        .get();
  }

  Future<void> deleteSummariesForPdf(String pdfId) async {
    final summarySnapshot = await getSummariesFutureByPdfId(pdfId);
    final batch = _firestore.batch();
    for (final doc in summarySnapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<DocumentSnapshot> getSummaryFuture(String summaryId) {
    return _firestore.collection('summaries').doc(summaryId).get();
  }

  /// Fetches summaries with local `shared_preferences` caching to reduce Firestore reads.
  Future<List<Map<String, dynamic>>> getSummariesByPdfIdWithCache(String pdfId, {bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'summary_cache_$pdfId';

    if (!forceRefresh) {
      final cachedString = prefs.getString(cacheKey);
      if (cachedString != null) {
        try {
          final List<dynamic> decoded = json.decode(cachedString);
          return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        } catch (_) {
          // If JSON decoding fails, ignore cache and fetch fresh
        }
      }
    }

    // Fetch from Firestore
    final snapshot = await getSummariesFutureByPdfId(pdfId);
    final results = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      // Ensure data is JSON encodable by stringifying Timestamps if any
      final sanitized = <String, dynamic>{};
      data.forEach((key, value) {
        if (value is Timestamp) {
          sanitized[key] = value.toDate().toIso8601String();
        } else {
          sanitized[key] = value;
        }
      });
      return sanitized;
    }).toList();

    // Cache the fresh results
    await prefs.setString(cacheKey, json.encode(results));
    return results;
  }

  /// Saves a locally generated summary (no Firestore involved).
  Future<void> saveLocalSummary(String localPdfId, Map<String, dynamic> summaryData) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Split the aggregated data into the structure the UI expects
    final results = [
      {...summaryData['full'] as Map<String, dynamic>, 'pdfId': localPdfId, 'type': 'full'},
      {...summaryData['exam'] as Map<String, dynamic>, 'pdfId': localPdfId, 'type': 'exam'},
      {...summaryData['chapters'] as Map<String, dynamic>, 'pdfId': localPdfId, 'type': 'chapters'},
    ];

    await prefs.setString('summary_cache_$localPdfId', json.encode(results));
  }
}
