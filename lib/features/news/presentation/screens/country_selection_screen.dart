// lib/features/news/presentation/screens/country_selection_screen.dart
import 'package:flutter/material.dart';
import '../../domain/entities/news_category.dart';

class CountrySelectionScreen extends StatefulWidget {
  final String? initialCountry;

  const CountrySelectionScreen({super.key, this.initialCountry});

  @override
  State<CountrySelectionScreen> createState() => _CountrySelectionScreenState();
}

class _CountrySelectionScreenState extends State<CountrySelectionScreen> {
  late String? _selectedCountry;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedCountry = widget.initialCountry;
  }

  List<String?> get _filteredCountries {
    final all = <String?>[null, ...NewsCategory.supportedCountries];
    if (_searchQuery.isEmpty) return all;

    return all.where((code) {
      if (code == null) return 'detect'.contains(_searchQuery.toLowerCase()) || 'auto'.contains(_searchQuery.toLowerCase());
      final name = NewsCategory.getCountryName(code).toLowerCase();
      return name.contains(_searchQuery.toLowerCase()) || code.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredCountries;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0C14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Select Region',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search countries...',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                  prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withValues(alpha: 0.3)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                ),
              ),
            ),
          ),

          // Info Banner
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFF6C63FF), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Showing currently supported regions. More countries are being added soon!',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final code = filtered[index];
                final isSelected = _selectedCountry == code;
                final name = code != null ? NewsCategory.getCountryName(code) : 'Detect Automatically';
                final emoji = code != null ? NewsCategory.getCountryEmoji(code) : '📍';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected 
                        ? const Color(0xFF6C63FF).withValues(alpha: 0.1)
                        : Colors.white.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected 
                          ? const Color(0xFF6C63FF).withValues(alpha: 0.5)
                          : Colors.white.withValues(alpha: 0.08),
                        width: 1.5,
                      ),
                    ),
                    child: ListTile(
                      onTap: () {
                        setState(() => _selectedCountry = code);
                        Navigator.pop(context, (code: code,));
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      leading: Text(
                        emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                      title: Text(
                        name,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      trailing: isSelected 
                        ? const Icon(Icons.check_circle, color: Color(0xFF6C63FF))
                        : Icon(Icons.circle_outlined, color: Colors.white.withValues(alpha: 0.1), size: 20),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
