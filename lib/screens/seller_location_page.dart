// lib/screens/seller_location_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

class SellerLocationPage extends StatefulWidget {
  final double lat;
  final double lng;
  final String sellerName;
  final String? address; // optional address

  const SellerLocationPage({
    super.key,
    required this.lat,
    required this.lng,
    required this.sellerName,
    this.address,
  });

  @override
  State<SellerLocationPage> createState() => _SellerLocationPageState();
}

class _SellerLocationPageState extends State<SellerLocationPage> {
  final MapController mapController = MapController();

  static const Color _accentPink = Color(0xFFEF3167);

  @override
  Widget build(BuildContext context) {
    final center = ll.LatLng(widget.lat, widget.lng);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.sellerName),
        backgroundColor: _accentPink,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 15.0,
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: 'com.example.localgems',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    width: 80,
                    height: 80,
                    point: center,
                    child: const Icon(Icons.store_mall_directory,
                        size: 40, color: _accentPink),
                  ),
                ],
              ),
            ],
          ),
          if (widget.address != null && widget.address!.isNotEmpty)
            Positioned(
              left: 12,
              right: 12,
              bottom: 20,
              child: Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 6,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: _accentPink),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.address!,
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _accentPink,
        child: const Icon(Icons.my_location, color: Colors.white),
        onPressed: () {
          try {
            mapController.move(center, 16.0);
          } catch (_) {}
        },
      ),
    );
  }
}
