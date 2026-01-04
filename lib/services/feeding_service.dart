import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/feeding_status.dart';

class FeedingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get feeding status for a location
  Future<FeedingStatus> getFeedingStatus(String locationName) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      // Query feedings for this location today
      final snapshot = await _firestore
          .collection('feedings')
          .where('location', isEqualTo: locationName)
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .orderBy('timestamp', descending: true)
          .get();

      if (snapshot.docs.isEmpty) {
        // No feedings today - return default status
        return FeedingStatus(
          locationName: locationName,
          feedCount: 0,
        );
      }

      // Get the most recent feeding
      final mostRecent = snapshot.docs.first;
      final data = mostRecent.data();

      return FeedingStatus(
        locationName: locationName,
        feedCount: snapshot.docs.length,
        lastFedTimestamp: data['timestamp'] as Timestamp?,
      );
    } catch (e) {
      debugPrint('Error getting feeding status for $locationName: $e');
      // Return default status instead of throwing
      return FeedingStatus(
        locationName: locationName,
        feedCount: 0,
      );
    }
  }

  // Mark a location as fed
  Future<void> markLocationAsFed(String locationName) async {
    try {
      await _firestore.collection('feedings').add({
        'location': locationName,
        'timestamp': FieldValue.serverTimestamp(),
        'fedBy': 'anonymous',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error marking location as fed: $e');
      rethrow;
    }
  }

  // Get total feedings across all locations today
  Future<int> getTotalFeedingsToday() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final snapshot = await _firestore
          .collection('feedings')
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();

      return snapshot.docs.length;
    } catch (e) {
      debugPrint('Error getting total feedings: $e');
      return 0;
    }
  }
}
