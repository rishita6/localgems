// lib/screens/location_page.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';
import 'common_widgets.dart';
import 's_profilep.dart'; // <<-- open seller profile from map

class LocationPage extends StatefulWidget {
  /// mode: "find" to show nearby stores; "set" to set current user's location
  final String mode;
  final double? initialLat;
  final double? initialLng;

  /// Optional: if provided and mode == 'set', LocationPage will update this document path
  /// (e.g. 'users/{uid}/addresses/{docId}') instead of creating a new address doc.
  final String? targetAddressDocPath;

  const LocationPage({
    super.key,
    this.mode = 'find',
    this.initialLat,
    this.initialLng,
    this.targetAddressDocPath,
  });

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  final _fire = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  final MapController mapController = MapController();

  ll.LatLng? _currentLatLng;
  Marker? _selectedMarker;
  final List<Marker> _markers = [];
  bool _loading = true;
  double radiusKm = 10.0; // search radius default
  List<Map<String, dynamic>> _nearbySellers = [];

  // Category filter: added
  final List<String> categories = [
    'All',
    'Mehendi',
    'Parlour',
    'Food & Beverages',
    'Clothing',
    'Accessories',
    'Handicrafts',
    'Home Decor',
    'Grocery',
    'Books',
    'Stationery',
    'Personal Care',
    'Grooming',
    'Other',
  ];
  String selectedCategory = 'All';

  // theme (kept inline so file is self-contained)
  static const Color _accentPink = Color(0xFFEF3167);
  static const Color _bgBlue = Color(0xFFD0E3FF);
  static const Color _markerOwner = Color(0xFF2B6BEF); // user marker color

  // debug info visible on-screen (helpful during development)
  String _debugInfo = '';

  @override
  void initState() {
    super.initState();
    _initLocationAndMarkers();
  }

  void _setDebug(String s) {
    if (!kReleaseMode) {
      setState(() => _debugInfo = s);
      debugPrint(s);
    }
  }

  Future<void> _initLocationAndMarkers() async {
    setState(() => _loading = true);
    try {
      // prefer provided initial coords if mode==find wants to center on seller, but still try to get device pos for accurate distances
      if (widget.initialLat != null && widget.initialLng != null) {
        _currentLatLng = ll.LatLng(widget.initialLat!, widget.initialLng!);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            mapController.move(_currentLatLng!, 14.0);
          } catch (_) {}
        });
      }

      // Try to get device position (if permissions allow). If returns null, we keep using initial coords if present.
      final pos = await _determinePosition();
      if (pos != null) {
        _currentLatLng = ll.LatLng(pos.latitude, pos.longitude);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            mapController.move(_currentLatLng!, 14.0);
          } catch (_) {}
        });
      }

      if (widget.mode == 'find') {
        await _loadNearbySellers();
      } else {
        await _loadCurrentUserLocation();
      }
    } catch (e, st) {
      debugPrint('initLocation error: $e\n$st');
      _setDebug('init error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadCurrentUserLocation() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final doc = await _fire.collection('users').doc(uid).get();
    final data = doc.data();
    if (data != null && data['location'] != null) {
      // safe conversion
      final loc = Map<String, dynamic>.from(data['location']);
      final lat = _extractDouble(loc['lat']);
      final lng = _extractDouble(loc['lng']);
      if (lat != null && lng != null) {
        _selectedMarker = Marker(
          key: const ValueKey('selected'),
          width: 80,
          height: 80,
          point: ll.LatLng(lat, lng),
          child: const Icon(Icons.store, size: 36, color: Colors.blueAccent),
        );
        _markers.removeWhere((m) => m.key == const ValueKey('selected'));
        _markers.add(_selectedMarker!);
        _currentLatLng = ll.LatLng(lat, lng);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            mapController.move(_currentLatLng!, 14.0);
          } catch (_) {}
        });
        setState(() {});
      } else {
        _setDebug('user location exists but lat/lng not parseable');
      }
    } else {
      _setDebug('user document has no location');
    }
  }

  /// Robust helper: tries to parse dynamic into double
  double? _extractDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  /// Robustly extract lat/lng from a document (location map or top-level fields)
  Map<String, double>? _latLngFromDoc(Map<String, dynamic>? d) {
    if (d == null) return null;
    // If there's a 'location' map
    final loc = d['location'];
    if (loc is Map) {
      final lat = _extractDouble(loc['lat']);
      final lng = _extractDouble(loc['lng']);
      if (lat != null && lng != null) return {'lat': lat, 'lng': lng};
    }
    // fallback to top-level fields
    final latRoot = _extractDouble(d['lat']);
    final lngRoot = _extractDouble(d['lng']);
    if (latRoot != null && lngRoot != null) return {'lat': latRoot, 'lng': lngRoot};

    // also handle "coordinates": { "latitude":..., "longitude":... } shapes
    final coords = d['coordinates'];
    if (coords is Map) {
      final lat = _extractDouble(coords['latitude'] ?? coords['lat']);
      final lng = _extractDouble(coords['longitude'] ?? coords['lng']);
      if (lat != null && lng != null) return {'lat': lat, 'lng': lng};
    }

    return null;
  }

  Future<void> _loadNearbySellers() async {
    _markers.clear();
    _nearbySellers.clear();
    _setDebug('loading sellers... (category=$selectedCategory)');
    try {
      // Build query and include category filter if selectedCategory != 'All'
      Query<Map<String, dynamic>> q = _fire.collection('users').where('role', isEqualTo: 'Seller').withConverter<Map<String, dynamic>>(
        fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
        toFirestore: (value, _) => value,
      );

      if (selectedCategory != 'All') {
        // Use server-side filtering when possible
        q = q.where('category', isEqualTo: selectedCategory);
      }

      final sellersSnap = await q.get();
      final allSellers = sellersSnap.docs;
      _setDebug('fetched ${allSellers.length} seller docs (after category filter)');

      // If we don't have a user position, we still show sellers (no distance)
      if (_currentLatLng == null) {
        final added = <String>[];
        for (var doc in allSellers) {
          final d = doc.data() as Map<String, dynamic>;
          final latlng = _latLngFromDoc(d);
          if (latlng == null) continue;
          final lat = latlng['lat']!;
          final lng = latlng['lng']!;
          added.add('${doc.id}($lat,$lng)');
          final marker = Marker(
            width: 80,
            height: 80,
            point: ll.LatLng(lat, lng),
            child: GestureDetector(
              onTap: () => _showSellerBottomSheet(doc.id, d),
              child: Icon(Icons.store_mall_directory, size: 36, color: _accentPink),
            ),
          );
          _markers.add(marker);
        }
        _setDebug('added ${_markers.length} markers (no user location), examples: ${added.take(3).join(', ')}');
        setState(() {});
        return;
      }

      // We have user location: compute distances and filter by radius
      final lat0 = _currentLatLng!.latitude;
      final lng0 = _currentLatLng!.longitude;

      final sellersWithin = <Map<String, dynamic>>[];
      final missingLocIds = <String>[];
      for (var doc in allSellers) {
        final d = doc.data() as Map<String, dynamic>;
        final latlng = _latLngFromDoc(d);
        if (latlng == null) {
          missingLocIds.add(doc.id);
          continue;
        }
        final lat = latlng['lat']!;
        final lng = latlng['lng']!;
        final dist = _haversineKm(lat0, lng0, lat, lng);
        sellersWithin.add({
          'id': doc.id,
          'data': d,
          'lat': lat,
          'lng': lng,
          'distanceKm': dist,
        });
      }

      _setDebug('sellers with location: ${sellersWithin.length}, missing location: ${missingLocIds.length}');
      // apply radius filter
      final filtered = sellersWithin.where((s) => (s['distanceKm'] as double) <= radiusKm).toList();
      filtered.sort((a, b) => (a['distanceKm'] as double).compareTo(b['distanceKm'] as double));
      _nearbySellers = filtered;

      // build markers (user marker first)
      _markers.clear();
      _markers.add(Marker(
        width: 48,
        height: 48,
        point: _currentLatLng!,
        child: Icon(Icons.my_location, color: _markerOwner),
      ));

      for (var s in _nearbySellers) {
        final marker = Marker(
          width: 80,
          height: 80,
          point: ll.LatLng(s['lat'], s['lng']),
          child: GestureDetector(
            onTap: () => _showSellerBottomSheet(s['id'], s['data']),
            child: Icon(Icons.store_mall_directory, size: 36, color: _accentPink),
          ),
        );
        _markers.add(marker);
      }

      _setDebug('nearby markers added: ${_nearbySellers.length}');
      setState(() {});
    } catch (e, st) {
      debugPrint('_loadNearbySellers error: $e\n$st');
      _setDebug('error loading sellers: $e');
    }
  }

  Future<Position?> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location services are disabled.')));
      _setDebug('location service disabled');
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permissions are denied')));
        _setDebug('permission denied');
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permissions permanently denied; open settings to enable.')));

      _setDebug('permission denied forever');
      return null;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
      _setDebug('got device position: ${pos.latitude}, ${pos.longitude}');
      return pos;
    } catch (e) {
      debugPrint('getCurrentPosition error: $e');
      _setDebug('getCurrentPosition error: $e');
      return null;
    }
  }

  Future<String> _reverseGeocode(double lat, double lng) async {
    try {
      final places = await placemarkFromCoordinates(lat, lng);
      if (places.isEmpty) return '';
      final p = places.first;
      return '${p.name ?? ''} ${p.subLocality ?? ''} ${p.locality ?? ''} ${p.postalCode ?? ''} ${p.country ?? ''}'.trim();
    } catch (e) {
      debugPrint('reverseGeocode error: $e');
      return '';
    }
  }

  Future<void> _saveLocationSelected(ll.LatLng pos) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not signed in')));
      return;
    }

    final address = await _reverseGeocode(pos.latitude, pos.longitude);
    final userDocRef = _fire.collection('users').doc(uid);
    final userDoc = await userDocRef.get();

    // Seller flow: update users/{uid}.location
    if (userDoc.exists && (userDoc.data()?['role'] ?? '') == 'Seller') {
      await userDocRef.update({
        'location': {
          'lat': pos.latitude,
          'lng': pos.longitude,
          'address': address,
          'updatedAt': FieldValue.serverTimestamp(),
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seller location saved')));
        Navigator.pop(context, true); // signal success
      }
      return;
    }

    // Non-seller: update target doc if provided
    if (widget.targetAddressDocPath != null && widget.targetAddressDocPath!.isNotEmpty) {
      try {
        final docRef = _fire.doc(widget.targetAddressDocPath!);
        await docRef.set({
          'lat': pos.latitude,
          'lng': pos.longitude,
          'address': address,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Address updated from map')));
          Navigator.pop(context, true); // signal success to caller
        }
        return;
      } catch (e) {
        debugPrint('Failed to update target address doc: $e');
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update address')));
        return;
      }
    }

    // Default: create a new address doc under users/{uid}/addresses
    try {
      final addrRef = userDocRef.collection('addresses').doc();
      await addrRef.set({
        'lat': pos.latitude,
        'lng': pos.longitude,
        'address': address,
        'fullAddress': address,
        'label': 'Saved address',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Address saved')));
        Navigator.pop(context, addrRef.id); // return created doc id
      }
    } catch (e) {
      debugPrint('Failed to create address doc: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save address')));
    }
  }

  void _onTapMapTap(ll.LatLng latlng) {
    // no-op for now
  }

  void _onLongPressMap(ll.LatLng latlng) {
    setState(() {
      _selectedMarker = Marker(
        key: const ValueKey('selected'),
        width: 80,
        height: 80,
        point: latlng,
        child: const Icon(Icons.location_on, size: 40, color: Colors.blueAccent),
      );
      _markers.removeWhere((m) => m.key == const ValueKey('selected'));
      _markers.add(_selectedMarker!);
    });
  }

  /// Bottom sheet for a seller: now includes navigation to seller profile page
  void _showSellerBottomSheet(String id, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final name = data['businessName'] ?? data['name'] ?? 'Seller';
        final address = (data['location']?['address']) ?? '';
        return SizedBox(
          height: 220,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 6),
                Text(address, style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 10),
                Text('Category: ${data['category'] ?? '-'}'),
                const Spacer(),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        // NAVIGATE to seller profile page
                        Navigator.pop(ctx); // close sheet first for nicer UX
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => s_profilep(sellerId: id)),
                        );
                      },
                      icon: const Icon(Icons.storefront),
                      label: const Text('Open store'),
                      style: ElevatedButton.styleFrom(backgroundColor: _accentPink),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        final lat = _extractDouble(data['location']?['lat']);
                        final lng = _extractDouble(data['location']?['lng']);
                        if (lat != null && lng != null) {
                          final url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
                          launchUrlExternal(Uri.parse(url));
                        }
                      },
                      icon: const Icon(Icons.directions),
                      label: const Text('Directions'),
                      style: ElevatedButton.styleFrom(backgroundColor: _bgBlue),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Zoom to store',
                      onPressed: () {
                        final lat = _extractDouble(data['location']?['lat']);
                        final lng = _extractDouble(data['location']?['lng']);
                        if (lat != null && lng != null) {
                          try {
                            mapController.move(ll.LatLng(lat, lng), 16.0);
                          } catch (_) {}
                        }
                        Navigator.pop(ctx);
                      },
                      icon: Icon(Icons.location_pin, color: _accentPink),
                    )
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> launchUrlExternal(Uri uri) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        debugPrint('Could not launch $uri');
      }
    } catch (e) {
      debugPrint('launch external error: $e');
    }
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double deg) => deg * (pi / 180);

  Widget _buildBottomPanel() {
    if (widget.mode == 'find') {
      return Card(
        margin: const EdgeInsets.all(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // --- CATEGORY DROPDOWN (added) ---
            Row(
              children: [
                const Text('Category:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedCategory,
                        isExpanded: true,
                        items: categories.map((cat) {
                          return DropdownMenuItem(
                            value: cat,
                            child: Text(cat, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (value) async {
                          if (value == null) return;
                          setState(() {
                            selectedCategory = value;
                          });
                          await _loadNearbySellers(); // reload sellers with new category
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // --- RADIUS SLIDER + REFRESH ---
            Row(
              children: [
                const Text('Radius:'),
                const SizedBox(width: 12),
                Expanded(
                  child: Slider(
                    value: radiusKm,
                    min: 1,
                    max: 50,
                    divisions: 49,
                    activeColor: _accentPink,
                    label: '${radiusKm.toInt()} km',
                    onChanged: (v) async {
                      setState(() => radiusKm = v);
                      await _loadNearbySellers();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.refresh, color: _accentPink),
                  onPressed: () async {
                    await _loadNearbySellers();
                  },
                )
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 140,
              child: _nearbySellers.isEmpty
                  ? const Center(child: Text('No stores found in selected radius'))
                  : ListView.separated(
                      itemBuilder: (ctx, i) {
                        final s = _nearbySellers[i];
                        return ListTile(
                          title: Text(s['data']['businessName'] ?? s['data']['name'] ?? 'Store'),
                          subtitle: Text('${(s['distanceKm'] as double).toStringAsFixed(1)} km • ${s['data']['location']?['address'] ?? ''}'),
                          onTap: () {
                            final lat = s['lat'] as double;
                            final lng = s['lng'] as double;
                            try {
                              mapController.move(ll.LatLng(lat, lng), 16.0);
                            } catch (_) {}
                          },
                          trailing: TextButton(
                            onPressed: () {
                              // Open seller profile directly
                              Navigator.push(context, MaterialPageRoute(builder: (_) => s_profilep(sellerId: s['id'])));
                            },
                            child: const Text('Open'),
                          ),
                        );
                      },
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemCount: _nearbySellers.length,
                    ),
            ),
          ]),
        ),
      );
    } else {
      return Card(
        margin: const EdgeInsets.all(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Long-press on map to pick a location, or use current location'),
            const SizedBox(height: 8),
            Row(children: [
              ElevatedButton.icon(
                onPressed: () async {
                  final pos = await _determinePosition();
                  if (pos != null) {
                    final llp = ll.LatLng(pos.latitude, pos.longitude);
                    _onLongPressMap(llp);
                    try {
                      mapController.move(llp, 16.0);
                    } catch (_) {}
                  }
                },
                icon: const Icon(Icons.my_location),
                label: const Text('Use current'),
                style: ElevatedButton.styleFrom(backgroundColor: _accentPink),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _selectedMarker == null
                    ? null
                    : () async {
                        await _saveLocationSelected(_selectedMarker!.point);
                      },
                icon: const Icon(Icons.save),
                label: const Text('Save'),
                style: ElevatedButton.styleFrom(backgroundColor: _bgBlue),
              ),
              const SizedBox(width: 12),
              if (_selectedMarker != null)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _markers.removeWhere((m) => m.key == const ValueKey('selected'));
                      _selectedMarker = null;
                    });
                  },
                  child: const Text('Cancel'),
                )
            ]),
          ]),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = _currentLatLng ?? ll.LatLng(widget.initialLat ?? 20.5937, widget.initialLng ?? 78.9629);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.mode == 'find' ? 'Find Stores Nearby' : 'Set My Location'),
        backgroundColor: _accentPink,
      ),
      body: Stack(children: [
        Positioned.fill(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    // use initialCenter / initialZoom for this flutter_map version
                    initialCenter: center,
                    initialZoom: 13.0,
                    onLongPress: (tapPos, latlng) {
                      _onLongPressMap(latlng);
                    },
                    onTap: (tapPos, latlng) => _onTapMapTap(latlng),
                  ),
                  children: [
                    TileLayer(
                      // kept OSM default tile server (transparent about subdomains removal warning)
                      urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                      userAgentPackageName: 'com.example.localgems',
                    ),
                    MarkerLayer(markers: _markers),
                  ],
                ),
        ),
        Positioned(
          right: 12,
          top: 12,
          child: FloatingActionButton(
            heroTag: 'loc',
            mini: true,
            backgroundColor: _accentPink,
            onPressed: () async {
              final pos = await _determinePosition();
              if (pos != null) {
                final llp = ll.LatLng(pos.latitude, pos.longitude);
                try {
                  mapController.move(llp, 14.0);
                } catch (_) {}
              }
            },
            child: const Icon(Icons.my_location, color: Colors.white),
          ),
        ),
        Align(alignment: Alignment.bottomCenter, child: _buildBottomPanel()),
        // small debug overlay in non-release builds
        if (!kReleaseMode && _debugInfo.isNotEmpty)
          Positioned(
            left: 12,
            top: 80,
            child: Container(
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(maxWidth: 320),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(8)),
              child: Text(_debugInfo, style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ),
      ]),
    );
  }
}
