import 'package:flutter/material.dart';
import '../models/feeding_status.dart';

class FeedingStatusChip extends StatelessWidget {
  final FeedingStatus status;
  final bool compact;

  const FeedingStatusChip({
    super.key,
    required this.status,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      // Compact version for map pins
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: status.getStatusColor().withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.restaurant, size: 10, color: Colors.white),
            const SizedBox(width: 2),
            Text(
              _getCompactText(),
              style: const TextStyle(
                fontSize: 9,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    // Full version for report cards
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: status.getStatusColor().withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: status.getStatusColor(),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.restaurant,
            size: 18,
            color: status.getStatusColor(),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                status.getStatusText(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: status.getStatusColor(),
                ),
              ),
              if (status.feedCount > 0)
                Text(
                  'Fed ${status.feedCount}x today',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _getCompactText() {
    final hours = status.getHoursSinceLastFed();

    if (hours == null) {
      return 'Not fed';
    } else if (hours < 1) {
      return 'Fed ✓';
    } else {
      return '${hours}h';
    }
  }
}

// Widget for "Mark as Fed" button
class MarkAsFedButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isLoading;

  const MarkAsFedButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.restaurant, size: 18),
      label: Text(isLoading ? 'Marking...' : 'Mark as Fed'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFC4A484),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
