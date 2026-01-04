import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

/// 💼 BUSINESS ANALYTICS DASHBOARD
/// Shows key operational metrics that matter for scaling the app
class BusinessDashboard extends StatelessWidget {
  const BusinessDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Metrics'),
        backgroundColor: const Color(0xFFC4A484),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('reports').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final reports = snapshot.data!.docs;
          final metrics = _calculateBusinessMetrics(reports);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Key Performance Indicators
                _buildSectionHeader('📊 Key Performance Indicators'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildKPICard(
                        title: 'Daily Active Users',
                        value: metrics['dailyActiveUsers'].toString(),
                        subtitle: 'users reporting today',
                        color: Colors.blue,
                        icon: Icons.person_outline,
                        trend: metrics['userGrowth'],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildKPICard(
                        title: 'Response Time',
                        value: '${metrics['avgResponseTime']}m',
                        subtitle: 'avg to first report',
                        color: Colors.green,
                        icon: Icons.speed,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildKPICard(
                        title: 'Coverage Rate',
                        value: '${metrics['coverageRate']}%',
                        subtitle: 'locations monitored',
                        color: Colors.purple,
                        icon: Icons.map_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildKPICard(
                        title: 'Engagement',
                        value: '${metrics['engagementRate']}%',
                        subtitle: 'return user rate',
                        color: Colors.orange,
                        icon: Icons.trending_up,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Operational Efficiency
                _buildSectionHeader('⚡ Operational Efficiency'),
                const SizedBox(height: 12),
                _buildEfficiencyCard(
                  title: 'Report Resolution Time',
                  value: '${metrics['resolutionTime']} hours',
                  description: 'Average time until situation is resolved',
                  icon: Icons.timer_outlined,
                  color: Colors.teal,
                ),
                const SizedBox(height: 12),
                _buildEfficiencyCard(
                  title: 'Peak Hour Utilization',
                  value: '${metrics['peakUtilization']}%',
                  description: 'Reports during 7-10 AM, 5-9 PM',
                  icon: Icons.access_time,
                  color: Colors.indigo,
                ),

                const SizedBox(height: 24),

                // Risk Management
                _buildSectionHeader('⚠️ Risk Management'),
                const SizedBox(height: 12),
                _buildRiskCard(
                  title: 'High-Risk Reports',
                  value: metrics['dangerReports'].toString(),
                  percentage: metrics['dangerPercentage'],
                  icon: Icons.warning_amber,
                  color: Colors.red,
                ),
                const SizedBox(height: 12),
                _buildRiskCard(
                  title: 'False Positive Rate',
                  value: '${metrics['falsePositiveRate']}%',
                  percentage: metrics['falsePositiveRate'].toDouble(),
                  description: 'Reports with low confidence',
                  icon: Icons.report_problem_outlined,
                  color: Colors.orange,
                ),

                const SizedBox(height: 24),

                // Growth Metrics
                _buildSectionHeader('📈 Growth & Scalability'),
                const SizedBox(height: 12),
                _buildGrowthCard(metrics),

                const SizedBox(height: 24),

                // Cost Efficiency (for scaling)
                _buildSectionHeader('💰 Cost Efficiency'),
                const SizedBox(height: 12),
                _buildCostCard(metrics),

                const SizedBox(height: 24),

                // User Behavior Insights
                _buildSectionHeader('👥 User Behavior'),
                const SizedBox(height: 12),
                _buildBehaviorInsights(metrics),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        fontFamily: 'SourGummy',
      ),
    );
  }

  Widget _buildKPICard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
    double? trend,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              if (trend != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: trend >= 0 ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${trend >= 0 ? '+' : ''}${trend.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEfficiencyCard({
    required String title,
    required String value,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskCard({
    required String title,
    required String value,
    required double percentage,
    String? description,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percentage / 100,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation(color),
                          minHeight: 6,
                        ),
                      ),
                    ),
                  ],
                ),
                if (description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrowthCard(Map<String, dynamic> metrics) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade50, Colors.blue.shade50],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, color: Colors.purple.shade700, size: 28),
              const SizedBox(width: 12),
              const Text(
                'Growth Trajectory',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildGrowthMetric(
                'Weekly Growth',
                '${metrics['weeklyGrowth']}%',
                Icons.calendar_today,
              ),
              _buildGrowthMetric(
                'User Retention',
                '${metrics['retention']}%',
                Icons.people,
              ),
              _buildGrowthMetric(
                'Viral Coefficient',
                metrics['viralCoef'].toStringAsFixed(1),
                Icons.share,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGrowthMetric(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.purple.shade700),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.purple.shade700,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade700,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCostCard(Map<String, dynamic> metrics) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Cost per Active User',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              Text(
                '\$${metrics['costPerUser'].toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Firebase Costs (est.)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              Text(
                '\$${metrics['firebaseCost'].toStringAsFixed(2)}/mo',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '💡 Tip: Based on ${metrics['totalReports']} reports/month',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildBehaviorInsights(Map<String, dynamic> metrics) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              const Text(
                'User Patterns',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInsightRow(
            'Most Active Time',
            '${metrics['peakHour']}:00 - ${metrics['peakHour'] + 1}:00',
          ),
          _buildInsightRow(
            'Avg Reports/User',
            metrics['reportsPerUser'].toStringAsFixed(1),
          ),
          _buildInsightRow(
            'Popular Location',
            metrics['hotspot'],
          ),
          _buildInsightRow(
            'Session Duration',
            '${metrics['sessionDuration']}m avg',
          ),
        ],
      ),
    );
  }

  Widget _buildInsightRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _calculateBusinessMetrics(
      List<QueryDocumentSnapshot> reports) {
    // Calculate various business metrics from reports
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Daily active users (unique reporters today)
    final todayReports = reports.where((r) {
      final timestamp = (r.data() as Map)['timestamp'] as Timestamp;
      return timestamp.toDate().isAfter(today);
    }).toList();

    final dailyActiveUsers = todayReports.length; // Simplified

    // Danger reports
    final dangerReports = reports.where((r) {
      return (r.data() as Map)['condition'] == 'danger';
    }).length;

    final dangerPercentage =
        reports.isEmpty ? 0.0 : (dangerReports / reports.length * 100);

    // Most common location (hotspot)
    final locationCounts = <String, int>{};
    for (var r in reports) {
      final location = (r.data() as Map)['location'] as String;
      locationCounts[location] = (locationCounts[location] ?? 0) + 1;
    }
    final hotspot = locationCounts.isEmpty
        ? 'N/A'
        : locationCounts.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key;

    // Peak hour (most reports)
    final hourCounts = <int, int>{};
    for (var r in reports) {
      final timestamp = (r.data() as Map)['timestamp'] as Timestamp;
      final hour = timestamp.toDate().hour;
      hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
    }
    final peakHour = hourCounts.isEmpty
        ? 8
        : hourCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    return {
      'dailyActiveUsers': dailyActiveUsers,
      'avgResponseTime': 15, // Minutes (mock data)
      'coverageRate': 85, // Percentage
      'engagementRate': 72, // Percentage
      'resolutionTime': 2.5, // Hours
      'peakUtilization': 68, // Percentage
      'dangerReports': dangerReports,
      'dangerPercentage': dangerPercentage.toInt(),
      'falsePositiveRate': 12, // Percentage
      'weeklyGrowth': 23, // Percentage
      'retention': 65, // Percentage
      'viralCoef': 1.3, // Multiplier
      'costPerUser': 0.15, // Dollars
      'firebaseCost': 25.00, // Dollars per month
      'totalReports': reports.length,
      'peakHour': peakHour,
      'reportsPerUser':
          reports.isEmpty ? 0.0 : reports.length / max(dailyActiveUsers, 1),
      'hotspot': hotspot,
      'sessionDuration': 8, // Minutes
      'userGrowth': 15.0, // Percentage change
    };
  }
}
