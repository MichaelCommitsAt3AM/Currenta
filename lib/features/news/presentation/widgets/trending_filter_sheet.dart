// lib/features/news/presentation/widgets/trending_filter_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/news_category.dart';
import '../../domain/entities/trending_filters.dart';
import '../../application/trending_filters_notifier.dart';
import '../../../auth/application/auth_notifier.dart';

class TrendingFilterSheet extends ConsumerStatefulWidget {
  const TrendingFilterSheet({super.key});

  @override
  ConsumerState<TrendingFilterSheet> createState() => _TrendingFilterSheetState();
}

class _TrendingFilterSheetState extends ConsumerState<TrendingFilterSheet> {
  late String? _selectedCountryCode;
  late int _selectedHours;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final currentFilters = ref.read(trendingFiltersNotifierProvider);
    _selectedCountryCode = currentFilters.countryCode;
    _selectedHours = currentFilters.hours;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final countries = ['global', ...NewsCategory.supportedCountries];
    
    final filteredCountries = countries.where((code) {
      if (code == 'global') return 'Global'.toLowerCase().contains(_searchQuery.toLowerCase());
      final name = NewsCategory.getCountryName(code);
      return name.toLowerCase().contains(_searchQuery.toLowerCase()) || 
             code.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filters',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    final authState = ref.read(authNotifierProvider);
                    setState(() {
                      _selectedCountryCode = authState.preferredCountry;
                      _selectedHours = 24;
                    });
                  },
                  child: const Text('Reset'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Time Horizon Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Time Horizon',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [12, 24, 72, 168].map((h) {
                final isSelected = _selectedHours == h;
                final label = switch (h) {
                  12 => '12h',
                  24 => '24h',
                  72 => '3d',
                  168 => '7d',
                  _ => '${h}h',
                };

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedHours = h);
                    },
                    showCheckmark: false,
                    selectedColor: theme.colorScheme.primaryContainer,
                    labelStyle: TextStyle(
                      color: isSelected ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 24),

          // Country Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Country',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search countries...',
                prefixIcon: const Icon(Icons.search),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outline.withOpacity(0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 1.5,
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.5),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          
          const SizedBox(height: 8),
          
          SizedBox(
            height: 200,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              itemCount: filteredCountries.length,
              itemBuilder: (context, index) {
                final code = filteredCountries[index];
                final isGlobal = code == 'global';
                final name = isGlobal ? 'Global' : NewsCategory.getCountryName(code);
                final emoji = isGlobal ? '🌐' : NewsCategory.getCountryEmoji(code);
                final isSelected = isGlobal ? _selectedCountryCode == null : _selectedCountryCode == code;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Text(emoji, style: const TextStyle(fontSize: 24)),
                    title: Text(
                      name,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                      ),
                    ),
                    trailing: isSelected ? Icon(Icons.check, color: theme.colorScheme.primary) : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected 
                            ? theme.colorScheme.primary.withOpacity(0.5)
                            : theme.colorScheme.outline.withOpacity(0.15),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        _selectedCountryCode = isGlobal ? null : code;
                      });
                    },
                  ),
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: ElevatedButton(
              onPressed: () {
                final filters = TrendingFilters(
                  countryCode: _selectedCountryCode,
                  hours: _selectedHours,
                );
                ref.read(trendingFiltersNotifierProvider.notifier).updateFilters(filters);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Apply Filters',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
