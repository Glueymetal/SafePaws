import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FeedingStatus {
  final String locationName;
  final DateTime? lastFedAt;
  final int feedCount;

  FeedingStatus({
    required this.locationName,
    required this.feedCount,
    Timestamp? lastFedTimestamp,
  }) : lastFedAt = lastFedTimestamp?.toDate();

  // Get hours since last fed
  int? getHoursSinceLastFed() {
    if (lastFedAt == null) return null;
    return DateTime.now().difference(lastFedAt!).inHours;
  }

  // Get minutes since last fed
  int? getMinutesSinceLastFed() {
    if (lastFedAt == null) return null;
    return DateTime.now().difference(lastFedAt!).inMinutes;
  }

  // Determine status based on time since last feeding
  String getStatus() {
    final hours = getHoursSinceLastFed();

    if (hours == null) {
      return 'not_fed';
    } else if (hours < 4) {
      return 'recently_fed';
    } else if (hours < 8) {
      return 'needs_feeding_soon';
    } else {
      return 'needs_feeding';
    }
  }

  // Get status color
  Color getStatusColor() {
    switch (getStatus()) {
      case 'recently_fed':
        return Colors.green;
      case 'needs_feeding_soon':
        return Colors.orange;
      case 'needs_feeding':
        return Colors.red;
      case 'not_fed':
      default:
        return Colors.grey;
    }
  }

  // Get status text
  String getStatusText() {
    final hours = getHoursSinceLastFed();
    final minutes = getMinutesSinceLastFed();

    if (hours == null) {
      return 'Not fed today';
    } else if (minutes! < 60) {
      return 'Fed $minutes min${minutes != 1 ? 's' : ''} ago';
    } else if (hours < 4) {
      return 'Recently fed ($hours hr${hours != 1 ? 's' : ''} ago)';
    } else if (hours < 8) {
      return 'Needs feeding soon ($hours hr${hours != 1 ? 's' : ''} ago)';
    } else {
      return 'Needs feeding! ($hours hr${hours != 1 ? 's' : ''} ago)';
    }
  }
}
