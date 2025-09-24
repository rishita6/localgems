// lib/screens/search_page.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'location_page.dart'; // <-- LocationPage must accept optional initialLat/initialLng
import 'product_detail_page.dart'; // <-- your ProductDetailPage file that accepts productId & sellerId

/// Local color theme (blue + pink)
class AppColors {
  static const bg = Color(0xFFD0E3FF); // soft blue background
  static const pink = Color(0xFFEF3167); // accent pink
  static const card = Color(0xFFFFFBF7); // cream card background
  static const textDark = Color(0xFF222222);
  static const textSoft = Color(0xFF6B7280);
  static const white = Colors.white;
}

class search_page extends StatefulWidget {
  const search_page({super.key});

  @override
  State<search_page> createState() => _search_pageState();
}

class _search_pageState extends State<search_page> {
  final TextEditingController _searchController = TextEditingController();
  double _minPrice = 0;
  double _maxPrice = 5000;
  double _selectedRating = 0;
  double _maxDistance = 50; // kilometers filter
  final List<String> _selectedCategories = [];

  double? _userLat;
  double? _userLng;
  String? _uid;

  @override
  void initState() {
    super.initState();
    _initUser();
  }

  Future<void> _initUser() async {
    final user = FirebaseAuth.instance.currentUser;
    _uid = user?.uid;
    if (_uid != null) {
      // load first saved address that contains lat/lng
      final addrSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('addresses')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (addrSnap.docs.isNotEmpty) {
        final d = addrSnap.docs.first.data();
        final lat = _parseDouble(d['lat']);
        final lng = _parseDouble(d['lng']);
        if (lat != null && lng != null) {
          if (mounted) {
            setState(() {
              _userLat = lat;
              _userLng = lng;
            });
          }
        }
      }
    }
  }

  /// Robust parsing for number fields that might be stored as string or num
  double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Haversine distance in kilometers
  double _calculateDistanceKm(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371; // Earth's radius in km
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double deg) => deg * pi / 180;

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // allow sheet to expand above keyboard
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        // Use a DraggableScrollableSheet wrapped in SafeArea + SingleChildScrollView
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          minChildSize: 0.3,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      Container(
                        width: 48,
                        height: 6,
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(6)),
                      ),
                      const SizedBox(height: 12),
                      const Text("Filters",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                      const SizedBox(height: 16),
                      const Text("Price Range"),
                      RangeSlider(
                        values: RangeValues(_minPrice, _maxPrice),
                        min: 0,
                        max: 5000,
                        divisions: 100,
                        activeColor: AppColors.pink,
                        labels: RangeLabels("₹${_minPrice.toInt()}", "₹${_maxPrice.toInt()}"),
                        onChanged: (values) {
                          setState(() {
                            _minPrice = values.start;
                            _maxPrice = values.end;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text("Distance (km)"),
                      Slider(
                        value: _maxDistance,
                        min: 1,
                        max: 200,
                        divisions: 199,
                        label: "${_maxDistance.toInt()} km",
                        activeColor: AppColors.pink,
                        onChanged: (v) {
                          setState(() => _maxDistance = v);
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text("Categories"),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          // you can add or remove chips here — chosen labels should match product.category values (or be substrings)
                          _filterChip("Clothing"),
                          _filterChip("Food"),
                          _filterChip("Food & Beverages"),
                          _filterChip("Books"),
                          _filterChip("Electronics"),
                          _filterChip("Handicrafts"),
                          _filterChip("Mehendi"),
                          _filterChip("Parlour"),
                        ],
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.pink,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() {}); // reapply filters
                        },
                        child: const Text("Apply Filters"),
                      ),
                      const SizedBox(height: 18),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  FilterChip _filterChip(String label) {
    final selected = _selectedCategories.contains(label);
    return FilterChip(
      label: Text(label, style: TextStyle(color: selected ? Colors.white : AppColors.textDark)),
      selected: selected,
      onSelected: (v) {
        setState(() {
          if (v) {
            _selectedCategories.add(label);
          } else {
            _selectedCategories.remove(label);
          }
        });
      },
      backgroundColor: AppColors.card,
      selectedColor: AppColors.pink,
      checkmarkColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.pink,
        title: TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Search products...",
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
            border: InputBorder.none,
          ),
          onChanged: (_) => setState(() {}),
        ),
        actions: [
          IconButton(
            // user didn't like the old icon — use a more utility/tune icon
            icon: const Icon(Icons.tune, color: Colors.white),
            onPressed: _openFilterSheet,
          )
        ],
      ),
      body: Stack(
        children: [
          _buildProductResults(),
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              backgroundColor: AppColors.pink,
              child: const Icon(Icons.location_pin, color: Colors.white), // nicer map icon
              onPressed: () async {
                // Open the real interactive map in "find" mode
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const LocationPage(mode: 'find')));
                // reload user location after returning (in case user picked/changed)
                await _initUser();
                setState(() {});
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductResults() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('products').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: AppColors.pink));
        }

        // Map snapshot docs to list and perform local filtering (including distance)
        final filtered = <Map<String, dynamic>>[];
        for (final doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['name'] ?? '').toString().toLowerCase();
          final search = _searchController.text.toLowerCase();
          final price = (data['price'] is num) ? (data['price'] as num).toDouble() : double.tryParse((data['price'] ?? '0').toString()) ?? 0.0;

          final matchesSearch = search.isEmpty || name.contains(search);
          final matchesPrice = price >= _minPrice && price <= _maxPrice;

          if (!matchesSearch || !matchesPrice) continue;

          // category filter (if any) — NEW: match product category against selected filters
          if (_selectedCategories.isNotEmpty) {
            final prodCatRaw = (data['category'] ?? '').toString();
            final prodCat = prodCatRaw.toLowerCase();
            // match any selected category (case-insensitive, substring match)
            bool categoryMatch = _selectedCategories.any((sel) {
              final selNorm = sel.toLowerCase();
              return prodCat.contains(selNorm) || selNorm.contains(prodCat);
            });
            if (!categoryMatch) continue;
          }

          // distance calculation only if we have both user location and product/seller location
          double? distanceKm;
          // robust location parsing: product may store location as Map with numeric or string lat/lng,
          // or as top-level lat/lng, or coordinates.latitude/longitude
          final prodLoc = data['location'];
          if (_userLat != null && _userLng != null) {
            double? sLat;
            double? sLng;
            if (prodLoc is Map) {
              sLat = _parseDouble(prodLoc['lat']) ?? _parseDouble(prodLoc['latitude']);
              sLng = _parseDouble(prodLoc['lng']) ?? _parseDouble(prodLoc['longitude']);
            } else {
              sLat = _parseDouble(data['lat']);
              sLng = _parseDouble(data['lng']);
            }
            if (sLat != null && sLng != null) {
              distanceKm = _calculateDistanceKm(_userLat!, _userLng!, sLat, sLng);
              if (distanceKm > _maxDistance) continue; // exclude if out of range
            }
          }

          // collect the doc data along with id and computed distance
          final entry = Map<String, dynamic>.from(data);
          entry['_docId'] = doc.id;
          if (distanceKm != null) entry['_distanceKm'] = distanceKm;
          filtered.add(entry);
        }

        if (filtered.isEmpty) {
          return Center(child: Text("No results found", style: TextStyle(color: AppColors.textSoft)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: filtered.length,
          itemBuilder: (context, idx) {
            final data = filtered[idx];
            final sellerId = (data['sellerId'] ?? data['sellerUid'] ?? data['ownerId'] ?? data['seller_id'])?.toString();
            final productId = data['_docId']?.toString();

            final distanceKm = data['_distanceKm'] is double ? (data['_distanceKm'] as double) : null;
            final distanceStr = (distanceKm != null) ? "${distanceKm.toStringAsFixed(1)} km" : 'Distance unknown';

            return GestureDetector(
              onTap: () {
                if (productId != null && sellerId != null) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailPage(productId: productId, sellerId: sellerId)));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product or seller info missing')));
                }
              },
              child: Card(
                color: AppColors.card,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  leading: (data['imageUrl'] ?? '').toString().isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(data['imageUrl'], width: 64, height: 64, fit: BoxFit.cover),
                        )
                      : Container(width: 64, height: 64, decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.image, color: AppColors.textSoft)),
                  title: Text(data['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text("₹${data['price'] ?? ''}", style: TextStyle(color: AppColors.textSoft)),
                      const SizedBox(height: 4),
                      // You can display distance if desired:
                      // Text(distanceStr, style: TextStyle(color: AppColors.textSoft, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
