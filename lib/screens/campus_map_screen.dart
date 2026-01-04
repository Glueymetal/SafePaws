import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class CampusMapScreen extends StatelessWidget {
  const CampusMapScreen({super.key});

  // SNU Chennai center
  static final LatLng campusCenter = LatLng(12.7523549, 80.1896404);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Campus Map')),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: campusCenter,
          initialZoom: 16,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.pawsafe',
          ),

          // Markers
          MarkerLayer(
            markers: [
              _marker(campusCenter, 'SNU Campus'),
            ],
          ),
        ],
      ),
    );
  }

  Marker _marker(LatLng point, String label) {
    return Marker(
      point: point,
      width: 40,
      height: 40,
      child: Tooltip(
        message: label,
        child: const Icon(
          Icons.location_pin,
          size: 40,
          color: Colors.red,
        ),
      ),
    );
  }
}
