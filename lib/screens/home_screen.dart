import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../services/firestore_service.dart';
import '../services/feeding_service.dart';
import '../screens/add_report_screen.dart';
import '../screens/admin_dashboard.dart';
import '../screens/paws_chat_screen.dart';
import '../models/report_model.dart';
import '../models/feeding_status.dart';
import '../utils/confidence_calculator.dart';
import '../widgets/feeding_status_chip.dart';

class HomeScreen extends StatefulWidget {
  final FirestoreService firestoreService;

  HomeScreen({super.key, FirestoreService? firestoreService})
      : firestoreService = firestoreService ?? FirestoreService();

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Stream<List<DogReport>> reportsStream;
  final FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  final FeedingService _feedingService = FeedingService();

  String? _selectedLocation;
  FeedingStatus? _selectedLocationFeedingStatus;
  bool _isMarkingFed = false;

  bool _showFeedingView = false;

  List<FeedingStatus>? _cachedFeedingStatuses;
  bool _isFeedingLoading = false;
  bool _hasLoadedOnce = false;
  String? _feedingError;

  final Map<String, LatLng> campusLocations = {
    'Clock Tower': const LatLng(12.752724, 80.196404),
    'Main Canteen': const LatLng(12.753242388969374, 80.19462529900647),
    'Sports Complex': const LatLng(12.752944160414897, 80.19396547559492),
    'Academic Block 1': const LatLng(12.752102906578527, 80.19229066556564),
    'Academic Block 2': const LatLng(12.751496221296424, 80.19258517703302),
    'Academic Block 3': const LatLng(12.752684111785046, 80.19247275257061),
  };

  @override
  void initState() {
    super.initState();
    reportsStream = widget.firestoreService.getReports();
    analytics.logEvent(name: 'home_viewed');
  }

  Future<void> _loadFeedingData() async {
    if (_isFeedingLoading) return;

    setState(() {
      _isFeedingLoading = true;
      _feedingError = null;
    });

    try {
      final statuses =
          await _loadAllFeedingStatuses().timeout(const Duration(seconds: 10));

      setState(() {
        _cachedFeedingStatuses = statuses;
        _isFeedingLoading = false;
        _hasLoadedOnce = true;
      });
    } on TimeoutException {
      setState(() {
        _feedingError = 'Connection timeout. Please check your internet.';
        _isFeedingLoading = false;
        _hasLoadedOnce = true;
      });
    } catch (e) {
      setState(() {
        _feedingError = e.toString();
        _isFeedingLoading = false;
        _hasLoadedOnce = true;
      });
    }
  }

  String getTimeAgo(Timestamp timestamp) {
    final duration = DateTime.now().difference(timestamp.toDate());
    if (duration.inMinutes < 1) return 'Just now';
    if (duration.inMinutes < 60) {
      return '${duration.inMinutes} min${duration.inMinutes != 1 ? 's' : ''} ago';
    }
    if (duration.inHours < 24) {
      return '${duration.inHours} hour${duration.inHours != 1 ? 's' : ''} ago';
    }
    return '${duration.inDays} day${duration.inDays != 1 ? 's' : ''} ago';
  }

  Color _pinColor(String condition) {
    switch (condition) {
      case 'danger':
        return Colors.red;
      case 'highPresence':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  String _conditionEmoji(String condition) {
    switch (condition) {
      case 'danger':
      case 'highPresence':
        return '⚠️';
      default:
        return '✓';
    }
  }

  String _conditionText(String condition) {
    switch (condition) {
      case 'danger':
        return 'Danger';
      case 'highPresence':
        return 'High Presence';
      default:
        return 'Safe';
    }
  }

  Future<void> _loadFeedingStatus(String locationName) async {
    try {
      final status = await _feedingService.getFeedingStatus(locationName);
      setState(() {
        _selectedLocationFeedingStatus = status;
      });
    } catch (e) {
      debugPrint('Error loading feeding status: $e');
    }
  }

  Future<void> _markLocationAsFed() async {
    if (_selectedLocation == null) return;

    final locationToMark = _selectedLocation;
    setState(() => _isMarkingFed = true);

    try {
      await _feedingService.markLocationAsFed(_selectedLocation!);

      analytics.logEvent(
        name: 'location_marked_fed',
        parameters: {'location': _selectedLocation!},
      );

      await _loadFeedingStatus(_selectedLocation!);
      await _loadFeedingData();

      if (mounted) {
        setState(() {
          _selectedLocation = null;
          _selectedLocationFeedingStatus = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('✓ $locationToMark fed'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(
              bottom: 100,
              left: 16,
              right: 16,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark as fed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isMarkingFed = false);
    }
  }

  Future<List<FeedingStatus>> _loadAllFeedingStatuses() async {
    final statuses = <FeedingStatus>[];

    for (final location in campusLocations.keys) {
      try {
        final status = await _feedingService.getFeedingStatus(location);
        statuses.add(status);
      } catch (e) {
        debugPrint('Error loading status for $location: $e');
        statuses.add(FeedingStatus(
          locationName: location,
          feedCount: 0,
        ));
      }
    }

    return statuses;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF6),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background.png'),
            fit: BoxFit.cover,
            opacity: 0.3,
          ),
        ),
        child: Column(
          children: [
            _buildAppBar(),
            _buildPeakHoursBanner(),
            Expanded(
              child:
                  _showFeedingView ? _buildFeedingView() : _buildReportsView(),
            ),
          ],
        ),
      ),
      floatingActionButton: _showFeedingView ? null : _buildFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildAppBar() {
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Image.asset('assets/images/logo.png', height: 40),
              const SizedBox(width: 12),
              const Text(
                'Safe Paws',
                style: TextStyle(
                  fontFamily: 'SourGummy',
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const Spacer(),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Text('🐾', style: TextStyle(fontSize: 24)),
                    onPressed: () {
                      analytics.logEvent(name: 'paws_chat_opened');
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PawsChatScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Paws AI',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.admin_panel_settings,
                        color: Colors.black, size: 24),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AdminDashboard(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Admin',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              _buildViewToggle(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeakHoursBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1976D2).withValues(alpha: 0.1),
            const Color(0xFF64B5F6).withValues(alpha: 0.1),
          ],
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.access_time, size: 16, color: Color(0xFF1976D2)),
          SizedBox(width: 6),
          Text(
            'Peak reporting hours: 7-10 AM, 5-9 PM',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1976D2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleButton(
            icon: Icons.report,
            label: 'Reports',
            isSelected: !_showFeedingView,
            onTap: () {
              setState(() => _showFeedingView = false);
              analytics.logEvent(name: 'view_reports_selected');
            },
          ),
          _buildToggleButton(
            icon: Icons.restaurant,
            label: 'Feeding',
            isSelected: _showFeedingView,
            onTap: () {
              setState(() => _showFeedingView = true);
              analytics.logEvent(name: 'view_feeding_selected');
              if (!_hasLoadedOnce && !_isFeedingLoading) {
                _loadFeedingData();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFC4A484) : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 18,
                color: isSelected ? Colors.white : Colors.grey.shade700),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsView() {
    return StreamBuilder<List<DogReport>>(
      stream: reportsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final reports = snapshot.data ?? [];

        if (reports.isEmpty) {
          return Column(
            children: [
              _buildEmptyMap(),
              _buildReportsHeader(0),
              Expanded(
                child: _buildEmptyState(),
              ),
            ],
          );
        }

        final locationData = _processReports(reports);
        return Column(
          children: [
            _buildMap(locationData, showFeedingMarkers: false),
            _buildReportsHeader(reports.length),
            Expanded(child: _buildReportsList(reports)),
          ],
        );
      },
    );
  }

  // ✅ EMPTY MAP WITH LOCATION LABELS
  Widget _buildEmptyMap() {
    return Container(
      height: 350,
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FlutterMap(
          options: const MapOptions(
            initialCenter: LatLng(12.752724, 80.196404),
            initialZoom: 17,
            interactionOptions: InteractionOptions(flags: InteractiveFlag.all),
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
            ),
            MarkerLayer(
              markers: campusLocations.entries.map((entry) {
                return Marker(
                  width: 100,
                  height: 80,
                  point: entry.value,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_pin,
                        size: 35,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                            )
                          ],
                        ),
                        child: Text(
                          entry.key,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedingView() {
    if (_isFeedingLoading && _cachedFeedingStatuses == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC4A484)),
            ),
            const SizedBox(height: 16),
            const Text('Loading feeding data...',
                style: TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
      );
    }

    if (_feedingError != null && _cachedFeedingStatuses == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off, size: 60, color: Colors.orange.shade300),
              const SizedBox(height: 16),
              const Text('Unable to load feeding data',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadFeedingData,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC4A484),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_cachedFeedingStatuses == null || _cachedFeedingStatuses!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_outlined,
                size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text('No feeding data available',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadFeedingData,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC4A484),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    final feedingStatuses = _cachedFeedingStatuses!;

    return RefreshIndicator(
      onRefresh: _loadFeedingData,
      color: const Color(0xFFC4A484),
      child: Stack(
        children: [
          Column(
            children: [
              _buildFeedingMap(feedingStatuses),
              _buildFeedingSummaryHeader(),
              Expanded(child: _buildFeedingStatusList(feedingStatuses)),
            ],
          ),
          if (_selectedLocation != null &&
              _selectedLocationFeedingStatus != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildLocationCard(),
            ),
        ],
      ),
    );
  }

  // ✅ FEEDING MAP WITH LOCATION LABELS
  Widget _buildFeedingMap(List<FeedingStatus> feedingStatuses) {
    return Container(
      height: 300,
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FlutterMap(
          options: const MapOptions(
            initialCenter: LatLng(12.752724, 80.196404),
            initialZoom: 17,
            interactionOptions: InteractionOptions(flags: InteractiveFlag.all),
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
            ),
            MarkerLayer(
              markers: campusLocations.entries.map((entry) {
                final status = feedingStatuses.firstWhere(
                  (s) => s.locationName == entry.key,
                  orElse: () =>
                      FeedingStatus(locationName: entry.key, feedCount: 0),
                );
                return _buildFeedingMarker(entry, status);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ FEEDING MARKER WITH LABEL
  Marker _buildFeedingMarker(
      MapEntry<String, LatLng> entry, FeedingStatus status) {
    final hours = status.getHoursSinceLastFed();
    final statusText = hours == null
        ? 'Not Fed'
        : hours == 0
            ? 'Just Fed'
            : hours < 4
                ? 'Fed ✓'
                : 'Need Food';

    return Marker(
      width: 130,
      height: 150,
      point: entry.value,
      child: GestureDetector(
        onTap: () async {
          setState(() => _selectedLocation = entry.key);
          await _loadFeedingStatus(entry.key);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.location_pin,
                    size: 40, color: status.getStatusColor()),
                Positioned(
                  right: -35,
                  top: -5,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: status.getStatusColor(),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.restaurant,
                            size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(statusText,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: status.getStatusColor(),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2), blurRadius: 4)
                ],
              ),
              child: Text(
                entry.key,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedingSummaryHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('🍽️ Feeding Status',
              style: TextStyle(
                  fontFamily: 'SourGummy',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
          FutureBuilder<int>(
            future: _feedingService.getTotalFeedingsToday(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green, width: 1),
                ),
                child: Text('${snapshot.data} fed today',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.green)),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeedingStatusList(List<FeedingStatus> statuses) {
    statuses.sort((a, b) {
      final statusOrder = {
        'needs_feeding': 0,
        'needs_feeding_soon': 1,
        'recently_fed': 2,
        'not_fed': 3
      };
      return (statusOrder[a.getStatus()] ?? 99)
          .compareTo(statusOrder[b.getStatus()] ?? 99);
    });

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: statuses.length,
      itemBuilder: (context, index) {
        final status = statuses[index];
        return _FeedingStatusCard(
          status: status,
          onMarkFed: () async {
            setState(() {
              _selectedLocation = status.locationName;
              _selectedLocationFeedingStatus = status;
            });
            await _markLocationAsFed();
          },
        );
      },
    );
  }

  Widget _buildLocationCard() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _selectedLocationFeedingStatus!
                                .getStatusColor()
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.location_on,
                              color: _selectedLocationFeedingStatus!
                                  .getStatusColor(),
                              size: 24),
                        ),
                        const SizedBox(width: 12),
                        Text(_selectedLocation!,
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'SourGummy')),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 24),
                      onPressed: () {
                        setState(() {
                          _selectedLocation = null;
                          _selectedLocationFeedingStatus = null;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FeedingStatusChip(
                    status: _selectedLocationFeedingStatus!, compact: false),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isMarkingFed ? null : _markLocationAsFed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC4A484),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isMarkingFed
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.restaurant, size: 22),
                              SizedBox(width: 10),
                              Text('Mark as Fed',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pets_outlined, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text('No recent activity',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87)),
          const SizedBox(height: 8),
          Text('This is normal during off-peak hours',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Map<String, dynamic> _processReports(List<DogReport> reports) {
    final Map<String, List<DogReport>> reportsByLocation = {};
    for (final r in reports) {
      reportsByLocation.putIfAbsent(r.location, () => []).add(r);
    }

    final Map<String, DogReport> latestByLocation = {};
    final Map<String, int> latestDogCountByLocation = {};
    final Map<String, Map<String, dynamic>> confidenceByLocation = {};

    for (final entry in reportsByLocation.entries) {
      final locationReports = entry.value;

      confidenceByLocation[entry.key] =
          ConfidenceCalculator.calculate(locationReports);

      locationReports.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      final latestReport = locationReports.first;
      latestByLocation[entry.key] = latestReport;

      latestDogCountByLocation[entry.key] = latestReport.dogCount;
    }

    return {
      'latest': latestByLocation,
      'totals': latestDogCountByLocation,
      'confidence': confidenceByLocation,
    };
  }

  Widget _buildMap(Map<String, dynamic> locationData,
      {required bool showFeedingMarkers}) {
    final latestByLocation = locationData['latest'] as Map<String, DogReport>;
    final totalDogsByLocation = locationData['totals'] as Map<String, int>;
    final confidenceByLocation =
        locationData['confidence'] as Map<String, Map<String, dynamic>>;

    return Container(
      height: 350,
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FlutterMap(
          options: const MapOptions(
            initialCenter: LatLng(12.752724, 80.196404),
            initialZoom: 17,
            interactionOptions: InteractionOptions(flags: InteractiveFlag.all),
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
            ),
            MarkerLayer(
              markers: campusLocations.entries.map((entry) {
                // ✅ Check if this location has reports
                if (latestByLocation.containsKey(entry.key)) {
                  // Show report marker with data
                  return _buildReportMarker(
                    entry,
                    latestByLocation[entry.key]!,
                    totalDogsByLocation[entry.key] ?? 0,
                    confidenceByLocation[entry.key]!,
                  );
                } else {
                  // ✅ Show grey label marker (no reports)
                  return _buildGreyLocationMarker(entry);
                }
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ SMALL: Just tiny label, no grey pin
  Marker _buildGreyLocationMarker(MapEntry<String, LatLng> entry) {
    return Marker(
      width: 80,
      height: 20,
      point: entry.value,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 4,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 2,
            )
          ],
        ),
        child: Text(
          entry.key,
          style: const TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  // ✅ REPORT MARKER WITH LABEL
  Marker _buildReportMarker(MapEntry<String, LatLng> entry, DogReport report,
      int totalDogs, Map<String, dynamic> confidence) {
    return Marker(
      width: 140,
      height: 160,
      point: entry.value,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(Icons.location_pin,
                  size: 40, color: _pinColor(report.condition)),
              if (totalDogs >= 1)
                Positioned(
                  right: -35,
                  top: -8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _pinColor(report.condition),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$totalDogs ',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                        const Text('🐕 ', style: TextStyle(fontSize: 11)),
                        Text(_conditionEmoji(report.condition),
                            style: const TextStyle(fontSize: 11)),
                        const SizedBox(width: 2),
                        Text(_conditionText(report.condition),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _pinColor(report.condition),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2), blurRadius: 4)
              ],
            ),
            child: Text(
              entry.key,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 4),
          ConfidenceBadge(confidenceData: confidence, compact: true),
        ],
      ),
    );
  }

  Widget _buildReportsHeader(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('🐾 Wall of Reports',
              style: TextStyle(
                  fontFamily: 'SourGummy',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFC4A484).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFC4A484), width: 1),
            ),
            child: Text('$count reports',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFC4A484))),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsList(List<DogReport> reports) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: reports.length,
      itemBuilder: (context, index) {
        final report = reports[index];
        final locationReports =
            reports.where((r) => r.location == report.location).toList();
        final confidence = ConfidenceCalculator.calculate(locationReports);
        return _ReportCard(
          report: report,
          timeAgo: getTimeAgo(report.timestamp),
          confidenceData: confidence,
        );
      },
    );
  }

  Widget _buildFAB() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 40),
      child: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFC4A484),
        icon: const Icon(Icons.pets, color: Colors.white),
        label: const Text('Add Report',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        onPressed: () {
          analytics.logEvent(name: 'add_report_button_tapped');
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AddReportScreen()));
        },
      ),
    );
  }
}

// 🎨 FEEDING STATUS CARD
class _FeedingStatusCard extends StatelessWidget {
  final FeedingStatus status;
  final VoidCallback onMarkFed;

  const _FeedingStatusCard({
    required this.status,
    required this.onMarkFed,
  });

  @override
  Widget build(BuildContext context) {
    final hoursSince = status.getHoursSinceLastFed();
    final statusColor = status.getStatusColor();

    return Card(
      margin: const EdgeInsets.only(bottom: 12, left: 12, right: 12),
      elevation: 3,
      shadowColor: statusColor.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: statusColor.withValues(alpha: 0.3), width: 2),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              statusColor.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child:
                        Icon(Icons.location_on, color: statusColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(status.locationName,
                            style: const TextStyle(
                                fontFamily: 'SourGummy',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87)),
                        const SizedBox(height: 4),
                        Text(_getStatusText(hoursSince),
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.restaurant,
                            size: 16, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(_getStatusLabel(hoursSince),
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStat(
                      icon: Icons.access_time,
                      label: 'Last Fed',
                      value: hoursSince == null
                          ? 'Never'
                          : hoursSince == 0
                              ? 'Just now'
                              : '${hoursSince}h ago',
                      color: statusColor,
                    ),
                    Container(
                      height: 40,
                      width: 1,
                      color: Colors.grey.shade300,
                    ),
                    _buildStat(
                      icon: Icons.today,
                      label: 'Today',
                      value: '${status.feedCount}x',
                      color: Colors.blue,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: onMarkFed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC4A484),
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shadowColor: const Color(0xFFC4A484).withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.restaurant, size: 20),
                      SizedBox(width: 8),
                      Text('Mark as Fed',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }

  String _getStatusText(int? hoursSince) {
    if (hoursSince == null) return 'Not fed today';
    if (hoursSince == 0) return 'Fed just now';
    if (hoursSince < 4) return 'Recently fed';
    return 'Needs feeding';
  }

  String _getStatusLabel(int? hoursSince) {
    if (hoursSince == null) return 'Not Fed';
    if (hoursSince == 0) return 'Just Fed';
    if (hoursSince < 4) return 'Fed ✓';
    return 'Feed Now';
  }
}

// REPORT CARD WIDGET
class _ReportCard extends StatelessWidget {
  final DogReport report;
  final String timeAgo;
  final Map<String, dynamic> confidenceData;

  const _ReportCard({
    required this.report,
    required this.timeAgo,
    required this.confidenceData,
  });

  String _formatCondition(String condition) {
    switch (condition) {
      case 'lowPresence':
        return 'Low Presence';
      case 'highPresence':
        return 'High Presence';
      case 'danger':
        return 'Danger';
      default:
        return condition;
    }
  }

  Color _conditionColor(String condition) {
    switch (condition) {
      case 'danger':
        return Colors.red.shade100;
      case 'highPresence':
        return Colors.orange.shade200;
      default:
        return Colors.green.shade100;
    }
  }

  IconData _conditionIcon(String condition) {
    switch (condition) {
      case 'danger':
        return Icons.warning;
      case 'highPresence':
        return Icons.report_problem;
      default:
        return Icons.check_circle;
    }
  }

  Color _conditionIconColor(String condition) {
    switch (condition) {
      case 'danger':
        return Colors.red.shade700;
      case 'highPresence':
        return Colors.orange.shade700;
      default:
        return Colors.green.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _conditionColor(report.condition),
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.location_on,
                          color: _conditionIconColor(report.condition),
                          size: 20),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(report.location,
                              style: const TextStyle(
                                  fontFamily: 'SourGummy',
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(_conditionIcon(report.condition),
                      color: _conditionIconColor(report.condition), size: 24),
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              children: [
                _InfoChip(
                    icon: Icons.pets,
                    label:
                        '${report.dogCount} dog${report.dogCount != 1 ? 's' : ''}'),
                const SizedBox(width: 8),
                _InfoChip(
                    icon: Icons.warning_amber_rounded,
                    label: _formatCondition(report.condition)),
              ],
            ),
            const SizedBox(height: 8),
            ConfidenceBadge(confidenceData: confidenceData, compact: false),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 14, color: Colors.black54),
                const SizedBox(width: 4),
                Text('Reported $timeAgo',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        fontStyle: FontStyle.italic)),
              ],
            ),
            if (report.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.notes, size: 16, color: Colors.black54),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(report.description,
                            style: const TextStyle(
                                fontSize: 14, color: Colors.black87))),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.black87),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87)),
        ],
      ),
    );
  }
}
