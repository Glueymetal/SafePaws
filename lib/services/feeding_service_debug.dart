import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/feeding_status.dart';

class FeedingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get feeding status for a location with detailed logging
  Future<FeedingStatus> getFeedingStatus(String locationName) async {
    debugPrint('📍 Fetching feeding status for: $locationName');

    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      debugPrint('📅 Query start time: $startOfDay');

      // Query feedings for this location today
      final snapshot = await _firestore
          .collection('feedings')
          .where('location', isEqualTo: locationName)
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .orderBy('timestamp', descending: true)
          .get();

      debugPrint('📊 Found ${snapshot.docs.length} feedings for $locationName');

      if (snapshot.docs.isEmpty) {
        debugPrint('✅ No feedings today - returning default status');
        return FeedingStatus(
          locationName: locationName,
          feedCount: 0,
        );
      }

      // Get the most recent feeding
      final mostRecent = snapshot.docs.first;
      final data = mostRecent.data();

      debugPrint('🕐 Last fed: ${data['timestamp']}');

      return FeedingStatus(
        locationName: locationName,
        feedCount: snapshot.docs.length,
        lastFedTimestamp: data['timestamp'] as Timestamp?,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ ERROR getting feeding status for $locationName: $e');
      debugPrint('Stack trace: $stackTrace');

      // Return default status instead of throwing
      return FeedingStatus(
        locationName: locationName,
        feedCount: 0,
      );
    }
  }

  // Mark a location as fed with logging
  Future<void> markLocationAsFed(String locationName) async {
    debugPrint('🍽️ Marking location as fed: $locationName');

    try {
      final docRef = await _firestore.collection('feedings').add({
        'location': locationName,
        'timestamp': FieldValue.serverTimestamp(),
        'fedBy': 'anonymous',
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Successfully marked as fed. Doc ID: ${docRef.id}');
    } catch (e, stackTrace) {
      debugPrint('❌ ERROR marking location as fed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Get total feedings across all locations today with logging
  Future<int> getTotalFeedingsToday() async {
    debugPrint('📈 Fetching total feedings today');

    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final snapshot = await _firestore
          .collection('feedings')
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();

      debugPrint('✅ Total feedings today: ${snapshot.docs.length}');
      return snapshot.docs.length;
    } catch (e, stackTrace) {
      debugPrint('❌ ERROR getting total feedings: $e');
      debugPrint('Stack trace: $stackTrace');
      return 0;
    }
  }

  // NEW: Test Firebase connection
  Future<bool> testConnection() async {
    debugPrint('🔧 Testing Firebase connection...');

    try {
      // Try to read from the feedings collection
      final snapshot = await _firestore.collection('feedings').limit(1).get();

      debugPrint('✅ Firebase connection successful');
      debugPrint('📊 Collection exists: ${snapshot.docs.isNotEmpty}');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ Firebase connection FAILED: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }
}
