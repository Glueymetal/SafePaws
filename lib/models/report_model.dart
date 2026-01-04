import 'package:cloud_firestore/cloud_firestore.dart';

class DogReport {
  final String id;
  final String location;
  final int dogCount;
  final String condition;
  final String description;
  final double latitude;
  final double longitude;
  final Timestamp timestamp;
  final Timestamp expiresAt;

  DogReport({
    required this.id,
    required this.location,
    required this.dogCount,
    required this.condition,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.expiresAt,
  });

  // Create DogReport from Firestore document
  factory DogReport.fromMap(String id, Map<String, dynamic> data) {
    return DogReport(
      id: id,
      location: data['location'] ?? '',
      dogCount: data['dogCount'] ?? 0,
      condition: data['condition'] ?? 'lowPresence',
      description: data['description'] ?? '',
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      timestamp: data['timestamp'] ?? Timestamp.now(),
      expiresAt: data['expiresAt'] ?? Timestamp.now(),
    );
  }

  // Convert DogReport to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'location': location,
      'dogCount': dogCount,
      'condition': condition,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp,
      'expiresAt': expiresAt,
    };
  }

  // Check if report is expired
  bool get isExpired {
    return DateTime.now().isAfter(expiresAt.toDate());
  }

  // Get time remaining until expiry
  Duration get timeUntilExpiry {
    return expiresAt.toDate().difference(DateTime.now());
  }

  // Get hours remaining as string
  String get hoursRemaining {
    final hours = timeUntilExpiry.inHours;
    final minutes = timeUntilExpiry.inMinutes % 60;

    if (hours > 0) {
      return '$hours hr${hours != 1 ? 's' : ''} ${minutes} min${minutes != 1 ? 's' : ''}';
    } else if (minutes > 0) {
      return '$minutes min${minutes != 1 ? 's' : ''}';
    } else {
      return 'Expiring soon';
    }
  }
}
