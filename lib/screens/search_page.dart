// lib/screens/search_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Local color theme (blue + pink)
class AppColors {
  static const bg = Color(0xFFD0E3FF);      // soft blue background
  static const pink = Color(0xFFEF3167);    // accent pink
  static const card = Color(0xFFFFFBF7);    // cream card background
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
  double _maxDistance = 50;
  final List<String> _selectedCategories = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Filters",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark)),
                const SizedBox(height: 16),
                const Text("Price Range"),
                RangeSlider(
                  values: RangeValues(_minPrice, _maxPrice),
                  min: 0,
                  max: 5000,
                  divisions: 100,
                  activeColor: AppColors.pink,
                  labels: RangeLabels(
                      "₹${_minPrice.toInt()}", "₹${_maxPrice.toInt()}"),
                  onChanged: (values) {
                    setModalState(() {
                      _minPrice = values.start;
                      _maxPrice = values.end;
                    });
                  },
                ),
                const SizedBox(height: 16),
                const Text("Categories"),
                Wrap(
                  spacing: 8,
                  children: [
                    _filterChip("Clothing", setModalState),
                    _filterChip("Food", setModalState),
                    _filterChip("Books", setModalState),
                    _filterChip("Electronics", setModalState),
                    _filterChip("Handicrafts", setModalState),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.pink,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {});
                  },
                  child: const Text("Apply Filters"),
                )
              ],
            ),
          );
        });
      },
    );
  }

  FilterChip _filterChip(String label, StateSetter setModalState) {
    final selected = _selectedCategories.contains(label);
    return FilterChip(
      label: Text(label,
          style: TextStyle(
              color: selected ? Colors.white : AppColors.textDark)),
      selected: selected,
      onSelected: (v) {
        setModalState(() {
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
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onPressed: _openFilterSheet,
          )
        ],
      ),
      body: Stack(
        children: [
          _buildProductResults(),

          // Map button (static for now)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              backgroundColor: AppColors.pink,
              child: const Icon(Icons.map_outlined, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StaticMapPage()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductResults() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance.collection('products').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.pink));
        }

        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['name'] ?? '').toString().toLowerCase();
          final search = _searchController.text.toLowerCase();

          final matchesSearch =
              search.isEmpty || name.contains(search);
          final price = (data['price'] is num)
              ? (data['price'] as num).toDouble()
              : double.tryParse((data['price'] ?? '0').toString()) ?? 0.0;
          final matchesPrice = price >= _minPrice && price <= _maxPrice;
          return matchesSearch && matchesPrice;
        }).toList();

        if (docs.isEmpty) {
          return Center(
              child: Text("No results found",
                  style: TextStyle(color: AppColors.textSoft)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, idx) {
            final data = docs[idx].data() as Map<String, dynamic>;
            return Card(
              color: AppColors.card,
              child: ListTile(
                title: Text(data['name'] ?? '',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark)),
                subtitle: Text("₹${data['price']}",
                    style: TextStyle(color: AppColors.textSoft)),
              ),
            );
          },
        );
      },
    );
  }
}

/// Placeholder Map Page
class StaticMapPage extends StatelessWidget {
  const StaticMapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.pink,
        title: const Text("Map View"),
      ),
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(
            child: Text("Static Map Placeholder"),
          ),
        ),
      ),
    );
  }
}
