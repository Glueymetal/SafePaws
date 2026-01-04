import 'package:flutter/material.dart';
import '../models/report_model.dart';
import 'dart:math';

class ConfidenceCalculator {
  /// Calculate trust level for reports - LAYMAN FRIENDLY VERSION
  /// Uses simple words: "Verified ✓", "Check First ⚠️", "No Info"
  static Map<String, dynamic> calculate(List<DogReport> reports) {
    if (reports.isEmpty) {
      return {
        'level': 'No Info',
        'color': Colors.grey.shade400,
        'icon': Icons.help_outline,
        'score': 0,
        'details': 'No reports yet',
        'reportCount': 0,
        'minutesAgo': 0,
      };
    }

    // Find the most recent report
    final latestReport = reports.reduce(
        (a, b) => a.timestamp.toDate().isAfter(b.timestamp.toDate()) ? a : b);

    final minutesSinceLatest =
        DateTime.now().difference(latestReport.timestamp.toDate()).inMinutes;

    // ==========================================
    // SIMPLE LOGIC FOR LAYMEN
    // ==========================================

    // CASE 1: VERIFIED ✓ (Green) - Multiple recent reports
    if (reports.length >= 2 && minutesSinceLatest < 120) {
      return {
        'level': 'Verified ✓',
        'color': Colors.green.shade600,
        'icon': Icons.verified,
        'score': 90,
        'details': '${reports.length} people reported',
        'reportCount': reports.length,
        'minutesAgo': minutesSinceLatest,
      };
    }

    // CASE 2: JUST REPORTED (Green) - Very recent single report
    if (reports.length == 1 && minutesSinceLatest < 30) {
      return {
        'level': 'Just Reported',
        'color': Colors.green.shade600,
        'icon': Icons.schedule,
        'score': 75,
        'details': '${minutesSinceLatest}m ago',
        'reportCount': 1,
        'minutesAgo': minutesSinceLatest,
      };
    }

    // CASE 3: CHECK FIRST ⚠️ (Yellow) - Old or single report
    if (minutesSinceLatest >= 120 || reports.length == 1) {
      final hours = minutesSinceLatest ~/ 60;
      final timeText =
          hours > 0 ? '${hours}h ago' : '${minutesSinceLatest}m ago';

      return {
        'level': 'Check First ⚠️',
        'color': Colors.orange.shade600,
        'icon': Icons.warning_amber_rounded,
        'score': 40,
        'details': timeText,
        'reportCount': reports.length,
        'minutesAgo': minutesSinceLatest,
      };
    }

    // CASE 4: UNCONFIRMED (Gray) - Default fallback
    return {
      'level': 'Unconfirmed',
      'color': Colors.grey.shade500,
      'icon': Icons.info_outline,
      'score': 20,
      'details': 'Limited info',
      'reportCount': reports.length,
      'minutesAgo': minutesSinceLatest,
    };
  }

  /// Format minutes into readable time
  static String _formatMinutes(int minutes) {
    if (minutes < 1) {
      return 'just now';
    } else if (minutes < 60) {
      return '${minutes}m ago';
    } else if (minutes < 1440) {
      final hours = minutes ~/ 60;
      return '${hours}h ago';
    } else {
      final days = minutes ~/ 1440;
      return '${days}d ago';
    }
  }
}

/// LAYMAN-FRIENDLY Confidence Badge Widget
class ConfidenceBadge extends StatelessWidget {
  final Map<String, dynamic> confidenceData;
  final bool compact;

  const ConfidenceBadge({
    super.key,
    required this.confidenceData,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      // Compact version for map pins
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: confidenceData['color'],
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              confidenceData['icon'],
              size: 10,
              color: Colors.white,
            ),
            const SizedBox(width: 3),
            Text(
              _getShortLabel(confidenceData['level']),
              style: const TextStyle(
                fontSize: 9,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    } else {
      // Full version for report cards - MORE VISUAL
      return GestureDetector(
        onTap: () => _showExplanation(context),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: confidenceData['color'].withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: confidenceData['color'],
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                confidenceData['icon'],
                size: 18,
                color: confidenceData['color'],
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    confidenceData['level'],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: confidenceData['color'],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    confidenceData['details'],
                    style: TextStyle(
                      fontSize: 11,
                      color: confidenceData['color'].withOpacity(0.8),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.info_outline,
                size: 14,
                color: confidenceData['color'].withOpacity(0.6),
              ),
            ],
          ),
        ),
      );
    }
  }

  String _getShortLabel(String level) {
    if (level.contains('Verified')) return 'OK';
    if (level.contains('Just')) return 'New';
    if (level.contains('Check')) return 'Old';
    return '?';
  }

  void _showExplanation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue),
            SizedBox(width: 8),
            Text('What does this mean?'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This tells you how reliable the information is:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 16),
              _buildExplanationItem(
                icon: Icons.verified,
                color: Colors.green,
                title: 'Verified ✓',
                description:
                    'Multiple people just reported this. You can trust it!',
              ),
              const SizedBox(height: 12),
              _buildExplanationItem(
                icon: Icons.schedule,
                color: Colors.green,
                title: 'Just Reported',
                description:
                    'Someone reported this minutes ago. Very fresh info.',
              ),
              const SizedBox(height: 12),
              _buildExplanationItem(
                icon: Icons.warning_amber_rounded,
                color: Colors.orange,
                title: 'Check First ⚠️',
                description:
                    'Old report or only 1 person reported. Be careful!',
              ),
              const SizedBox(height: 12),
              _buildExplanationItem(
                icon: Icons.help_outline,
                color: Colors.grey,
                title: 'No Info',
                description: 'Nobody has reported anything here yet.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  Widget _buildExplanationItem({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
