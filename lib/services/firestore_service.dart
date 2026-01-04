import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/report_model.dart';

class FirestoreService {
  final CollectionReference reports =
      FirebaseFirestore.instance.collection('reports');

  // Add a new dog report with expiry
  Future<void> addReport({
    required String location,
    required int dogCount,
    required String condition,
    String description = '',
    required double latitude,
    required double longitude,
  }) async {
    // Calculate expiry time (4 hours from now)
    final expiresAt = Timestamp.fromDate(
      DateTime.now().add(const Duration(hours: 4)),
    );

    await reports.add({
      'location': location,
      'dogCount': dogCount,
      'condition': condition,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': FieldValue.serverTimestamp(),
      'expiresAt': expiresAt,
    });
  }

  // Get all active (non-expired) reports, ordered from latest to oldest
// Get all active (non-expired) reports
  Stream<List<DogReport>> getReports() {
    return reports
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .orderBy('expiresAt')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
      final reportsList = snapshot.docs
          .map((doc) =>
              DogReport.fromMap(doc.id, doc.data() as Map<String, dynamic>))
          .toList();

      // ✅ Sort again on client-side to ensure correct order
      reportsList.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return reportsList;
    });
  }

  // Optional: Manually delete expired reports (can be called periodically)
  Future<void> cleanupExpiredReports() async {
    final expiredReports = await reports
        .where('expiresAt', isLessThanOrEqualTo: Timestamp.now())
        .get();

    for (var doc in expiredReports.docs) {
      await doc.reference.delete();
    }
  }
}
