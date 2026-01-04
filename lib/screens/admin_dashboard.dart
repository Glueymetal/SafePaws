import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/analytics_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  String _selectedTimeFilter = 'today';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final analytics = Provider.of<AnalyticsService>(context, listen: false);
      analytics.logEvent(name: 'admin_dashboard_viewed');
    });
  }

  DateTime _getFilterDate() {
    switch (_selectedTimeFilter) {
      case 'today':
        return DateTime.now().subtract(Duration(hours: 24));
      case 'week':
        return DateTime.now().subtract(Duration(days: 7));
      case 'month':
        return DateTime.now().subtract(Duration(days: 30));
      default:
        return DateTime(2020);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFFF8E1),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Admin Dashboard',
          style: TextStyle(
            fontFamily: 'SourGummy',
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: DropdownButton<String>(
              value: _selectedTimeFilter,
              underline: SizedBox(),
              icon: Icon(Icons.filter_list, color: Colors.black),
              items: [
                DropdownMenuItem(value: 'today', child: Text('Today')),
                DropdownMenuItem(value: 'week', child: Text('Week')),
                DropdownMenuItem(value: 'month', child: Text('Month')),
                DropdownMenuItem(value: 'all', child: Text('All Time')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedTimeFilter = value!;
                });
              },
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reports')
            .where('timestamp',
                isGreaterThan: Timestamp.fromDate(_getFilterDate()))
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text('Error loading data: ${snapshot.error}'),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.analytics_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No reports for selected period',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final reports = snapshot.data!.docs;
          final stats = _calculateStats(reports);

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            child: SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.article,
                          label: 'Total Reports',
                          value: reports.length.toString(),
                          color: Colors.blue,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.pets,
                          label: 'Active Dogs',
                          value: stats['activeDogs'].toString(),
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.location_on,
                          label: 'Active Locations',
                          value: stats['activeLocations'].toString(),
                          color: Colors.green,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.warning,
                          label: 'Danger Reports',
                          value: stats['dangerReports'].toString(),
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  _buildSectionTitle('📍 Location Hotspots'),
                  SizedBox(height: 8),
                  _buildLocationHotspots(
                      stats['locationCounts'] as Map<String, int>),
                  SizedBox(height: 24),
                  _buildSectionTitle('🎯 Condition Breakdown'),
                  SizedBox(height: 8),
                  _buildConditionBreakdown(
                      stats['conditionCounts'] as Map<String, int>),
                  SizedBox(height: 24),
                  _buildSectionTitle('🕒 Recent Activity'),
                  SizedBox(height: 8),
                  _buildRecentActivity(reports.take(5).toList()),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    String? subtitle,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              fontFamily: 'SourGummy',
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        fontFamily: 'SourGummy',
      ),
    );
  }

  Widget _buildLocationHotspots(Map<String, int> locationCounts) {
    if (locationCounts.isEmpty) {
      return _buildEmptyState('No location data');
    }

    final sortedLocations = locationCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: sortedLocations.take(5).map((entry) {
          final percentage = (entry.value /
                  locationCounts.values.reduce((a, b) => a + b) *
                  100)
              .toStringAsFixed(0);

          return ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  _getLocationColor(sortedLocations.indexOf(entry)),
              child: Text(
                entry.value.toString(),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            title: Text(
              entry.key,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: LinearProgressIndicator(
              value: entry.value / sortedLocations.first.value,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(
                _getLocationColor(sortedLocations.indexOf(entry)),
              ),
            ),
            trailing: Text(
              '$percentage%',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildConditionBreakdown(Map<String, int> conditionCounts) {
    if (conditionCounts.isEmpty) {
      return _buildEmptyState('No condition data');
    }

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: conditionCounts.entries.map((entry) {
          final total = conditionCounts.values.reduce((a, b) => a + b);
          final percentage = (entry.value / total * 100).toStringAsFixed(1);

          return Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getConditionColor(entry.key).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      _getConditionEmoji(entry.key),
                      style: TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getConditionLabel(entry.key),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: entry.value / total,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation(
                            _getConditionColor(entry.key),
                          ),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      entry.value.toString(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '$percentage%',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRecentActivity(List<QueryDocumentSnapshot> recentReports) {
    final now = DateTime.now();

    // Filter out expired reports for display
    final activeReports = recentReports.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();
      return expiresAt != null && expiresAt.isAfter(now);
    }).toList();

    if (activeReports.isEmpty) {
      return _buildEmptyState('No active reports');
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: activeReports.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final timestamp = (data['timestamp'] as Timestamp).toDate();
          final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();
          final timeAgo = _getTimeAgo(timestamp);
          final expiresIn =
              expiresAt != null ? _getExpiresIn(expiresAt) : 'Unknown';

          return ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _getConditionColor(data['condition'])
                    .withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  _getConditionEmoji(data['condition']),
                  style: TextStyle(fontSize: 24),
                ),
              ),
            ),
            title: Text(
              data['location'] ?? 'Unknown',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${data['dogCount']} dogs • ${_getConditionLabel(data['condition'])}',
                  style: TextStyle(fontSize: 12),
                ),
                Text(
                  'Expires in $expiresIn',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            trailing: Text(
              timeAgo,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          message,
          style: TextStyle(color: Colors.grey.shade600),
        ),
      ),
    );
  }

  // ✅ UPDATED: Filter by expiry to count only active dogs
  Map<String, dynamic> _calculateStats(List<QueryDocumentSnapshot> reports) {
    final now = DateTime.now();

    Set<String> activeLocations = {};
    int dangerReports = 0;
    int expiredReports = 0;
    Map<String, int> locationCounts = {};
    Map<String, int> conditionCounts = {};

    // Track latest NON-EXPIRED report per location
    Map<String, int> activeDogCountByLocation = {};

    for (var doc in reports) {
      final data = doc.data() as Map<String, dynamic>;
      final location = data['location'] as String?;
      final condition = data['condition'] as String?;
      final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();

      // Check if report is expired
      final isExpired = expiresAt == null || expiresAt.isBefore(now);

      if (isExpired) {
        expiredReports++;
        continue; // Skip expired reports for active stats
      }

      if (location != null) {
        activeLocations.add(location);
        locationCounts[location] = (locationCounts[location] ?? 0) + 1;

        // Only count dogs from the latest ACTIVE report per location
        if (!activeDogCountByLocation.containsKey(location)) {
          activeDogCountByLocation[location] = (data['dogCount'] as int?) ?? 0;
        }
      }

      if (condition == 'danger') {
        dangerReports++;
      }

      if (condition != null) {
        conditionCounts[condition] = (conditionCounts[condition] ?? 0) + 1;
      }
    }

    // Sum only active (non-expired) dog counts
    final activeDogs =
        activeDogCountByLocation.values.fold(0, (sum, count) => sum + count);

    return {
      'activeDogs': activeDogs, // ✅ Now only counts non-expired reports
      'activeLocations': activeLocations.length,
      'dangerReports': dangerReports,
      'expiredReports': expiredReports,
      'locationCounts': locationCounts,
      'conditionCounts': conditionCounts,
    };
  }

  Color _getLocationColor(int index) {
    final colors = [
      Colors.red,
      Colors.orange,
      Colors.amber,
      Colors.blue,
      Colors.green,
    ];
    return colors[index % colors.length];
  }

  Color _getConditionColor(String condition) {
    switch (condition) {
      case 'danger':
        return Colors.red;
      case 'highPresence':
        return Colors.orange;
      case 'lowPresence':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getConditionEmoji(String condition) {
    switch (condition) {
      case 'danger':
        return '⚠️';
      case 'highPresence':
        return '🟠';
      case 'lowPresence':
        return '✅';
      default:
        return '🐕';
    }
  }

  String _getConditionLabel(String condition) {
    switch (condition) {
      case 'danger':
        return 'Danger (Aggressive/Injured)';
      case 'highPresence':
        return 'High Presence (Caution)';
      case 'lowPresence':
        return 'Low Presence (Safe)';
      default:
        return condition;
    }
  }

  String _getTimeAgo(DateTime timestamp) {
    final difference = DateTime.now().difference(timestamp);

    if (difference.inMinutes < 1) return 'just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${(difference.inDays / 7).floor()}w ago';
  }

  String _getExpiresIn(DateTime expiresAt) {
    final difference = expiresAt.difference(DateTime.now());

    if (difference.isNegative) return 'Expired';
    if (difference.inMinutes < 1) return 'Soon';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m';
    if (difference.inHours < 24) return '${difference.inHours}h';
    return '${difference.inDays}d';
  }
}
